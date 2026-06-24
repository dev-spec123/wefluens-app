import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import QRCode from 'react-native-qrcode-svg';

import { Avatar, NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, useTheme } from '@/lib/theme';

export default function MyQRCode() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId, email, profile } = useAuth();

  const name = profile?.name ?? email ?? 'You';
  const handle = profile?.handle ?? '';
  // Same payload the Swift app encodes, so codes are cross-compatible.
  const payload = userId ? `wefluens://user/${userId}` : '';

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('qrTitle')} onBack={() => router.back()} />

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.avatarShadow}>
          <Avatar colors={gradients.sunset} name={name} imageUrl={profile?.avatarUrl} size={80} online />
        </View>
        <Text style={[styles.name, { color: c.ink }]} numberOfLines={1}>{name}</Text>
        {handle.length > 0 ? (
          <Text style={[styles.handle, { color: c.inkSecondary }]} numberOfLines={1}>@{handle}</Text>
        ) : null}

        {/* QR card — only when signed in; otherwise a sign-in prompt */}
        {userId ? (
          <>
            <View style={[styles.qrCard, { borderColor: c.hairline }]}>
              <QRCode value={payload} size={220} backgroundColor="#fff" color="#1a1410" ecl="M" />
            </View>
            <Text style={[styles.idHint, { color: c.inkTertiary }]}>
              {userId.slice(0, 12).toUpperCase()}…
            </Text>
          </>
        ) : (
          <Text style={[styles.signInPrompt, { color: c.inkSecondary }]}>{t('qrSignInPrompt')}</Text>
        )}

        <Text style={[styles.scanTitle, { color: c.ink }]}>{t('qrScanToAdd')}</Text>
        <Text style={[styles.scanSub, { color: c.inkSecondary }]}>{t('qrScanToAddSub')}</Text>

        {/* Scan someone else's code */}
        <Pressable onPress={() => router.push('/qr-scan')} style={{ alignSelf: 'stretch', marginTop: 22 }}>
          <LinearGradient
            colors={gradients.sunset}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.scanBtn}
          >
            <Ionicons name="scan" size={20} color="#fff" />
            <Text style={styles.scanBtnText}>{t('qrScanButton')}</Text>
          </LinearGradient>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  content: { alignItems: 'center', paddingHorizontal: 24, paddingTop: 18, paddingBottom: 36 },
  avatarShadow: {
    borderRadius: 40,
    shadowColor: '#000', shadowOpacity: 0.12, shadowRadius: 14, shadowOffset: { width: 0, height: 8 },
  },
  signInPrompt: { fontSize: 15, textAlign: 'center', marginTop: 24, paddingHorizontal: 20, lineHeight: 21 },
  name: { fontSize: 22, fontWeight: '700', marginTop: 12 },
  handle: { fontSize: 14, fontWeight: '500', marginTop: 3 },
  qrCard: {
    backgroundColor: '#fff', borderRadius: 20, borderWidth: 1, padding: 20, marginTop: 24,
    shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 4,
  },
  idHint: { fontSize: 11, fontWeight: '500', marginTop: 14, fontVariant: ['tabular-nums'] },
  scanTitle: { fontSize: 16, fontWeight: '700', marginTop: 22 },
  scanSub: { fontSize: 13, textAlign: 'center', marginTop: 6, paddingHorizontal: 20, lineHeight: 19 },
  scanBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10,
    paddingVertical: 16, borderRadius: radius.md,
  },
  scanBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
