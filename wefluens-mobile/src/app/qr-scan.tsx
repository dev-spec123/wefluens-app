import { Ionicons } from '@expo/vector-icons';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, Vibration, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, gradients, radius, space, useTheme } from '@/lib/theme';

const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

/** Extracts a user id from a `wefluens://user/<uuid>` payload (or a bare uuid). */
function parseUserId(code: string): string | null {
  const prefix = 'wefluens://user/';
  const raw = code.startsWith(prefix) ? code.slice(prefix.length) : code;
  return UUID_RE.test(raw.trim()) ? raw.trim() : null;
}

type RequestStatus = 'idle' | 'sending' | 'sent' | 'failed';

export default function QRScan() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();

  const [permission, requestPermission] = useCameraPermissions();
  const [handled, setHandled] = useState(false);

  // Scan-result overlay state (mirrors Swift QRScanView.resultOverlay).
  const [scannedId, setScannedId] = useState<string | null>(null);
  const [scannedName, setScannedName] = useState<string | null>(null);
  const [status, setStatus] = useState<RequestStatus>('idle');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  function resetScan() {
    setScannedId(null);
    setScannedName(null);
    setStatus('idle');
    setErrorMessage(null);
    setHandled(false);
  }

  async function onScan(data: string) {
    if (handled) return;
    const target = parseUserId(data);
    if (!target) { setHandled(true); notify(t('qrInvalid')); setTimeout(() => setHandled(false), 1500); return; }
    if (target === userId) { setHandled(true); notify(t('qrSelf')); setTimeout(() => setHandled(false), 1500); return; }

    // Freeze scanning and surface the confirmation overlay before sending.
    setHandled(true);
    setScannedId(target);
    setStatus('idle');
    Vibration.vibrate(10);
    // Best-effort preview name; the overlay renders fine without it.
    api.getProfileName(target).then((n: string | null) => setScannedName(n)).catch(() => {});
  }

  async function sendRequest() {
    if (!scannedId) return;
    setStatus('sending');
    try {
      // Pass a real message (an empty one is rejected) and act on the returned
      // status — the RPC succeeds with a status, it doesn't throw for "already…".
      const result = await api.sendFriendRequest(scannedId, t('friendRequestMessage'));
      switch (result) {
        case 'already_friends': setErrorMessage(t('qrAlreadyFriends')); setStatus('failed'); break;
        case 'incoming_exists': setErrorMessage(t('qrIncomingExists')); setStatus('failed'); break;
        default: setStatus('sent'); Vibration.vibrate([0, 30, 60, 30]); break; // 'sent' / 'already_sent'
      }
    } catch {
      setErrorMessage(t('qrRequestError'));
      setStatus('failed');
      Vibration.vibrate(120);
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
          {/* Scan frame with coral corner accents (mirrors Swift scanFrame). */}
          <View style={styles.frame}>
            <View style={[styles.corner, styles.cornerTL]} />
            <View style={[styles.corner, styles.cornerTR]} />
            <View style={[styles.corner, styles.cornerBL]} />
            <View style={[styles.corner, styles.cornerBR]} />
            <View style={[styles.cornerV, styles.cornerVTL]} />
            <View style={[styles.cornerV, styles.cornerVTR]} />
            <View style={[styles.cornerV, styles.cornerVBL]} />
            <View style={[styles.cornerV, styles.cornerVBR]} />
          </View>
          <Text style={styles.hint}>{t('qrScanHint')}</Text>
        </View>
      </SafeAreaView>

      {/* Result overlay */}
      {scannedId && (
        <View style={styles.resultScrim}>
          {status === 'idle' || status === 'sending' ? (
            <View style={styles.resultCard}>
              <Avatar colors={avatarGradient(scannedId)} name={scannedName ?? '?'} size={72} online />
              {scannedName ? <Text style={styles.resultName}>{scannedName}</Text> : null}
              {status === 'sending' ? (
                <View style={{ alignItems: 'center', gap: space.sm }}>
                  <ActivityIndicator color="#fff" />
                  <Text style={styles.resultSub}>{t('qrSending')}</Text>
                </View>
              ) : (
                <>
                  <Pressable onPress={sendRequest} style={styles.sendBtnWrap}>
                    <LinearGradient
                      colors={gradients.sunset}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.sendBtn}
                    >
                      <Ionicons name="person-add" size={18} color="#fff" />
                      <Text style={styles.sendBtnText}>{t('qrSendRequest')}</Text>
                    </LinearGradient>
                  </Pressable>
                  <Pressable onPress={resetScan} hitSlop={8}>
                    <Text style={styles.cancelText}>{t('authCancel')}</Text>
                  </Pressable>
                </>
              )}
            </View>
          ) : status === 'sent' ? (
            <View style={styles.resultCard}>
              <Ionicons name="checkmark-circle" size={56} color="#2AD17E" />
              <Text style={styles.resultTitle}>{t('qrSentTitle')}</Text>
              <Text style={styles.resultSub}>{t('qrSentSub')}</Text>
              <Pressable onPress={() => router.back()} style={styles.plainBtn}>
                <Text style={styles.plainBtnText}>{t('qrDone')}</Text>
              </Pressable>
            </View>
          ) : (
            <View style={styles.resultCard}>
              <Ionicons name="close-circle" size={56} color={c.danger} />
              <Text style={styles.resultTitle}>{t('qrFailedTitle')}</Text>
              <Text style={styles.resultSub}>{errorMessage ?? t('qrFailedSub')}</Text>
              <Pressable onPress={resetScan} style={styles.plainBtn}>
                <Text style={styles.plainBtnText}>{t('qrTryAgain')}</Text>
              </Pressable>
            </View>
          )}
        </View>
      )}
    </View>
  );
}

