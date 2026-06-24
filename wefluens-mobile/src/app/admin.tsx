import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, FlatList, Modal, Pressable, RefreshControl, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ActionSheet } from '@/components/ActionSheet';
import { Avatar, Card, EmptyState, GradientButton, NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, radius, useTheme } from '@/lib/theme';
import type { AdminUser } from '@/lib/types';

export default function Admin() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { isAdmin, userId } = useAuth();

  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [menuUser, setMenuUser] = useState<AdminUser | null>(null);
  const [showInvite, setShowInvite] = useState(false);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviting, setInviting] = useState(false);

  const load = useCallback(async () => {
    try {
      const rows = await api.loadAllUsers();
      setUsers(rows);
    } catch {
      setUsers([]);
    }
  }, []);

  useEffect(() => {
    // Only reachable for admins; bounce non-admins out.
    if (!isAdmin) {
      router.back();
      return;
    }
    (async () => {
      setLoading(true);
      await load();
      setLoading(false);
    })();
  }, [isAdmin, load, router]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  async function doBan(user: AdminUser, ban: boolean) {
    const who = `${user.name} (${user.email})`;
    const ok = await confirmAsync(
      ban ? t('adminBan') : t('adminUnban'),
      `${who} ${ban ? t('adminBanConfirm') : t('adminUnbanConfirm')}`,
      {
        confirmLabel: ban ? t('adminBan') : t('adminUnban'),
        cancelLabel: t('authCancel'),
        destructive: ban,
      },
    );
    if (!ok) return;
    try {
      await api.adminBanUser(user.id, ban);
      await load();
    } catch {
      notify(t('authErrGeneric'));
    }
  }

  async function doSetAdmin(user: AdminUser, makeAdmin: boolean) {
    const who = `${user.name} (${user.email})`;
    const ok = await confirmAsync(
      makeAdmin ? t('adminMakeAdmin') : t('adminRemoveAdmin'),
      `${who} ${makeAdmin ? t('adminMakeAdminConfirm') : t('adminRemoveAdminConfirm')}`,
      {
        confirmLabel: makeAdmin ? t('adminMakeAdmin') : t('adminRemoveAdmin'),
        cancelLabel: t('authCancel'),
        destructive: !makeAdmin,
      },
    );
    if (!ok) return;
    try {
      await api.adminSetAdmin(user.id, makeAdmin);
      await load();
      notify(makeAdmin ? t('adminMakeAdmin') : t('adminRemoveAdmin'));
    } catch {
      notify(t('authErrGeneric'));
    }
  }

  async function doDelete(user: AdminUser) {
    const ok = await confirmAsync(t('adminDelete'), t('adminDeleteConfirm'), {
      confirmLabel: t('adminDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await api.adminDeleteUser(user.id);
      await load();
    } catch {
      notify(t('authErrGeneric'));
    }
  }

  async function doInvite() {
    const email = inviteEmail.trim();
    if (!email) return;
    setInviting(true);
    try {
      const res = await api.adminInviteUser(email);
      if (res.ok === false) {
        notify(t('adminInviteFailed'), res.error);
      } else {
        notify(t('adminInviteSent'));
        setShowInvite(false);
        setInviteEmail('');
        await load();
      }
    } catch {
      notify(t('adminInviteFailed'));
    } finally {
      setInviting(false);
    }
  }

  function renderRow({ item, index }: { item: AdminUser; index: number }) {
    return (
      <View style={{ paddingHorizontal: 16, paddingTop: index === 0 ? 4 : 0, paddingBottom: 8 }}>
        <Card>
          <Pressable
            onPress={() => setMenuUser(item)}
            style={{ flexDirection: 'row', alignItems: 'center', padding: 12, gap: 12 }}
          >
            <Avatar colors={avatarGradient(item.id)} name={item.name} size={44} />
            <View style={{ flex: 1 }}>
              <Text style={{ color: c.ink, fontSize: 15, fontWeight: '600' }} numberOfLines={1}>
                {item.name}
              </Text>
              <Text style={{ color: c.inkSecondary, fontSize: 12, marginTop: 2 }} numberOfLines={1}>
                {item.email}
              </Text>
            </View>
            {item.isAdmin ? (
              <View style={[styles.badge, { backgroundColor: c.coral + '1A' }]}>
                <Text style={{ color: c.coral, fontSize: 11, fontWeight: '700' }}>{t('adminAdmin')}</Text>
              </View>
            ) : null}
            {item.banned ? (
              <View style={[styles.badge, { backgroundColor: c.danger + '1A' }]}>
                <Text style={{ color: c.danger, fontSize: 11, fontWeight: '700' }}>{t('adminBanned')}</Text>
              </View>
            ) : null}
          </Pressable>
        </Card>
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('adminTitle')} onBack={() => router.back()} />
      {loading ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <FlatList
          data={users}
          keyExtractor={(u) => u.id}
          renderItem={renderRow}
          ListHeaderComponent={
            <View style={styles.header}>
              <Text style={[styles.headerTitle, { color: c.inkSecondary }]}>{t('adminAllUsers')}</Text>
              <Pressable
                onPress={() => setShowInvite(true)}
                style={[styles.inviteBtn, { backgroundColor: c.coral + '14' }]}
                hitSlop={8}
              >
                <Text style={{ color: c.coral, fontSize: 13, fontWeight: '700' }}>+ {t('adminInvite')}</Text>
              </Pressable>
            </View>
          }
          ListEmptyComponent={<EmptyState icon="people-outline" title={t('adminNoUsers')} />}
          contentContainerStyle={{ paddingBottom: 24, flexGrow: 1 }}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />
          }
        />
      )}

      {menuUser ? (
        <ActionSheet
          visible={!!menuUser}
          title={menuUser.name}
          cancelLabel={t('authCancel')}
          onClose={() => setMenuUser(null)}
          actions={[
            // Hide the role action on the current admin's own row (the server also
            // rejects self-change). Everyone else can be promoted/demoted.
            ...(menuUser.id !== userId
              ? [
                  menuUser.isAdmin
                    ? { label: t('adminRemoveAdmin'), icon: 'shield-outline' as const, destructive: true, onPress: () => doSetAdmin(menuUser, false) }
                    : { label: t('adminMakeAdmin'), icon: 'shield-checkmark' as const, onPress: () => doSetAdmin(menuUser, true) },
                ]
              : []),
            menuUser.banned
              ? { label: t('adminUnban'), icon: 'checkmark-circle', onPress: () => doBan(menuUser, false) }
              : { label: t('adminBan'), icon: 'ban', onPress: () => doBan(menuUser, true) },
            { label: t('adminDelete'), icon: 'trash', destructive: true, onPress: () => doDelete(menuUser) },
          ]}
        />
      ) : null}

      <Modal visible={showInvite} transparent animationType="fade" onRequestClose={() => setShowInvite(false)}>
        <Pressable style={styles.scrim} onPress={() => setShowInvite(false)}>
          <Pressable style={[styles.modalCard, { backgroundColor: c.card }]} onPress={() => {}}>
            <View style={[styles.inviteIcon, { backgroundColor: c.coral + '26' }]}>
              <Ionicons name="paper-plane" size={30} color={c.coral} />
            </View>
            <Text style={[styles.modalTitle, { color: c.ink }]}>{t('adminInviteTitle')}</Text>
            <Text style={[styles.modalSubtitle, { color: c.inkSecondary }]}>{t('adminInviteSubtitle')}</Text>
            <TextInput
              value={inviteEmail}
              onChangeText={setInviteEmail}
              placeholder={t('adminInviteEmail')}
              placeholderTextColor={c.inkTertiary}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              style={[styles.modalInput, { color: c.ink, borderColor: c.hairline, backgroundColor: c.cardSubtle }]}
            />
            <GradientButton
              title={t('adminInviteSend')}
              onPress={doInvite}
              loading={inviting}
              disabled={!inviteEmail.trim()}
              style={{ marginTop: 12, alignSelf: 'stretch' }}
            />
          </Pressable>
        </Pressable>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 20, paddingTop: 8, paddingBottom: 10,
  },
  headerTitle: { fontSize: 13, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  inviteBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: radius.sm },
  badge: { paddingHorizontal: 8, paddingVertical: 3, borderRadius: radius.sm },
  scrim: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32 },
  modalCard: { width: '100%', borderRadius: radius.lg, padding: 20, alignItems: 'center' },
  inviteIcon: { width: 72, height: 72, borderRadius: 36, alignItems: 'center', justifyContent: 'center', marginBottom: 14 },
  modalTitle: { fontSize: 20, fontWeight: '700', textAlign: 'center' },
  modalSubtitle: { fontSize: 13, textAlign: 'center', marginTop: 6, marginBottom: 16, paddingHorizontal: 8, lineHeight: 18 },
  modalInput: { alignSelf: 'stretch', borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15 },
});
