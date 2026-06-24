import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, Divider, NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { setActivityStatus as persistActivityStatus, setDataSharing as persistDataSharing } from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

function IconBadge({ icon }: { icon: keyof typeof Ionicons.glyphMap }) {
  const c = useTheme();
  return (
    <View style={[styles.badge, { backgroundColor: c.coral + '1A' }]}>
      <Ionicons name={icon} size={16} color={c.coral} />
    </View>
  );
}

function GroupTitle({ text }: { text: string }) {
  const c = useTheme();
  return <Text style={[styles.groupTitle, { color: c.inkTertiary }]}>{text.toUpperCase()}</Text>;
}

function NavRow({
  icon, title, subtitle, onPress,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
  onPress: () => void;
}) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} style={styles.row}>
      <IconBadge icon={icon} />
      <View style={{ flex: 1 }}>
        <Text style={[styles.rowTitle, { color: c.ink }]}>{title}</Text>
        {subtitle ? <Text style={[styles.rowSub, { color: c.inkSecondary }]}>{subtitle}</Text> : null}
      </View>
      <Ionicons name="chevron-forward" size={16} color={c.inkTertiary} />
    </Pressable>
  );
}

function ToggleRow({
  icon, title, subtitle, value, onValueChange,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
  value: boolean;
  onValueChange: (v: boolean) => void;
}) {
  const c = useTheme();
  return (
    <View style={[styles.row, { paddingVertical: 9 }]}>
      <IconBadge icon={icon} />
      <View style={{ flex: 1 }}>
        <Text style={[styles.rowTitle, { color: c.ink }]}>{title}</Text>
        {subtitle ? <Text style={[styles.rowSub, { color: c.inkSecondary }]}>{subtitle}</Text> : null}
      </View>
      <Switch value={value} onValueChange={onValueChange} trackColor={{ true: c.coral }} />
    </View>
  );
}

export default function Privacy() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const { profile, refreshProfile } = useAuth();
  const [visibility, setVisibility] = useState(true);
  const [activityStatus, setActivityStatus] = useState(profile?.activityStatus ?? true);
  const [dataSharing, setDataSharing] = useState(profile?.dataSharing ?? true);

  // Seed from the loaded profile (it may arrive after first render).
  useEffect(() => {
    if (!profile) return;
    setActivityStatus(profile.activityStatus);
    setDataSharing(profile.dataSharing);
  }, [profile?.activityStatus, profile?.dataSharing]);

  // Optimistic toggle → persist to the profile → refresh; revert on failure.
  const onActivityChange = async (v: boolean) => {
    setActivityStatus(v);
    if (!profile) return;
    try { await persistActivityStatus(profile.id, v); await refreshProfile(); }
    catch { setActivityStatus(!v); }
  };
  const onDataSharingChange = async (v: boolean) => {
    setDataSharing(v);
    if (!profile) return;
    try { await persistDataSharing(profile.id, v); await refreshProfile(); }
    catch { setDataSharing(!v); }
  };

  const inset = 64;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('privacyTitle')} onBack={() => router.back()} />
      <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 12, paddingBottom: 30 }}>
        <GroupTitle text={t('privacyTitle')} />
        <Card style={{ paddingVertical: 4 }}>
          <NavRow
            icon="person-remove"
            title={t('privacyBlockedAccounts')}
            subtitle={t('privacyBlockedAccountsSub')}
            onPress={() => router.push('/blocked')}
          />
          <Divider inset={inset} />
          <NavRow
            icon="key"
            title={t('changePwTitle')}
            subtitle={t('changePwSubtitle')}
            onPress={() => router.push('/change-password')}
          />
          <Divider inset={inset} />
          <ToggleRow
            icon="eye"
            title={t('privacyVisibility')}
            subtitle={t('privacyVisibilitySub')}
            value={visibility}
            onValueChange={setVisibility}
          />
          <Divider inset={inset} />
          <ToggleRow
            icon="flash"
            title={t('privacyActivityStatus')}
            subtitle={t('privacyActivityStatusSub')}
            value={activityStatus}
            onValueChange={onActivityChange}
          />
          <Divider inset={inset} />
          <ToggleRow
            icon="git-branch"
            title={t('privacyDataSharing')}
            subtitle={t('privacyDataSharingSub')}
            value={dataSharing}
            onValueChange={onDataSharingChange}
          />
        </Card>

        <View style={{ height: 20 }} />

        <GroupTitle text={t('legalSafety')} />
        <Card style={{ paddingVertical: 4 }}>
          <NavRow
            icon="document-text"
            title={t('legalTerms')}
            onPress={() => router.push({ pathname: '/legal', params: { doc: 'terms' } })}
          />
          <Divider inset={inset} />
          <NavRow
            icon="shield-checkmark"
            title={t('legalGuidelines')}
            onPress={() => router.push({ pathname: '/legal', params: { doc: 'guidelines' } })}
          />
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  badge: { width: 36, height: 36, borderRadius: radius.sm, alignItems: 'center', justifyContent: 'center' },
  groupTitle: { fontSize: 12, fontWeight: '700', letterSpacing: 1, paddingLeft: 4, marginBottom: 10 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 14, paddingVertical: 12 },
  rowTitle: { fontSize: 15, fontWeight: '500' },
  rowSub: { fontSize: 12, marginTop: 2 },
});
