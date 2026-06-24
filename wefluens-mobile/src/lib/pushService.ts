/**
 * Push notifications — client side, mirroring the Swift app's PushService.
 * Requests OS permission, fetches an Expo push token, and upserts it into the
 * `device_tokens` table the backend reads.
 *
 * NOTE (backend follow-up): the Swift app stores a raw APNs token and the current
 * `send-push` edge function targets APNs directly. Expo returns an *Expo push
 * token* (`ExponentPushToken[…]`), which APNs cannot consume. To actually deliver
 * to this client, the backend must route Expo-format tokens through Expo's push
 * service. Registering the token here is the client-side parity piece; delivery is
 * a separate backend task.
 */
import Constants from 'expo-constants';
import * as Device from 'expo-device';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';

import { supabase } from './supabase';

let handlerSet = false;

/** Call once at app startup so foreground notifications surface a banner. */
export function setupNotificationHandler(): void {
  if (handlerSet) return;
  handlerSet = true;
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldPlaySound: true,
      shouldSetBadge: true,
      shouldShowBanner: true,
      shouldShowList: true,
    }),
  });
}

/**
 * Request permission, get the Expo push token, and save it to `device_tokens`.
 * Returns the token on success, or null if denied / unavailable (simulator, Expo
 * Go, missing projectId). Never throws.
 */
export async function registerForPushNotifications(userId: string): Promise<string | null> {
  try {
    if (!Device.isDevice) return null; // push tokens require a physical device

    const current = await Notifications.getPermissionsAsync();
    let granted = current.granted
      || current.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
    if (!granted) {
      const requested = await Notifications.requestPermissionsAsync();
      granted = requested.granted
        || requested.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
    }
    if (!granted) return null;

    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'Default',
        importance: Notifications.AndroidImportance.DEFAULT,
      });
    }

    const projectId = Constants.expoConfig?.extra?.eas?.projectId as string | undefined;
    if (!projectId) return null;

    const { data: token } = await Notifications.getExpoPushTokenAsync({ projectId });

    await supabase
      .from('device_tokens')
      .upsert({ user_id: userId, token, platform: Platform.OS }, { onConflict: 'token' });

    return token;
  } catch {
    return null;
  }
}
