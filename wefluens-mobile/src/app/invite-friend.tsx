/**
 * Invite a Friend — the signed-in user's personal shareable invite code
 * (Wefluens is invite-only). Fetches / mints the code via get_or_create_my_invite_code,
 * shows uses left, and offers Copy + Share. Admins can revoke any code from the
 * iOS Developer panel.
 */
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, NavBar } from '@/components/ui';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { gradients, useTheme } from '@/lib/theme';

export default function InviteFriend() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const [info, setInfo] = useState<api.MyInviteCode | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await api.getMyInviteCode();
        if (active) setInfo(res);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, []);

  const shareText = info ? `${t('inviteFriendShareMessage')} ${info.code}` : '';

  async function onCopy() {
    if (!info) return;
    await Clipboard.setStringAsync(info.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }
  async function onShare() {
    if (!info) return;
    try { await Share.share({ message: shareText }); } catch { /* dismissed */ }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('inviteFriendTitle')} onBack={() => router.back()} />

      {loading ? (
        <View style={styles.center}><ActivityIndicator color={c.coral} /></View>
      ) : !info ? (
        <View style={styles.center}>
          <Text style={{ color: c.inkSecondary }}>{t('addFriendError')}</Text>
        </View>
      ) : (
        <View style={{ paddingHorizontal: 24, paddingTop: 8, alignItems: 'center' }}>
          <View style={[styles.iconWrap, { backgroundColor: c.coral + '1A' }]}>
            <Ionicons name="gift" size={40} color={c.coral} />
          </View>

          <Text style={[styles.intro, { color: c.inkSecondary }]}>{t('inviteFriendIntro')}</Text>

          <Card style={styles.codeCard}>
            <Text style={[styles.code, { color: c.ink }]}>{info.code}</Text>
            <Text style={[styles.remaining, { color: c.inkSecondary }]}>
              {Math.max(0, info.max_uses - info.uses)} {t('inviteFriendRemaining')}
            </Text>
          </Card>

          <View style={styles.buttons}>
            <Pressable onPress={onCopy} style={[styles.btn, { backgroundColor: c.coral + '1F' }]}>
              <Ionicons name={copied ? 'checkmark' : 'copy-outline'} size={16} color={c.coral} />
              <Text style={[styles.btnText, { color: c.coral }]}>
                {copied ? t('inviteFriendCopied') : t('inviteFriendCopy')}
              </Text>
            </Pressable>
            <Pressable onPress={onShare} style={{ flex: 1 }}>
              <LinearGradient
                colors={gradients.sunset}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.btnFilled}
              >
                <Ionicons name="share-outline" size={16} color="#fff" />
                <Text style={[styles.btnText, { color: '#fff' }]}>{t('inviteFriendShare')}</Text>
              </LinearGradient>
            </Pressable>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  iconWrap: { width: 84, height: 84, borderRadius: 42, alignItems: 'center', justifyContent: 'center', marginTop: 20 },
  intro: { fontSize: 14, textAlign: 'center', marginTop: 18, lineHeight: 20 },
  codeCard: { width: '100%', alignItems: 'center', paddingVertical: 26, marginTop: 22 },
  code: { fontSize: 34, fontWeight: '800', letterSpacing: 3 },
  remaining: { fontSize: 13, fontWeight: '600', marginTop: 8 },
  buttons: { flexDirection: 'row', gap: 12, marginTop: 22, width: '100%' },
  btn: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7, paddingVertical: 14, borderRadius: 999 },
  btnFilled: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7, paddingVertical: 14, borderRadius: 999 },
  btnText: { fontSize: 15, fontWeight: '600' },
});
