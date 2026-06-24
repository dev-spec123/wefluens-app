import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView,
  StyleSheet, Text, TextInput, Vibration, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Card, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { getRemarks, setRemark } from '@/lib/friendPrefs';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, gradients, radius, useTheme } from '@/lib/theme';

export default function ContactDetail() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { block, refreshContacts, contacts } = useAppData();
  const params = useLocalSearchParams<{
    id: string; name?: string; handle?: string; role?: string; followers?: string; avatarUrl?: string;
  }>();

  const id = params.id;
  const name = params.name ?? 'User';
  const handle = params.handle ?? '';
  const role = params.role ?? '';
  const followers = params.followers ?? '0';
  const avatarUrl = params.avatarUrl ?? null;
  const colors = avatarGradient(id);

  // Live contact record (when this friend is in the loaded list) so platform /
  // online presence reflect the real values, mirroring Swift's Contact.platform
  // / Contact.isOnline. Route params carry only the lightweight summary fields.
  const contact = contacts.find((ct) => ct.id === id);
  const platform = contact?.platform ?? '';
  const isOnline = contact?.isOnline ?? false;

  const [opening, setOpening] = useState(false);
  const [removing, setRemoving] = useState(false);

  // Local friend remark (备注) — overrides the displayed name in Contacts.
  const [remark, setRemarkState] = useState('');
  const [remarkEditing, setRemarkEditing] = useState(false);
  const [remarkDraft, setRemarkDraft] = useState('');

  useEffect(() => {
    let active = true;
    getRemarks().then((m) => { if (active) setRemarkState(m[id]?.trim() ?? ''); });
    return () => { active = false; };
  }, [id]);

  function openRemarkEditor() {
    setRemarkDraft(remark);
    setRemarkEditing(true);
  }

  async function saveRemark() {
    const next = remarkDraft.trim();
    await setRemark(id, next);
    setRemarkState(next);
    setRemarkEditing(false);
  }

  async function startChat() {
    if (opening) return;
    setOpening(true);
    try {
      const threadId = await api.getOrCreateThread(id);
      router.replace({
        pathname: '/chat/[threadId]',
        params: { threadId, otherUserId: id, title: name, avatarUrl: avatarUrl ?? '' },
      });
    } catch {
      Alert.alert(t('chatStartError'));
    } finally {
      setOpening(false);
    }
  }

  function confirmRemove() {
    Alert.alert(t('contactDetailRemoveFriend'), t('contactDetailRemoveFriendMsg'), [
      { text: t('authCancel'), style: 'cancel' },
      { text: t('contactDetailRemoveFriend'), style: 'destructive', onPress: removeFriend },
    ]);
  }

  async function removeFriend() {
    if (removing) return;
    setRemoving(true);
    try {
      await api.removeFriend(id);
      Vibration.vibrate(40);
      await refreshContacts();
      router.back();
    } catch {
      Alert.alert(t('contactDetailRemoveFriendMsg'));
      setRemoving(false);
    }
  }

  function confirmBlock() {
    Alert.alert(t('blockAction'), t('blockConfirm'), [
      { text: t('authCancel'), style: 'cancel' },
      {
        text: t('blockAction'),
        style: 'destructive',
        onPress: async () => {
          try {
            await block(id);
            Vibration.vibrate(40);
            router.back();
          } catch {
            Alert.alert(t('blockError'));
          }
        },
      },
    ]);
  }

  function openMenu() {
    Alert.alert(name, undefined, [
      { text: t('reportTitle'), onPress: () => router.push({ pathname: '/report', params: { reportedUserId: id, blockableUserId: id } }) },
      { text: t('blockAction'), style: 'destructive', onPress: confirmBlock },
      { text: t('authCancel'), style: 'cancel' },
    ]);
  }

  function statItem(value: string, label: string) {
    return (
      <View style={styles.stat}>
        <Text style={[styles.statValue, { color: c.ink }]} numberOfLines={1}>{value || '—'}</Text>
        <Text style={[styles.statLabel, { color: c.inkSecondary }]}>{label}</Text>
      </View>
    );
  }

  function infoRow(icon: keyof typeof Ionicons.glyphMap, title: string, value: string) {
    return (
      <View style={styles.infoRow}>
        <View style={[styles.infoIcon, { backgroundColor: c.coral + '1A' }]}>
          <Ionicons name={icon} size={16} color={c.coral} />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={[styles.infoTitle, { color: c.inkSecondary }]}>{title}</Text>
          <Text style={[styles.infoValue, { color: c.ink }]}>{value || '—'}</Text>
        </View>
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingBottom: 30 }}>
        {/* Hero */}
        <View style={styles.heroWrap}>
          <LinearGradient
            colors={gradients.dusk}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.hero}
          >
            <Avatar colors={colors} name={name} imageUrl={avatarUrl} size={96} online={isOnline} />
            <View style={{ alignItems: 'center', marginTop: 14, gap: 4 }}>
              <Text style={styles.heroName} numberOfLines={1}>{remark || name}</Text>
              {remark ? (
                <Text style={styles.heroHandle} numberOfLines={1}>{`${t('contactsRemark')} · ${name}`}</Text>
              ) : null}
              {handle ? <Text style={styles.heroHandle} numberOfLines={1}>{handle}</Text> : null}
            </View>
            {role ? <View style={{ marginTop: 12 }}><TagChip text={role} filled /></View> : null}
          </LinearGradient>
        </View>

        {/* Stats */}
        <Card style={{ marginTop: 20 }}>
          <View style={styles.statsRow}>
            {statItem(followers, t('contactDetailFollowers'))}
            <View style={[styles.statDivider, { backgroundColor: c.hairline }]} />
            {statItem(platform, t('contactDetailPlatform'))}
            <View style={[styles.statDivider, { backgroundColor: c.hairline }]} />
            {statItem(isOnline ? t('contactDetailOnline') : t('contactDetailAway'), t('contactDetailStatus'))}
          </View>
        </Card>

        {/* Message action */}
        <Pressable onPress={startChat} disabled={opening} style={{ marginTop: 20 }}>
          <LinearGradient
            colors={gradients.sunset}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.messageBtn}
          >
            {opening ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <>
                <Ionicons name="chatbubble" size={18} color="#fff" />
                <Text style={styles.messageBtnText}>{t('contactDetailMessage')}</Text>
              </>
            )}
          </LinearGradient>
        </Pressable>

        {/* Set remark */}
        <Pressable onPress={openRemarkEditor} style={{ marginTop: 20 }}>
          <Card style={{ padding: 18 }}>
            <View style={styles.infoRow}>
              <View style={[styles.infoIcon, { backgroundColor: c.coral + '1A' }]}>
                <Ionicons name="pricetag" size={16} color={c.coral} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={[styles.infoTitle, { color: c.inkSecondary }]}>{t('contactsRemark')}</Text>
                <Text
                  style={[styles.infoValue, { color: remark ? c.ink : c.inkTertiary }]}
                  numberOfLines={1}
                >
                  {remark || t('contactsRemarkPlaceholder')}
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={c.inkTertiary} />
            </View>
          </Card>
        </Pressable>

        {/* Details */}
        <Card style={{ marginTop: 20, padding: 18 }}>
          <Text style={[styles.detailsHeader, { color: c.ink }]}>{t('contactDetailDetails')}</Text>
          <View style={{ gap: 16, marginTop: 16 }}>
            {infoRow('at', t('contactDetailHandle'), handle)}
            {infoRow('person-circle', t('contactDetailRole'), role)}
            {infoRow('bar-chart', t('contactDetailAudience'), platform ? `${followers} ${t('contactDetailAudienceOn')} ${platform}` : followers)}
          </View>
        </Card>

        {/* Delete friend */}
        <Pressable onPress={confirmRemove} disabled={removing} style={[styles.removeBtn, { backgroundColor: c.danger + '1A' }]}>
          {removing ? (
            <ActivityIndicator color={c.danger} />
          ) : (
            <>
              <Ionicons name="person-remove" size={16} color={c.danger} />
              <Text style={[styles.removeBtnText, { color: c.danger }]}>{t('contactDetailRemoveFriend')}</Text>
            </>
          )}
        </Pressable>
      </ScrollView>

      {/* Top-left back */}
      <Pressable onPress={() => router.back()} style={[styles.overlayBtn, { left: 18 }]}>
        <Ionicons name="chevron-back" size={20} color="#fff" />
      </Pressable>

      {/* Top-right overflow */}
      <Pressable onPress={openMenu} style={[styles.overlayBtn, { right: 18 }]}>
        <Ionicons name="ellipsis-horizontal" size={20} color="#fff" />
      </Pressable>

      {/* Remark editor */}
      <Modal visible={remarkEditing} transparent animationType="fade" onRequestClose={() => setRemarkEditing(false)}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.modalScrim}
        >
          <Pressable style={StyleSheet.absoluteFill} onPress={() => setRemarkEditing(false)} />
          <View style={[styles.modalCard, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Text style={[styles.modalTitle, { color: c.ink }]}>{t('contactsSetRemark')}</Text>
            <TextInput
              value={remarkDraft}
              onChangeText={setRemarkDraft}
              placeholder={t('contactsRemarkPlaceholder')}
              placeholderTextColor={c.inkTertiary}
              style={[styles.modalInput, { color: c.ink, backgroundColor: c.cardSubtle, borderColor: c.hairline }]}
              autoFocus
              maxLength={40}
              returnKeyType="done"
              onSubmitEditing={saveRemark}
            />
            <View style={styles.modalActions}>
              <Pressable
                onPress={() => setRemarkEditing(false)}
                style={[styles.modalBtn, { backgroundColor: c.cardSubtle }]}
              >
                <Text style={[styles.modalBtnText, { color: c.inkSecondary }]}>{t('authCancel')}</Text>
              </Pressable>
              <Pressable onPress={saveRemark} style={[styles.modalBtn, { backgroundColor: c.coral }]}>
                <Text style={[styles.modalBtnText, { color: '#fff' }]}>{t('editProfileSave')}</Text>
              </Pressable>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  heroWrap: { borderRadius: 28, overflow: 'hidden' },
  hero: { alignItems: 'center', paddingTop: 56, paddingBottom: 30, paddingHorizontal: 18 },
  heroName: { color: '#fff', fontSize: 24, fontWeight: '700' },
  heroHandle: { color: 'rgba(255,255,255,0.8)', fontSize: 15, fontWeight: '500' },
  statsRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 18 },
  stat: { flex: 1, alignItems: 'center', paddingHorizontal: 6 },
  statValue: { fontSize: 17, fontWeight: '700' },
  statLabel: { fontSize: 12, fontWeight: '500', marginTop: 4 },
  statDivider: { width: 1, height: 36 },
  messageBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderRadius: radius.pill, paddingVertical: 15 },
  messageBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  detailsHeader: { fontSize: 17, fontWeight: '700' },
  infoRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  infoIcon: { width: 38, height: 38, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  infoTitle: { fontSize: 12, fontWeight: '500' },
  infoValue: { fontSize: 15, fontWeight: '600', marginTop: 2 },
  removeBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, borderRadius: radius.pill, paddingVertical: 15, marginTop: 20 },
  removeBtnText: { fontSize: 16, fontWeight: '600' },
  overlayBtn: {
    position: 'absolute', top: 56, width: 40, height: 40, borderRadius: 20,
    backgroundColor: 'rgba(0,0,0,0.25)', alignItems: 'center', justifyContent: 'center',
  },
  modalScrim: {
    flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', alignItems: 'center', justifyContent: 'center', padding: 28,
  },
  modalCard: { width: '100%', maxWidth: 360, borderRadius: radius.card, borderWidth: 1, padding: 20 },
  modalTitle: { fontSize: 17, fontWeight: '700' },
  modalInput: {
    borderRadius: radius.md, borderWidth: 1, paddingHorizontal: 14, paddingVertical: 12,
    fontSize: 16, marginTop: 16,
  },
  modalActions: { flexDirection: 'row', gap: 10, marginTop: 18 },
  modalBtn: { flex: 1, borderRadius: radius.pill, paddingVertical: 12, alignItems: 'center' },
  modalBtnText: { fontSize: 15, fontWeight: '600' },
});
