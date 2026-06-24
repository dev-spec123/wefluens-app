import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { type Href, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  Linking, Platform, Pressable, RefreshControl, ScrollView, StyleSheet, Switch, Text, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Constants from 'expo-constants';
import * as StoreReview from 'expo-store-review';

import { Avatar, Card } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { getOpenToDeals, setOpenToDeals } from '@/lib/openToDeals';
import { registerForPushNotifications } from '@/lib/pushService';
import { gradients, radius, useTheme } from '@/lib/theme';

export default function MeScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { email, profile, isAdmin, signOut, refreshProfile } = useAuth();

  const [refreshing, setRefreshing] = useState(false);
  const [openDeals, setOpenDeals] = useState(true);
  const [notifEnabled, setNotifEnabled] = useState(profile?.notificationsEnabled ?? false);

  useEffect(() => {
    let active = true;
    getOpenToDeals().then((v) => { if (active) setOpenDeals(v); }).catch(() => {});
    return () => { active = false; };
  }, []);

  function toggleOpenDeals(v: boolean) {
    setOpenDeals(v);
    void setOpenToDeals(v);
  }

  // Keep the toggle in sync with the loaded profile, and refresh the push token
  // on launch when notifications are already enabled.
  useEffect(() => {
    if (!profile) return;
    setNotifEnabled(profile.notificationsEnabled);
    if (profile.notificationsEnabled) void registerForPushNotifications(profile.id);
  }, [profile?.id, profile?.notificationsEnabled]);

  async function onToggleNotifications(v: boolean) {
    if (!profile) return;
    if (v) {
      setNotifEnabled(true);
      const token = await registerForPushNotifications(profile.id);
      if (!token) {
        // Permission denied or unavailable — revert and point to system settings.
        setNotifEnabled(false);
        openNotificationSettings();
        return;
      }
      try { await api.setNotificationsEnabled(profile.id, true); await refreshProfile(); }
      catch { setNotifEnabled(false); }
    } else {
      setNotifEnabled(false);
      try { await api.setNotificationsEnabled(profile.id, false); await refreshProfile(); }
      catch { setNotifEnabled(true); }
    }
  }

  const name = profile?.name ?? email ?? 'User';
  const roleLine = profile?.role && profile.role.length ? profile.role : (email ?? '');

  async function onRefresh() {
    setRefreshing(true);
    try {
      await refreshProfile();
    } finally {
      setRefreshing(false);
    }
  }

  function openNotificationSettings() {
    if (Platform.OS === 'web') {
      notify(t('profileNotifications'), 'Manage notifications in your phone’s system settings.');
      return;
    }
    Linking.openSettings().catch(() => {});
  }

  function openHelp() {
    // '/support' is a new route; cast until expo-router regenerates typed routes.
    router.push('/support' as Href);
  }

  // Rating is split per store: Android → Google Play, iOS → App Store. (Apple
  // does NOT require an in-app rate button — this is purely a convenience link.)
  async function rateApp() {
    const playPackage = 'com.wefluens.connect';
    const iosAppId = (Constants.expoConfig?.extra as { iosAppStoreId?: string } | undefined)?.iosAppStoreId;
    try {
      if (Platform.OS === 'android') {
        const market = `market://details?id=${playPackage}`;
        const canMarket = await Linking.canOpenURL(market);
        await Linking.openURL(canMarket ? market : `https://play.google.com/store/apps/details?id=${playPackage}`);
        return;
      }
      if (Platform.OS === 'ios') {
        if (iosAppId) {
          await Linking.openURL(`https://apps.apple.com/app/id${iosAppId}?action=write-review`);
          return;
        }
        // No published App Store ID yet — use the native review sheet if offered.
        if (await StoreReview.isAvailableAsync()) {
          await StoreReview.requestReview();
          return;
        }
      }
    } catch {
      // fall through to the notice below
    }
    notify(t('profileRate'), t('rateComingSoon'));
  }

  async function confirmDelete() {
    const ok = await confirmAsync(t('profileDeleteAccount'), t('profileDeleteAccountConfirm'), {
      confirmLabel: t('profileDeleteAccount'),
      cancelLabel: t('authCancel'),
      destructive: true,
    });
    if (!ok) return;
    try {
      await api.deleteAccount();
    } catch {
      // best effort — still sign out
    } finally {
      await signOut();
    }
  }

  function MenuRow({
    icon, title, onPress, color, last,
  }: {
    icon: keyof typeof Ionicons.glyphMap;
    title: string;
    onPress: () => void;
    color?: string;
    last?: boolean;
  }) {
    const tint = color ?? c.coral;
    return (
      <View>
        <Pressable
          onPress={onPress}
          style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : 'transparent' }]}
        >
          <View style={[styles.iconBadge, { backgroundColor: tint + '1A' }]}>
            <Ionicons name={icon} size={16} color={tint} />
          </View>
          <Text style={[styles.rowTitle, { color: color ?? c.ink }]}>{title}</Text>
          <Ionicons name="chevron-forward" size={15} color={c.inkTertiary} />
        </Pressable>
        {!last ? (
          <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: 64 }} />
        ) : null}
      </View>
    );
  }

  function ToggleRow({
    icon, title, value, onValueChange, last,
  }: {
    icon: keyof typeof Ionicons.glyphMap;
    title: string;
    value: boolean;
    onValueChange: (v: boolean) => void;
    last?: boolean;
  }) {
    return (
      <View>
        <View style={styles.row}>
          <View style={[styles.iconBadge, { backgroundColor: c.coral + '1A' }]}>
            <Ionicons name={icon} size={16} color={c.coral} />
          </View>
          <Text style={[styles.rowTitle, { color: c.ink }]}>{title}</Text>
          <Switch
            value={value}
            onValueChange={onValueChange}
            trackColor={{ false: c.hairline, true: c.coral }}
            thumbColor="#fff"
            ios_backgroundColor={c.hairline}
          />
        </View>
        {!last ? (
          <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: 64 }} />
        ) : null}
      </View>
    );
  }

  function GroupTitle({ text }: { text: string }) {
    return <Text style={[styles.groupTitle, { color: c.inkTertiary }]}>{text.toUpperCase()}</Text>;
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />
        }
      >
        {/* Hero card with dusk gradient banner */}
        <View style={styles.heroWrap}>
          <LinearGradient
            colors={gradients.dusk}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.heroBanner}
          />
          <View style={[styles.heroCard, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <View style={[styles.avatarRing, { borderColor: c.paper }]}>
              <Avatar
                colors={gradients.sunset}
                name={name}
                imageUrl={profile?.avatarUrl}
                size={92}
                online
              />
            </View>

            <View style={{ alignItems: 'center', gap: 4, marginTop: 12 }}>
              <Text style={[styles.heroName, { color: c.ink }]} numberOfLines={1}>{name}</Text>
              {roleLine ? (
                <Text style={[styles.heroRole, { color: c.inkSecondary }]} numberOfLines={1}>{roleLine}</Text>
              ) : null}
            </View>

            {isAdmin ? (
              <View style={[styles.adminBadge, { backgroundColor: c.coral }]}>
                <Ionicons name="shield-checkmark" size={11} color="#fff" />
                <Text style={styles.adminBadgeText}>ADMIN</Text>
              </View>
            ) : null}

            {profile?.bio ? (
              <Text style={[styles.heroBio, { color: c.inkSecondary }]}>{profile.bio}</Text>
            ) : null}

            {profile?.location ? (
              <View style={styles.locationRow}>
                <Ionicons name="location-outline" size={12} color={c.inkSecondary} />
                <Text style={[styles.locationText, { color: c.inkSecondary }]}>{profile.location}</Text>
              </View>
            ) : null}

            <Pressable
              onPress={() => router.push('/edit-profile')}
              style={[styles.editBtn, { backgroundColor: c.coral + '1A' }]}
            >
              <Text style={[styles.editBtnText, { color: c.coral }]}>{t('profileEdit')}</Text>
            </Pressable>
          </View>
        </View>

        {/* Stats */}
        <Card style={styles.statsCard}>
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: c.ink }]}>{profile?.followers ?? '0'}</Text>
            <Text style={[styles.statLabel, { color: c.inkSecondary }]}>{t('profileReach')}</Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: c.hairline }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: c.ink }]}>{profile?.engagement ?? '0%'}</Text>
            <Text style={[styles.statLabel, { color: c.inkSecondary }]}>{t('profileEngagement')}</Text>
          </View>
          <View style={[styles.statDivider, { backgroundColor: c.hairline }]} />
          <View style={styles.statItem}>
            <Text style={[styles.statValue, { color: c.ink }]}>{profile?.deals ?? '0'}</Text>
            <Text style={[styles.statLabel, { color: c.inkSecondary }]}>{t('profileDeals')}</Text>
          </View>
        </Card>

        {/* Open to new deals */}
        <Card style={styles.dealCard}>
          <View style={[styles.iconBadge, { backgroundColor: c.coral, borderRadius: 14, width: 44, height: 44 }]}>
            <Ionicons name="flash" size={20} color="#fff" />
          </View>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={[styles.dealTitle, { color: c.ink }]}>{t('profileOpenDeals')}</Text>
            <Text style={[styles.dealSub, { color: c.inkSecondary }]} numberOfLines={2}>{t('profileOpenDealsSub')}</Text>
          </View>
          <Switch
            value={openDeals}
            onValueChange={toggleOpenDeals}
            trackColor={{ false: c.hairline, true: c.coral }}
            thumbColor="#fff"
            ios_backgroundColor={c.hairline}
          />
        </Card>

        {/* Add Friends via QR */}
        <Pressable onPress={() => router.push('/qr')}>
          {({ pressed }) => (
            <Card style={[styles.dealCard, pressed && { opacity: 0.7 }]}>
              <View style={[styles.iconBadge, { backgroundColor: c.plum, borderRadius: 14, width: 44, height: 44 }]}>
                <Ionicons name="qr-code" size={20} color="#fff" />
              </View>
              <View style={{ flex: 1, marginLeft: 12 }}>
                <Text style={[styles.dealTitle, { color: c.ink }]}>{t('profileAddViaQr')}</Text>
                <Text style={[styles.dealSub, { color: c.inkSecondary }]} numberOfLines={2}>{t('profileAddViaQrSub')}</Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={c.inkTertiary} />
            </Card>
          )}
        </Pressable>

        {/* Preferences */}
        <GroupTitle text={t('profilePreferences')} />
        <Card style={styles.menuCard}>
          <MenuRow icon="bookmark" title={t('favoritesTitle')} onPress={() => router.push('/favorites')} />
          <ToggleRow icon="notifications" title={t('profileNotifications')} value={notifEnabled} onValueChange={onToggleNotifications} />
          <MenuRow icon="lock-closed" title={t('profilePrivacy')} onPress={() => router.push('/privacy')} />
          <MenuRow icon="settings-outline" title={t('settingsTitle')} onPress={() => router.push('/settings')} last />
        </Card>

        {/* Admin */}
        {isAdmin ? (
          <>
            <GroupTitle text="ADMIN" />
            <Card style={styles.menuCard}>
              <MenuRow icon="shield-checkmark" title={t('profileAdmin')} onPress={() => router.push('/admin')} last />
            </Card>
          </>
        ) : null}

        {/* Support */}
        <GroupTitle text={t('profileSupport')} />
        <Card style={styles.menuCard}>
          <MenuRow icon="mail" title={t('profileHelp')} onPress={openHelp} />
          <MenuRow icon="star" title={t('profileRate')} onPress={rateApp} />
          <MenuRow icon="information-circle" title={t('profileAbout')} onPress={() => router.push('/about')} last />
        </Card>

        {/* Account actions */}
        <Card style={styles.menuCard}>
          <MenuRow icon="log-out" title={t('profileSignOut')} color={c.danger} onPress={() => signOut()} />
          <MenuRow icon="trash" title={t('profileDeleteAccount')} color={c.danger} onPress={confirmDelete} last />
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  content: { paddingHorizontal: 18, paddingTop: 8, paddingBottom: 32, gap: 14 },

  heroWrap: { marginTop: 8 },
  heroBanner: {
    height: 110,
    borderRadius: 28,
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
  },
  heroCard: {
    marginTop: 64,
    borderRadius: 28,
    borderWidth: 1,
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingBottom: 20,
    paddingTop: 56,
  },
  avatarRing: {
    borderRadius: 999,
    borderWidth: 5,
  },
  heroName: { fontSize: 22, fontWeight: '700' },
  heroRole: { fontSize: 14, fontWeight: '500' },
  adminBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: radius.pill,
    marginTop: 10,
  },
  adminBadgeText: { color: '#fff', fontSize: 11, fontWeight: '700', letterSpacing: 0.5 },
  heroBio: { fontSize: 14, textAlign: 'center', marginTop: 12, lineHeight: 20, paddingHorizontal: 8 },
  locationRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 10 },
  locationText: { fontSize: 13, fontWeight: '500' },
  editBtn: {
    marginTop: 14,
    alignSelf: 'stretch',
    alignItems: 'center',
    paddingVertical: 12,
    borderRadius: radius.pill,
  },
  editBtnText: { fontSize: 15, fontWeight: '600' },

  dealCard: { flexDirection: 'row', alignItems: 'center', paddingVertical: 16, paddingHorizontal: 16 },
  dealTitle: { fontSize: 15, fontWeight: '700' },
  dealSub: { fontSize: 12, marginTop: 2 },
  statsCard: { flexDirection: 'row', alignItems: 'center', paddingVertical: 18 },
  statItem: { flex: 1, alignItems: 'center', gap: 4 },
  statValue: { fontSize: 19, fontWeight: '700' },
  statLabel: { fontSize: 12, fontWeight: '500' },
  statDivider: { width: 1, height: 36 },

  groupTitle: { fontSize: 12, fontWeight: '700', letterSpacing: 1, marginLeft: 4, marginTop: 6, marginBottom: -4 },
  menuCard: { paddingVertical: 4 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: 14,
    paddingVertical: 13,
  },
  iconBadge: {
    width: 36,
    height: 36,
    borderRadius: 11,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowTitle: { flex: 1, fontSize: 15, fontWeight: '500' },
});
