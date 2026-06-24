import { Ionicons } from '@expo/vector-icons';
import Constants from 'expo-constants';
import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import * as Updates from 'expo-updates';
import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, Divider, NavBar } from '@/components/ui';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

const VERSION = Constants.expoConfig?.version ?? '1.0.1';

export default function About() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const [checking, setChecking] = useState(false);

  async function checkUpdate() {
    if (checking) return;
    setChecking(true);
    try {
      if (!Updates.isEnabled) {
        notify(t('aboutUpToDate'));
        return;
      }
      const res = await Updates.checkForUpdateAsync();
      if (res.isAvailable) {
        await Updates.fetchUpdateAsync();
        const ok = await confirmAsync(t('aboutUpdateReady'), t('aboutUpdateReadyMsg'), {
          confirmLabel: t('aboutRestart'), cancelLabel: t('authCancel'),
        });
        if (ok) await Updates.reloadAsync();
      } else {
        notify(t('aboutUpToDate'));
      }
    } catch {
      notify(t('aboutUpToDate'));
    } finally {
      setChecking(false);
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('aboutTitle')} onBack={() => router.back()} />

      <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 20, paddingBottom: 40 }}>
        {/* App identity */}
        <View style={styles.header}>
          <Image source={require('../../assets/images/icon.png')} style={styles.appIcon} contentFit="cover" />
          <Text style={[styles.appName, { color: c.ink }]}>Wefluens Connect</Text>
          <Text style={[styles.version, { color: c.inkSecondary }]}>{t('aboutVersion')} {VERSION}</Text>
        </View>

        <Card style={{ paddingVertical: 4 }}>
          <Row
            icon="refresh"
            title={t('aboutCheckUpdate')}
            right={checking ? <ActivityIndicator color={c.coral} /> : undefined}
            onPress={checkUpdate}
          />
          <Divider inset={64} />
          <Row icon="lock-closed" title={t('legalPrivacy')} onPress={() => router.push({ pathname: '/legal', params: { doc: 'privacy' } })} />
          <Divider inset={64} />
          <Row icon="document-text" title={t('legalTerms')} onPress={() => router.push({ pathname: '/legal', params: { doc: 'terms' } })} last />
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

function Row({
  icon, title, right, onPress, last,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  right?: React.ReactNode;
  onPress: () => void;
  last?: boolean;
}) {
  const c = useTheme();
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : 'transparent' }]}
    >
      <View style={[styles.iconBadge, { backgroundColor: c.coral + '1A' }]}>
        <Ionicons name={icon} size={16} color={c.coral} />
      </View>
      <Text style={[styles.rowTitle, { color: c.ink }]}>{title}</Text>
      {right ?? <Ionicons name="chevron-forward" size={15} color={c.inkTertiary} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: { alignItems: 'center', marginBottom: 22 },
  appIcon: { width: 88, height: 88, borderRadius: 20 },
  appName: { fontSize: 20, fontWeight: '700', marginTop: 14 },
  version: { fontSize: 14, fontWeight: '500', marginTop: 4, fontVariant: ['tabular-nums'] },
  row: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 14, paddingVertical: 13 },
  iconBadge: { width: 36, height: 36, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
  rowTitle: { flex: 1, fontSize: 15, fontWeight: '500' },
});
