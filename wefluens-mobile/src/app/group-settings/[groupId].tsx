import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Modal, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, Vibration, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Divider, EmptyState, NavBar } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { getMutedSet, setMuted } from '@/lib/convPrefs';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, gradients, radius, useTheme } from '@/lib/theme';
import type { Contact, GroupMember } from '@/lib/types';

type MemberRelationship = 'self' | 'friends' | 'request_sent' | 'none';

export default function GroupSettings() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();
  const { conversations, refreshConversations, contacts, refreshContacts } = useAppData();
  const params = useLocalSearchParams<{ groupId: string; title?: string }>();
  const groupId = params.groupId;
  const initialName = params.title ?? '';

  const [members, setMembers] = useState<GroupMember[]>([]);
  const [currentName, setCurrentName] = useState(initialName);
  const [nameDraft, setNameDraft] = useState(initialName);
  const [loading, setLoading] = useState(true);
  const [savingName, setSavingName] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [muted, setMutedState] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [busyAvatar, setBusyAvatar] = useState(false);
  const [busyDanger, setBusyDanger] = useState(false);
  const [selectedMember, setSelectedMember] = useState<GroupMember | null>(null);

  const isOwner = useMemo(
    () => !!userId && (members.find((m) => m.id === userId)?.isOwner ?? false),
    [members, userId],
  );
  const existingIds = useMemo(() => new Set(members.map((m) => m.id)), [members]);

  // Mirrors Swift's haptics — expo-haptics isn't a dependency, so RN's built-in
  // Vibration stands in (no native add). selectionHaptic = UISelectionFeedbackGenerator;
  // successHaptic = UINotificationFeedbackGenerator(.success).
  const selectionHaptic = () => { if (Platform.OS !== 'web') Vibration.vibrate(10); };
  const successHaptic = () => { if (Platform.OS !== 'web') Vibration.vibrate([0, 30, 60, 30]); };

  // Initial group avatar comes from the inbox row; load mute pref on mount.
  useEffect(() => {
    const conv = conversations.find((cv) => cv.id === groupId);
    if (conv) setAvatarUrl(conv.avatarUrl);
    getMutedSet().then((s) => setMutedState(s.has(groupId)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId]);

  async function toggleMute(on: boolean) {
    setMutedState(on);
    selectionHaptic();
    await setMuted(groupId, on);
    await refreshConversations();
  }

  async function changeAvatar() {
    if (!isOwner || busyAvatar) return;
    const res = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.85 });
    if (res.canceled || !res.assets.length) return;
    setBusyAvatar(true);
    try {
      const url = await api.changeGroupAvatar(groupId, res.assets[0].uri);
      setAvatarUrl(url);
      successHaptic();
      await refreshConversations();
    } catch (e) {
      notify(t('groupSettingsChangePhoto'), t('groupSettingsActionError'));
      console.warn('changeGroupAvatar failed', e);
    } finally {
      setBusyAvatar(false);
    }
  }

  async function confirmClearHistory() {
    const ok = await confirmAsync(t('chatClearHistory'), t('chatClearHistoryConfirm'), {
      confirmLabel: t('chatClearHistory'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await api.clearGroupHistory(groupId);
      await refreshConversations();
    } catch {
      notify(t('groupSettingsActionError'));
    }
  }

  async function confirmLeave() {
    if (busyDanger) return;
    const ok = await confirmAsync(t('groupSettingsLeave'), t('groupSettingsLeaveConfirm'), {
      confirmLabel: t('groupSettingsLeave'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok || !userId) return;
    setBusyDanger(true);
    try {
      await api.leaveGroup(groupId, userId);
      successHaptic();
      await refreshConversations();
      router.dismissAll?.();
      router.replace('/(tabs)');
    } catch (e) {
      notify(t('groupSettingsLeave'), t('groupSettingsActionError'));
      console.warn('leaveGroup failed', e);
    } finally {
      setBusyDanger(false);
    }
  }

  async function confirmDissolve() {
    if (busyDanger) return;
    const ok = await confirmAsync(t('groupSettingsDissolve'), t('groupSettingsDissolveConfirm'), {
      confirmLabel: t('groupSettingsDissolve'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setBusyDanger(true);
    try {
      await api.dissolveGroup(groupId);
      successHaptic();
      await refreshConversations();
      router.dismissAll?.();
      router.replace('/(tabs)');
    } catch (e) {
      notify(t('groupSettingsDissolve'), t('groupSettingsActionError'));
      console.warn('dissolveGroup failed', e);
    } finally {
      setBusyDanger(false);
    }
  }

  const trimmedName = nameDraft.trim();
  const canSaveName = isOwner && trimmedName.length > 0 && trimmedName !== currentName && !savingName;

  async function reload() {
    try {
      const roster = await api.listGroupMembers(groupId);
      setMembers(roster);
    } catch (e) {
      // Surface nothing — keep whatever roster we had.
      console.warn('list_group_members failed', e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [groupId]);

  async function saveName() {
    if (!canSaveName) return;
    const newName = trimmedName;
    setSavingName(true);
    try {
      await api.renameGroup(groupId, newName);
      setCurrentName(newName);
      successHaptic();
    } catch (e) {
      notify(t('groupSettingsName'), t('groupSettingsActionError'));
      console.warn('group_rename failed', e);
    } finally {
      setSavingName(false);
    }
  }

  async function confirmRemove(member: GroupMember) {
    selectionHaptic();
    const ok = await confirmAsync(t('groupSettingsRemoveConfirm'), undefined, {
      confirmLabel: t('groupSettingsRemove'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (ok) await remove(member);
  }

  async function remove(member: GroupMember) {
    try {
      await api.removeGroupMember(groupId, member.id);
      successHaptic();
      await reload();
    } catch (e) {
      notify(t('groupSettingsRemove'), t('groupSettingsActionError'));
      console.warn('group_remove_member failed', e);
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('groupSettingsTitle')} onBack={() => router.back()} />

      {loading && members.length === 0 ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 16, paddingBottom: 36 }}>
          {/* Group avatar */}
          <View style={{ alignItems: 'center', marginBottom: 20 }}>
            <Pressable onPress={changeAvatar} disabled={!isOwner || busyAvatar}>
              <Avatar colors={avatarGradient(groupId)} symbol="people" imageUrl={avatarUrl} size={88} />
              {isOwner && (
                <View style={[styles.cameraBadge, { backgroundColor: c.coral, borderColor: c.paper }]}>
                  {busyAvatar ? <ActivityIndicator color="#fff" size="small" /> : <Ionicons name="camera" size={15} color="#fff" />}
                </View>
              )}
            </Pressable>
          </View>

          {/* Name section */}
          <Text style={[styles.sectionLabel, { color: c.inkTertiary }]}>
            {t('groupSettingsName').toUpperCase()}
          </Text>
          <View style={[styles.nameRow, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <LinearGradient
              colors={gradients.sunset}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.nameIcon}
            >
              <Ionicons name="people" size={20} color="#fff" />
            </LinearGradient>

            {isOwner ? (
              <TextInput
                value={nameDraft}
                onChangeText={setNameDraft}
                placeholder={t('createGroupNamePlaceholder')}
                placeholderTextColor={c.inkTertiary}
                returnKeyType="done"
                onSubmitEditing={() => { if (canSaveName) void saveName(); }}
                style={{ flex: 1, fontSize: 16, fontWeight: '500', color: c.ink }}
              />
            ) : (
              <Text style={{ flex: 1, fontSize: 16, fontWeight: '500', color: c.ink }} numberOfLines={1}>
                {currentName.length ? currentName : t('createGroupNamePlaceholder')}
              </Text>
            )}

            {isOwner && (
              savingName ? (
                <ActivityIndicator color={c.coral} style={{ marginLeft: 6 }} />
              ) : (
                <Pressable onPress={saveName} disabled={!canSaveName} style={{ marginLeft: 6 }}>
                  {canSaveName ? (
                    <LinearGradient
                      colors={gradients.sunset}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={styles.savePill}
                    >
                      <Text style={[styles.savePillText, { color: '#fff' }]}>{t('groupSettingsSave')}</Text>
                    </LinearGradient>
                  ) : (
                    <View style={[styles.savePill, { backgroundColor: c.cardSubtle }]}>
                      <Text style={[styles.savePillText, { color: c.inkTertiary }]}>{t('groupSettingsSave')}</Text>
                    </View>
                  )}
                </Pressable>
              )
            )}
          </View>

          {/* Preferences */}
          <View style={[styles.prefRow, { backgroundColor: c.card, borderColor: c.hairline, marginTop: 22 }]}>
            <Ionicons name="notifications-off" size={18} color={c.coral} style={{ width: 30 }} />
            <Text style={{ flex: 1, color: c.ink, fontSize: 15, fontWeight: '500' }}>{t('groupSettingsMute')}</Text>
            <Switch value={muted} onValueChange={toggleMute} trackColor={{ true: c.coral }} />
          </View>

          {/* Members section */}
          <View style={[styles.membersHeader, { marginTop: 22 }]}>
            <Text style={[styles.sectionLabel, { color: c.inkTertiary, marginBottom: 0 }]}>
              {`${t('groupSettingsMembers')} · ${members.length}`.toUpperCase()}
            </Text>
            <Pressable onPress={() => { selectionHaptic(); setShowAdd(true); }} style={styles.addBtn}>
              <Ionicons name="person-add" size={14} color={c.coral} />
              <Text style={{ color: c.coral, fontSize: 13, fontWeight: '600' }}>{t('groupSettingsAddMembers')}</Text>
            </Pressable>
          </View>

          <View style={[styles.membersCard, { backgroundColor: c.card, borderColor: c.hairline }]}>
            {members.map((m, i) => (
              <View key={m.id}>
                <View style={styles.memberRow}>
                  {/* Tapping the avatar/name opens the member's info card. */}
                  <Pressable
                    onPress={() => { selectionHaptic(); setSelectedMember(m); }}
                    style={{ flex: 1, flexDirection: 'row', alignItems: 'center' }}
                  >
                    <Avatar colors={avatarGradient(m.id)} name={m.name} imageUrl={m.avatarUrl} size={44} />
                    <View style={{ flex: 1, marginLeft: 12 }}>
                      <Text style={{ color: c.ink, fontSize: 15, fontWeight: '600' }} numberOfLines={1}>{m.name}</Text>
                      {m.handle.length > 0 && (
                        <Text style={{ color: c.inkSecondary, fontSize: 13, marginTop: 2 }} numberOfLines={1}>@{m.handle}</Text>
                      )}
                    </View>
                  </Pressable>
                  {m.isOwner ? (
                    <View style={[styles.ownerTag, { backgroundColor: c.coral + (c.scheme === 'dark' ? '2E' : '1A') }]}>
                      <Text style={{ color: c.coral, fontSize: 11, fontWeight: '700' }}>{t('groupSettingsOwner')}</Text>
                    </View>
                  ) : isOwner ? (
                    <Pressable onPress={() => confirmRemove(m)} hitSlop={8}>
                      <Ionicons name="remove-circle" size={24} color={c.danger} />
                    </Pressable>
                  ) : null}
                </View>
                {i < members.length - 1 && <Divider inset={68} />}
              </View>
            ))}
          </View>

          {/* Clear history (tucked away here, not in the chat top bar) + Leave / Dissolve */}
          <View style={{ marginTop: 24, gap: 10 }}>
            <Pressable onPress={confirmClearHistory} style={[styles.dangerBtn, { backgroundColor: c.cardSubtle }]}>
              <Ionicons name="trash-bin-outline" size={18} color={c.inkSecondary} />
              <Text style={{ color: c.inkSecondary, fontSize: 15, fontWeight: '600' }}>{t('chatClearHistory')}</Text>
            </Pressable>
            <Pressable onPress={confirmLeave} disabled={busyDanger} style={[styles.dangerBtn, { backgroundColor: c.danger + '14' }]}>
              <Ionicons name="exit-outline" size={18} color={c.danger} />
              <Text style={{ color: c.danger, fontSize: 15, fontWeight: '600' }}>{t('groupSettingsLeave')}</Text>
            </Pressable>
            {isOwner && (
              <Pressable onPress={confirmDissolve} disabled={busyDanger} style={[styles.dangerBtn, { backgroundColor: c.danger + '14' }]}>
                <Ionicons name="trash-outline" size={18} color={c.danger} />
                <Text style={{ color: c.danger, fontSize: 15, fontWeight: '600' }}>{t('groupSettingsDissolve')}</Text>
              </Pressable>
            )}
          </View>
        </ScrollView>
      )}

      <AddMembersModal
        visible={showAdd}
        groupId={groupId}
        existingIds={existingIds}
        onClose={() => setShowAdd(false)}
        onAdded={() => { setShowAdd(false); void reload(); }}
      />

      <GroupMemberCard
        member={selectedMember}
        onClose={() => setSelectedMember(null)}
      />
    </SafeAreaView>
  );
}

// ─────────────────────────── Member info card ───────────────────────────

/** Tapping a member in the roster opens this card: their avatar, name, @handle,
 *  role + owner badge, and a context-aware action (Add Friend / Requested /
 *  Friends / This is you). */
function GroupMemberCard({
  member, onClose,
}: { member: GroupMember | null; onClose: () => void }) {
  const c = useTheme();
  const { t } = useI18n();
  const { userId } = useAuth();
  const { contacts, refreshContacts } = useAppData();
  const [busy, setBusy] = useState(false);
  const [relationship, setRelationship] = useState<MemberRelationship>('none');

  useEffect(() => {
    if (!member) return;
    if (member.id === userId) setRelationship('self');
    else if (contacts.some((ct) => ct.id === member.id)) setRelationship('friends');
    else setRelationship('none');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [member]);

  async function addFriend() {
    if (!member || busy) return;
    setBusy(true);
    try {
      const status = await api.sendFriendRequest(member.id, t('friendRequestMessage'));
      switch (status) {
        case 'sent':
          setRelationship('request_sent');
          notify(t('addFriendSent'));
          break;
        case 'already_sent':
          setRelationship('request_sent');
          break;
        case 'already_friends':
          setRelationship('friends');
          break;
        default:
          setRelationship('request_sent');
          break;
      }
      await refreshContacts().catch(() => {});
    } catch {
      notify(t('addFriendError'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={!!member} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.memberCardBackdrop} onPress={onClose}>
        <Pressable style={[styles.memberCardSheet, { backgroundColor: c.paper }]} onPress={() => {}}>
          {member && (
            <>
              <Avatar colors={avatarGradient(member.id)} name={member.name} imageUrl={member.avatarUrl} size={88} />
              <Text style={[styles.memberCardName, { color: c.ink }]} numberOfLines={1}>{member.name}</Text>
              {member.handle.length > 0 && (
                <Text style={[styles.memberCardHandle, { color: c.inkSecondary }]} numberOfLines={1}>@{member.handle}</Text>
              )}

              <View style={styles.memberCardTags}>
                {member.isOwner && (
                  <View style={[styles.ownerTag, { backgroundColor: c.coral + (c.scheme === 'dark' ? '2E' : '1A') }]}>
                    <Ionicons name="star" size={11} color={c.coral} />
                    <Text style={{ color: c.coral, fontSize: 11, fontWeight: '700', marginLeft: 4 }}>{t('groupSettingsOwner')}</Text>
                  </View>
                )}
                {member.role.length > 0 && (
                  <View style={[styles.roleTag, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
                    <Text style={{ color: c.inkSecondary, fontSize: 11, fontWeight: '700' }}>{member.role}</Text>
                  </View>
                )}
              </View>

              <View style={{ marginTop: 16 }}>
                {relationship === 'self' ? (
                  <MemberBadge icon="person" text={t('groupMemberYou')} c={c} />
                ) : relationship === 'friends' ? (
                  <MemberBadge icon="checkmark" text={t('addFriendFriends')} c={c} />
                ) : relationship === 'request_sent' ? (
                  <MemberBadge icon="time-outline" text={t('addFriendRequested')} c={c} />
                ) : (
                  <Pressable onPress={addFriend} disabled={busy}>
                    <LinearGradient
                      colors={gradients.sunset}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 1 }}
                      style={[styles.memberCardActionPill, { opacity: busy ? 0.7 : 1 }]}
                    >
                      {busy ? <ActivityIndicator color="#fff" /> : <Ionicons name="person-add" size={14} color="#fff" />}
                      <Text style={{ color: '#fff', fontSize: 15, fontWeight: '600' }}>{t('addFriendAdd')}</Text>
                    </LinearGradient>
                  </Pressable>
                )}
              </View>
            </>
          )}
        </Pressable>
      </Pressable>
    </Modal>
  );
}

function MemberBadge({ icon, text, c }: { icon: keyof typeof Ionicons.glyphMap; text: string; c: ReturnType<typeof useTheme> }) {
  return (
    <View style={[styles.memberCardActionPill, { backgroundColor: c.cardSubtle, borderWidth: 1, borderColor: c.hairline }]}>
      <Ionicons name={icon} size={13} color={c.inkSecondary} />
      <Text style={{ color: c.inkSecondary, fontSize: 14, fontWeight: '600' }}>{text}</Text>
    </View>
  );
}

// ─────────────────────────── Add Members modal ───────────────────────────

function AddMembersModal({
  visible, groupId, existingIds, onClose, onAdded,
}: {
  visible: boolean;
  groupId: string;
  existingIds: Set<string>;
  onClose: () => void;
  onAdded: () => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const { contacts } = useAppData();

  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [adding, setAdding] = useState(false);

  // Reset selection each time the sheet opens.
  useEffect(() => {
    if (visible) { setSelected(new Set()); setSearch(''); }
  }, [visible]);

  const candidates = useMemo(
    () => contacts.filter((ct) => !existingIds.has(ct.id)),
    [contacts, existingIds],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return candidates;
    return candidates.filter(
      (ct) => ct.name.toLowerCase().includes(q) || ct.handle.toLowerCase().includes(q),
    );
  }, [candidates, search]);

  const canAdd = selected.size > 0 && !adding;

  function toggle(id: string) {
    if (Platform.OS !== 'web') Vibration.vibrate(10);
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  async function add() {
    if (!canAdd) return;
    setAdding(true);
    let failed = false;
    for (const id of Array.from(selected)) {
      try {
        await api.addGroupMember(groupId, id);
      } catch (e) {
        failed = true;
        console.warn('group_add_member failed', id, e);
      }
    }
    setAdding(false);
    if (failed) {
      notify(t('groupSettingsAddMembers'), t('groupSettingsActionError'));
    } else {
      if (Platform.OS !== 'web') Vibration.vibrate([0, 30, 60, 30]);
      onAdded();
    }
  }

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <View style={styles.modalNav}>
          <Pressable onPress={onClose} style={[styles.iconBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Ionicons name="close" size={20} color={c.ink} />
          </Pressable>
          <View style={{ flex: 1, marginLeft: 12 }}>
            <Text style={{ color: c.ink, fontSize: 18, fontWeight: '700' }}>{t('groupSettingsAddMembers')}</Text>
            {selected.size > 0 && (
              <Text style={{ color: c.inkSecondary, fontSize: 12, fontWeight: '500', marginTop: 2 }}>
                {`${selected.size} ${t('createGroupSelected')}`}
              </Text>
            )}
          </View>
          {adding ? (
            <ActivityIndicator color={c.coral} style={{ width: 44 }} />
          ) : (
            <Pressable onPress={add} disabled={!canAdd} hitSlop={8}>
              <Text style={{ color: canAdd ? c.coral : c.inkTertiary, fontSize: 15, fontWeight: '600' }}>
                {t('groupSettingsSave')}
              </Text>
            </Pressable>
          )}
        </View>

        {candidates.length === 0 ? (
          <EmptyState icon="people-outline" title={t('groupSettingsNoFriendsToAdd')} />
        ) : (
          <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
            <View style={[styles.searchField, { backgroundColor: c.card, borderColor: c.hairline }]}>
              <Ionicons name="search" size={16} color={c.inkSecondary} />
              <TextInput
                value={search}
                onChangeText={setSearch}
                placeholder={t('forwardSearch')}
                placeholderTextColor={c.inkTertiary}
                style={{ flex: 1, marginLeft: 10, fontSize: 16, color: c.ink }}
              />
              {search.length > 0 && (
                <Pressable onPress={() => setSearch('')} hitSlop={8}>
                  <Ionicons name="close-circle" size={18} color={c.inkTertiary} />
                </Pressable>
              )}
            </View>

            {filtered.map((ct, i) => (
              <View key={ct.id}>
                <ContactPickRow contact={ct} selected={selected.has(ct.id)} onPress={() => toggle(ct.id)} />
                {i < filtered.length - 1 && <Divider inset={76} />}
              </View>
            ))}
          </ScrollView>
        )}
      </SafeAreaView>
    </Modal>
  );
}

function ContactPickRow({
  contact, selected, onPress,
}: { contact: Contact; selected: boolean; onPress: () => void }) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} style={styles.pickRow}>
      <Avatar
        colors={contact.avatarColors}
        name={contact.name}
        imageUrl={contact.avatarUrl}
        size={48}
        online={contact.isOnline}
      />
      <View style={{ flex: 1, marginLeft: 14 }}>
        <Text style={{ color: c.ink, fontSize: 16, fontWeight: '600' }} numberOfLines={1}>{contact.name}</Text>
        {contact.handle.length > 0 && (
          <Text style={{ color: c.inkSecondary, fontSize: 13, marginTop: 3 }} numberOfLines={1}>@{contact.handle}</Text>
        )}
      </View>
      <View
        style={[
          styles.checkCircle,
          { borderColor: selected ? c.coral : c.hairline, backgroundColor: selected ? c.coral : 'transparent' },
        ]}
      >
        {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  sectionLabel: { fontSize: 12, fontWeight: '700', letterSpacing: 1, marginBottom: 10 },
  nameRow: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.md, borderWidth: 1,
    paddingHorizontal: 14, paddingVertical: 12, gap: 12,
  },
  nameIcon: { width: 44, height: 44, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  savePill: { borderRadius: radius.pill, paddingHorizontal: 14, paddingVertical: 7, alignItems: 'center', justifyContent: 'center' },
  savePillText: { fontSize: 15, fontWeight: '600' },
  membersHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 },
  addBtn: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  membersCard: { borderRadius: radius.md, borderWidth: 1, paddingVertical: 4 },
  memberRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 10 },
  ownerTag: { borderRadius: radius.pill, paddingHorizontal: 9, paddingVertical: 4 },
  modalNav: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12 },
  iconBtn: { width: 40, height: 40, borderRadius: 20, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  searchField: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.pill, borderWidth: 1,
    paddingHorizontal: 16, paddingVertical: 12, marginHorizontal: 16, marginTop: 14, marginBottom: 6,
  },
  pickRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 10 },
  checkCircle: { width: 24, height: 24, borderRadius: 12, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  cameraBadge: {
    position: 'absolute', right: -2, bottom: -2, width: 28, height: 28, borderRadius: 14,
    borderWidth: 2, alignItems: 'center', justifyContent: 'center',
  },
  prefRow: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.md, borderWidth: 1,
    paddingHorizontal: 14, paddingVertical: 10, gap: 6,
  },
  dangerBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8,
    borderRadius: radius.md, paddingVertical: 14,
  },
  memberCardBackdrop: {
    flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end',
  },
  memberCardSheet: {
    borderTopLeftRadius: 28, borderTopRightRadius: 28,
    paddingTop: 28, paddingBottom: 44, paddingHorizontal: 24, alignItems: 'center',
  },
  memberCardName: { fontSize: 20, fontWeight: '700', marginTop: 14, textAlign: 'center' },
  memberCardHandle: { fontSize: 14, fontWeight: '500', marginTop: 2 },
  memberCardTags: { flexDirection: 'row', gap: 8, marginTop: 14 },
  roleTag: { flexDirection: 'row', borderRadius: radius.pill, borderWidth: 1, paddingHorizontal: 9, paddingVertical: 4 },
  memberCardActionPill: {
    flexDirection: 'row', alignItems: 'center', gap: 7,
    paddingHorizontal: 22, paddingVertical: 12, borderRadius: radius.pill,
  },
});
