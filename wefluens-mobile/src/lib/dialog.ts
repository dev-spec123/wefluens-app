/**
 * Cross-platform dialogs. react-native's Alert.alert with buttons does NOT work
 * on react-native-web (no-op), which makes confirms feel "dead" in the browser.
 * These helpers use window.confirm/alert on web and Alert on native.
 */
import { Alert, Platform } from 'react-native';

/** Yes/no confirmation. Resolves true if the user confirms. */
export function confirmAsync(
  title: string,
  message?: string,
  options?: { confirmLabel?: string; cancelLabel?: string; destructive?: boolean },
): Promise<boolean> {
  const confirmLabel = options?.confirmLabel ?? 'OK';
  const cancelLabel = options?.cancelLabel ?? 'Cancel';
  if (Platform.OS === 'web') {
    const text = message ? `${title}\n\n${message}` : title;
    return Promise.resolve(typeof window !== 'undefined' ? window.confirm(text) : false);
  }
  return new Promise((resolve) => {
    Alert.alert(title, message, [
      { text: cancelLabel, style: 'cancel', onPress: () => resolve(false) },
      { text: confirmLabel, style: options?.destructive ? 'destructive' : 'default', onPress: () => resolve(true) },
    ]);
  });
}

/** Simple message dialog (web-safe). */
export function notify(title: string, message?: string) {
  if (Platform.OS === 'web') {
    if (typeof window !== 'undefined') window.alert(message ? `${title}\n\n${message}` : title);
    return;
  }
  Alert.alert(title, message);
}
