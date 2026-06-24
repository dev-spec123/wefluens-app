import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, Pressable, ScrollView, Switch, Text, Vibration, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, Divider, GradientButton, NavBar } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { useTheme } from '@/lib/theme';
import type { ReportReason } from '@/lib/types';

const REASONS: { key: ReportReason; labelKey: string; icon: keyof typeof Ionicons.glyphMap }[] = [
  { key: 'spam', labelKey: 'reportReasonSpam', icon: 'megaphone' },
  { key: 'harassment', labelKey: 'reportReasonHarass', icon: 'person-remove' },
  { key: 'hate', labelKey: 'reportReasonHate', icon: 'hand-left' },
  { key: 'sexual', labelKey: 'reportReasonSexual', icon: 'eye-off' },
  { key: 'violence', labelKey: 'reportReasonViolence', icon: 'warning' },
  { key: 'other', labelKey: 'reportReasonOther', icon: 'ellipsis-horizontal-circle' },
];

export default function Report() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();
  const { block } = useAppData();
  const params = useLocalSearchParams<{
    reportedUserId?: string; messageId?: string; messageKind?: string; excerpt?: string; blockableUserId?: string;
  }>();

  const [selected, setSelected] = useState<ReportReason | null>(null);
  const [alsoBlock, setAlsoBlock] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  const blockable = params.blockableUserId || params.reportedUserId || null;

  async function submit() {
    if (!selected || !userId) return;
    setBusy(true);
    try {
      await api.report({
        uid: userId,
        reportedUserId: params.reportedUserId ?? null,
        messageId: params.messageId ?? null,
        messageKind: params.messageKind ?? null,
        excerpt: params.excerpt ?? null,
        reason: selected,
      });
      if (alsoBlock && blockable) await block(blockable).catch(() => {});
      // Match Swift's UINotificationFeedbackGenerator(.success) on submit.
      Vibration.vibrate(40);
      setDone(true);
    } catch {
      Alert.alert(t('reportError'));
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }}>
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 30 }}>
          <Ionicons name="shield-checkmark" size={56} color={c.coral} />
          <Text style={{ color: c.ink, fontSize: 22, fontWeight: '700', marginTop: 18 }}>{t('reportThanksTitle')}</Text>
          <Text style={{ color: c.inkSecondary, fontSize: 15, textAlign: 'center', marginTop: 10 }}>{t('reportThanksMessage')}</Text>
          <GradientButton title={t('settingsDone')} onPress={() => router.back()} style={{ marginTop: 28, alignSelf: 'stretch' }} />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar
        title={t('reportTitle')}
        right={<Pressable onPress={() => router.back()}><Text style={{ color: c.coral, fontWeight: '600' }}>{t('authCancel')}</Text></Pressable>}
      />
      <ScrollView contentContainerStyle={{ padding: 18, paddingBottom: 30 }}>
        <Text style={{ color: c.inkSecondary, fontSize: 14, paddingHorizontal: 4, marginBottom: 16 }}>{t('reportSubtitle')}</Text>
        <Card>
          {REASONS.map((r, i) => (
            <View key={r.key}>
              <Pressable onPress={() => { Vibration.vibrate(10); setSelected(r.key); }} style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 13, gap: 14 }}>
                <Ionicons name={r.icon} size={18} color={c.coral} style={{ width: 26 }} />
                <Text style={{ flex: 1, color: c.ink, fontSize: 15, fontWeight: '500' }}>{t(r.labelKey)}</Text>
                <Ionicons name={selected === r.key ? 'checkmark-circle' : 'ellipse-outline'} size={20} color={selected === r.key ? c.coral : c.inkTertiary} />
              </Pressable>
              {i < REASONS.length - 1 && <Divider inset={54} />}
            </View>
          ))}
        </Card>

        {blockable && (
          <Card style={{ marginTop: 14 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 12 }}>
              <Text style={{ flex: 1, color: c.ink, fontSize: 15, fontWeight: '500' }}>{t('reportAlsoBlock')}</Text>
              <Switch value={alsoBlock} onValueChange={setAlsoBlock} trackColor={{ true: c.coral }} />
            </View>
          </Card>
        )}

        <GradientButton title={t('reportSubmit')} onPress={submit} loading={busy} disabled={!selected} style={{ marginTop: 18 }} />
      </ScrollView>
    </SafeAreaView>
  );
}
