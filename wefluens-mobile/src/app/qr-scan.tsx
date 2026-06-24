import { Ionicons } from '@expo/vector-icons';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { gradients, useTheme } from '@/lib/theme';

const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

/** Extracts a user id from a `wefluens://user/<uuid>` payload (or a bare uuid). */
function parseUserId(code: string): string | null {
  const prefix = 'wefluens://user/';
  const raw = code.startsWith(prefix) ? code.slice(prefix.length) : code;
  return UUID_RE.test(raw.trim()) ? raw.trim() : null;
}

export default function QRScan() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();

  const [permission, requestPermission] = useCameraPermissions();
  const [handled, setHandled] = useState(false);
  const [sending, setSending] = useState(false);

  async function onScan(data: string) {
    if (handled || sending) return;
    const target = parseUserId(data);
    if (!target) { setHandled(true); notify(t('qrInvalid')); setTimeout(() => setHandled(false), 1500); return; }
    if (target === userId) { setHandled(true); notify(t('qrSelf')); setTimeout(() => setHandled(false), 1500); return; }

    setHandled(true);
    setSending(true);
    try {
      // Pass a real message (an empty one is rejected) and act on the returned
      // status — the RPC succeeds with a status, it doesn't throw for "already…".
      const status = await api.sendFriendRequest(target, t('friendRequestMessage'));
      switch (status) {
        case 'already_friends': notify(t('qrAlreadyFriends')); break;
        case 'incoming_exists': notify(t('qrIncomingExists')); break;
        default: notify(t('qrRequestSent')); break; // 'sent' / 'already_sent'
      }
      router.back();
    } catch {
      notify(t('qrRequestError'));
      setTimeout(() => { setHandled(false); }, 1500);
    } finally {
      setSending(false);
    }
  }

  // Web / unsupported — scanning needs the native camera.
  if (Platform.OS === 'web') {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <NavBar title={t('qrScanTitle')} onBack={() => router.back()} />
        <View style={styles.center}>
          <Ionicons name="phone-portrait-outline" size={40} color={c.inkTertiary} />
          <Text style={{ color: c.inkSecondary, marginTop: 12, textAlign: 'center', paddingHorizontal: 32 }}>
            {t('qrScanHint')}
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!permission) {
    return <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']} />;
  }

  if (!permission.granted) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <NavBar title={t('qrScanTitle')} onBack={() => router.back()} />
        <View style={styles.center}>
          <Ionicons name="camera-outline" size={40} color={c.inkTertiary} />
          <Text style={{ color: c.inkSecondary, marginTop: 12, textAlign: 'center', paddingHorizontal: 36 }}>
            {t('qrPermission')}
          </Text>
          <Pressable onPress={requestPermission} style={{ marginTop: 18 }}>
            <LinearGradient
              colors={gradients.sunset}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.grantBtn}
            >
              <Text style={styles.grantText}>{t('qrPermissionGrant')}</Text>
            </LinearGradient>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: '#000' }}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
        onBarcodeScanned={handled ? undefined : ({ data }) => onScan(data)}
      />

      {/* Overlay */}
      <SafeAreaView style={styles.overlay} edges={['top']} pointerEvents="box-none">
        <View style={styles.topBar} pointerEvents="box-none">
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.closeBtn}>
            <Ionicons name="close" size={26} color="#fff" />
          </Pressable>
        </View>

        <View style={styles.frameWrap} pointerEvents="none">
          <View style={styles.frame} />
          <Text style={styles.hint}>{t('qrScanHint')}</Text>
        </View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  grantBtn: { paddingHorizontal: 28, paddingVertical: 14, borderRadius: 14 },
  grantText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  overlay: { flex: 1 },
  topBar: { flexDirection: 'row', justifyContent: 'flex-start', paddingHorizontal: 12, paddingTop: 6 },
  closeBtn: {
    width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center', justifyContent: 'center',
  },
  frameWrap: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  frame: {
    width: 240, height: 240, borderRadius: 28, borderWidth: 3, borderColor: 'rgba(255,255,255,0.9)',
  },
  hint: { color: 'rgba(255,255,255,0.9)', fontSize: 14, fontWeight: '600', marginTop: 24 },
});