const CORNER = 28;
const CORNER_W = 3;

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  grantBtn: { paddingHorizontal: 28, paddingVertical: 14, borderRadius: radius.md },
  grantText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  overlay: { flex: 1 },
  topBar: { flexDirection: 'row', justifyContent: 'flex-start', paddingHorizontal: 12, paddingTop: 6 },
  closeBtn: {
    width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(0,0,0,0.4)',
    alignItems: 'center', justifyContent: 'center',
  },
  frameWrap: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  frame: {
    width: 240, height: 240, borderRadius: 24, borderWidth: CORNER_W, borderColor: 'rgba(255,255,255,0.5)',
  },
  // Horizontal coral corner bars.
  corner: { position: 'absolute', width: CORNER, height: CORNER_W, borderRadius: 2, backgroundColor: '#FF4D6D' },
  cornerTL: { top: -CORNER_W, left: -CORNER_W },
  cornerTR: { top: -CORNER_W, right: -CORNER_W },
  cornerBL: { bottom: -CORNER_W, left: -CORNER_W },
  cornerBR: { bottom: -CORNER_W, right: -CORNER_W },
  // Vertical coral corner bars.
  cornerV: { position: 'absolute', width: CORNER_W, height: CORNER, borderRadius: 2, backgroundColor: '#FF4D6D' },
  cornerVTL: { top: -CORNER_W, left: -CORNER_W },
  cornerVTR: { top: -CORNER_W, right: -CORNER_W },
  cornerVBL: { bottom: -CORNER_W, left: -CORNER_W },
  cornerVBR: { bottom: -CORNER_W, right: -CORNER_W },
  hint: { color: 'rgba(255,255,255,0.9)', fontSize: 14, fontWeight: '600', marginTop: 24 },

  // Result overlay (idle/sending/sent/failed).
  resultScrim: {
    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.7)',
    alignItems: 'center', justifyContent: 'center', padding: space.xxl,
  },
  resultCard: { alignItems: 'center', gap: space.lg, width: '100%' },
  resultName: { color: '#fff', fontSize: 20, fontWeight: '700' },
  resultTitle: { color: '#fff', fontSize: 20, fontWeight: '700' },
  resultSub: { color: 'rgba(255,255,255,0.7)', fontSize: 14, textAlign: 'center' },
  sendBtnWrap: { width: '100%', paddingHorizontal: 40 },
  sendBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: space.sm,
    paddingVertical: 15, borderRadius: radius.md,
  },
  sendBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  cancelText: { color: 'rgba(255,255,255,0.7)', fontSize: 15 },
  plainBtn: {
    alignItems: 'center', justifyContent: 'center', alignSelf: 'stretch',
    marginHorizontal: 40, paddingVertical: 14, borderRadius: radius.md,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  plainBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
