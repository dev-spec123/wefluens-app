/**
 * Group chat — text + image + voice, ported from the Swift GroupChatDetailView.
 * Loads via api.loadGroupMessages, marks the group read on mount, and stays
 * live with a realtime subscription on `group_messages`. Incoming bubbles show
 * the sender's avatar + name (once per run); mine sit right-aligned in coral.
 * Long-pressing a message opens the QQ-style menu (copy / reply / forward /
 * favorite / pin / select / recall / delete / report).
 */
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { Image } from 'expo-image';
import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator, FlatList, KeyboardAvoidingView, Platform, Pressable,
  StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ActionSheet, type SheetAction } from '@/components/ActionSheet';
import { ImageViewer } from '@/components/ImageViewer';
import { VideoViewer } from '@/components/VideoViewer';
import { FileBubble } from '@/components/FileBubble';
import { AudioBubble, VoiceRecordButton } from '@/components/Voice';
import { Avatar, RoundIconButton } from '@/components/ui';
import { confirmAsync, notify } from '@/lib/dialog';
import { addFavorite } from '@/lib/favorites';
import { getPinned, setPinned, type PinnedMessage } from '@/lib/pinnedMessages';
import { useAppData } from '@/context/AppDataContext';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { getCachedMessages, getMemCachedMessages, setCachedMessages } from '@/lib/messageCache';
import { messageMentionsMe } from '@/lib/mentions';
import { recallErrorKey, withinRecallWindow } from '@/lib/recall';
import { supabase } from '@/lib/supabase';
import { avatarGradient, gradients, radius, useTheme } from '@/lib/theme';
import type { GroupMember, GroupMessage } from '@/lib/types';

/** A message paired with whether it begins a new run from its sender. */
interface GroupRow {
  message: GroupMessage;
  startsRun: boolean;
  showSenderHeader: boolean;
}

const MAX_IMAGE_DIM = 2048;

function excerptOf(m: GroupMessage, t: (k: string) => string): string {
  if (m.isRecalled) return t('chatMessageRecalled');
  const text = m.text?.trim();
  if (text) return text;
  if (m.kind === 'image') return t('chatImagePreview');
  if (m.kind === 'audio') return t('chatVoicePreview');
  return t('chatFilePreview');
}

export default function GroupChat() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId, profile } = useAuth();
  const myName = profile?.name ?? '';
  const { blockedIds, block } = useAppData();
  const params = useLocalSearchParams<{ groupId: string; title: string; memberCount: string }>();

  const groupId = params.groupId;
  const title = params.title ?? 'Group';
  const memberCount = params.memberCount ?? '0';

  // Seed synchronously from the in-memory cache → instant, spinner-free re-entry.
  const [messages, setMessages] = useState<GroupMessage[]>(
    () => getMemCachedMessages<GroupMessage>(`group.${groupId}`) ?? [],
  );
  const [draft, setDraft] = useState('');
  const [loading, setLoading] = useState(() => {
    const c = getMemCachedMessages<GroupMessage>(`group.${groupId}`);
    return !c || c.length === 0;
  });
  const [sendingImage, setSendingImage] = useState(false);
  const [sendingVoice, setSendingVoice] = useState(false);
  const [menuMsg, setMenuMsg] = useState<GroupMessage | null>(null);
  const [showAttach, setShowAttach] = useState(false);
  const [members, setMembers] = useState<GroupMember[]>([]);
  const [showMentions, setShowMentions] = useState(false);
  const [pinned, setPinnedState] = useState<PinnedMessage | null>(null);

  const [replyTo, setReplyTo] = useState<GroupMessage | null>(null);
  const [selectMode, setSelectMode] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [highlightId, setHighlightId] = useState<string | null>(null);
  const [viewerUri, setViewerUri] = useState<string | null>(null);
  const [viewerKey, setViewerKey] = useState<string | null>(null);
  const [viewerVideoPath, setViewerVideoPath] = useState<string | null>(null);

  const listRef = useRef<FlatList<GroupRow>>(null);

  const blockedRef = useRef(blockedIds);
  blockedRef.current = blockedIds;

  const reload = useCallback(async () => {
    if (!userId || !groupId) return;
    const msgs = await api.loadGroupMessages(groupId, userId, blockedRef.current);
    setMessages(msgs);
    void setCachedMessages(`group.${groupId}`, msgs);
  }, [userId, groupId]);

  // Initial load + mark read.
  useEffect(() => {
    if (!userId || !groupId) return;
    let alive = true;
    // Show the last cached view instantly, then refresh from the server.
    getCachedMessages<GroupMessage>(`group.${groupId}`).then((cached) => {
      if (alive && cached && cached.length) {
        setMessages((prev) => (prev.length ? prev : cached));
        setLoading(false);
      }
    });
    (async () => {
      try {
        const msgs = await api.loadGroupMessages(groupId, userId, blockedRef.current);
        if (alive) setMessages(msgs);
        void setCachedMessages(`group.${groupId}`, msgs);
        await api.markGroupRead(groupId).catch(() => {});
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, [userId, groupId]);

  // Load the pinned message (群公告 banner) on mount.
  useEffect(() => {
    if (!groupId) return;
    let alive = true;
    getPinned(groupId).then((p) => { if (alive) setPinnedState(p); }).catch(() => {});
    return () => { alive = false; };
  }, [groupId]);

  // Realtime — any change to this group's messages reloads the thread.
  useEffect(() => {
    if (!groupId) return;
    const channel = supabase
      .channel(`group-${groupId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'group_messages', filter: `group_id=eq.${groupId}` },
        () => { void reload(); },
      )
      .subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [groupId, reload]);

  // Auto-scroll to the latest message (skip while jumping to a quote).
  useEffect(() => {
    if (messages.length === 0 || highlightId) return;
    const id = setTimeout(() => listRef.current?.scrollToEnd({ animated: true }), 80);
    return () => clearTimeout(id);
  }, [messages.length, highlightId]);

  const rows = useMemo<GroupRow[]>(() => {
    return messages.map((m, i) => {
      const prev = i > 0 ? messages[i - 1] : null;
      const startsRun = prev?.senderId !== m.senderId;
      return { message: m, startsRun, showSenderHeader: m.sender === 'them' && startsRun };
    });
  }, [messages]);

  const byId = useMemo(() => {
    const m = new Map<string, GroupMessage>();
    messages.forEach((msg) => m.set(msg.id, msg));
    return m;
  }, [messages]);
  const indexById = useMemo(() => {
    const m = new Map<string, number>();
    messages.forEach((msg, i) => m.set(msg.id, i));
    return m;
  }, [messages]);

  const jumpToMessage = useCallback((id: string) => {
    const idx = indexById.get(id);
    if (idx == null) { notify(t('chatReplyJumpMissing')); return; }
    listRef.current?.scrollToIndex({ index: idx, animated: true, viewPosition: 0.35 });
    setHighlightId(id);
    setTimeout(() => setHighlightId((cur) => (cur === id ? null : cur)), 1600);
  }, [indexById, t]);

  const canSend = draft.trim().length > 0;

  async function send() {
    const text = draft.trim();
    if (!text || !groupId) return;
    const replyId = replyTo?.id ?? null;
    setDraft('');
    setReplyTo(null);
    try {
      await api.sendGroupMessage(groupId, text, replyId);
      await reload();
    } catch {
      setDraft(text);
      notify(t('chatSendError'));
    }
  }

  async function pickImage() {
    if (!groupId) return;
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      // quality 1 + no editing is required to keep animated GIFs animated (Android).
      quality: 1,
      allowsEditing: false,
    });
    if (result.canceled || !result.assets[0]) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendGroupImage(groupId, asset.uri, asset.width ?? 0, asset.height ?? 0, '', asset.mimeType || asset.fileName || asset.uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingImage(false);
    }
  }

  async function pickVideo() {
    if (!groupId) return;
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['videos'],
      quality: 1,
      allowsEditing: false,
    });
    if (result.canceled || !result.assets[0]) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendGroupVideo(groupId, asset.uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingImage(false);
    }
  }

  async function pickDocument() {
    if (!groupId || sendingImage) return;
    const result = await DocumentPicker.getDocumentAsync({ copyToCacheDirectory: true });
    if (result.canceled || !result.assets?.length) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendGroupFile(
        groupId, asset.uri, asset.name, asset.size ?? null,
        asset.mimeType || 'application/octet-stream',
      );
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingImage(false);
    }
  }

  async function sendVoice(uri: string) {
    if (!groupId || sendingVoice) return;
    setSendingVoice(true);
    try {
      await api.sendGroupVoice(groupId, uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingVoice(false);
    }
  }

  // ─────────────────────────── Message actions ───────────────────────────

  async function blockSender(msg: GroupMessage) {
    const ok = await confirmAsync(t('blockAction'), t('blockConfirm'), {
      confirmLabel: t('blockAction'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await block(msg.senderId);
      await reload();
    } catch {
      notify(t('blockError'));
    }
  }

  function favoriteMessage(msg: GroupMessage) {
    void addFavorite({
      id: msg.id, text: excerptOf(msg, t), kind: msg.kind, sender: msg.sender, source: title, at: Date.now(),
      imagePath: (msg.kind === 'image' || msg.kind === 'audio' || msg.kind === 'video' || msg.kind === 'file') ? msg.imagePath : null,
      fileName: msg.fileName ?? null,
      fileMime: msg.fileMime ?? null,
    });
  }

  async function copyMessage(msg: GroupMessage) {
    await Clipboard.setStringAsync(msg.text ?? '');
    notify(t('chatCopied'));
  }

  async function recall(msg: GroupMessage) {
    try {
      await api.recallMessage(msg.id, 'group');
      await reload();
    } catch (e) {
      notify(t(recallErrorKey(e)));
    }
  }

  async function deleteOne(msg: GroupMessage) {
    const ok = await confirmAsync(t('chatDelete'), t('chatDeleteConfirm'), {
      confirmLabel: t('chatDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await api.deleteMessageForMe(msg.id, 'group');
      await reload();
    } catch (e) {
      console.warn('deleteMessageForMe failed', e);
    }
  }

  function pinMessage(msg: GroupMessage) {
    if (!groupId) return;
    const next: PinnedMessage = { id: msg.id, text: excerptOf(msg, t), by: msg.senderName };
    setPinnedState(next);
    void setPinned(groupId, next);
  }

  function unpinMessage() {
    if (!groupId) return;
    setPinnedState(null);
    void setPinned(groupId, null);
  }

  function enterSelect(msg: GroupMessage) {
    setSelectMode(true);
    setSelected(new Set([msg.id]));
  }

  function exitSelect() {
    setSelectMode(false);
    setSelected(new Set());
  }

  function toggleSelect(msg: GroupMessage) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(msg.id)) next.delete(msg.id); else next.add(msg.id);
      return next;
    });
  }

  function forwardSelected() {
    if (selected.size === 0) return;
    const ids = messages.filter((m) => selected.has(m.id) && !m.isRecalled).map((m) => m.id);
    if (ids.length === 0) return;
    router.push({ pathname: '/forward', params: { kind: 'group', messageIds: ids.join(',') } });
    exitSelect();
  }

  async function deleteSelected() {
    if (selected.size === 0) return;
    const ok = await confirmAsync(t('chatDelete'), t('chatDeleteSelectedConfirm'), {
      confirmLabel: t('chatDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      for (const id of selected) await api.deleteMessageForMe(id, 'group');
      await reload();
    } catch (e) {
      console.warn('delete selected failed', e);
    } finally {
      exitSelect();
    }
  }

  function openImage(msg: GroupMessage) {
    if (!msg.imagePath) return;
    setViewerKey(msg.imagePath);
    api.signedMediaUrl(msg.imagePath)
      .then((u) => setViewerUri(u))
      .catch(() => notify(t('chatSendError')));
  }

  function openVideo(msg: GroupMessage) {
    if (!msg.imagePath) return;
    setViewerVideoPath(msg.imagePath);
  }

  async function openMentions() {
    if (members.length === 0) {
      try { setMembers(await api.listGroupMembers(groupId)); } catch { /* keep empty */ }
    }
    setShowMentions(true);
  }

  function insertMention(name: string) {
    setDraft((d) => {
      const sep = d.length === 0 || d.endsWith(' ') ? '' : ' ';
      return `${d}${sep}@${name} `;
    });
  }

  const menuActions: SheetAction[] = useMemo(() => {
    if (!menuMsg) return [];
    const m = menuMsg;
    const acts: SheetAction[] = [];
    if (!m.isRecalled && m.text?.trim()) {
      acts.push({ label: t('chatCopy'), icon: 'copy', onPress: () => void copyMessage(m) });
    }
    if (!m.isRecalled) {
      acts.push({ label: t('chatReply'), icon: 'arrow-undo', onPress: () => setReplyTo(m) });
      acts.push({
        label: t('chatForward'), icon: 'arrow-redo',
        onPress: () => router.push({ pathname: '/forward', params: { kind: 'group', messageId: m.id } }),
      });
      acts.push({ label: t('favoriteAction'), icon: 'bookmark', onPress: () => favoriteMessage(m) });
      acts.push(
        pinned?.id === m.id
          ? { label: t('unpinMessage'), icon: 'pin-outline', onPress: () => unpinMessage() }
          : { label: t('pinMessage'), icon: 'pin', onPress: () => pinMessage(m) },
      );
    }
    acts.push({ label: t('chatSelect'), icon: 'checkmark-circle', onPress: () => enterSelect(m) });
    if (m.sender === 'me' && !m.isRecalled && withinRecallWindow(m)) {
      acts.push({ label: t('chatRecall'), icon: 'refresh', onPress: () => void recall(m) });
    }
    acts.push({ label: t('chatDelete'), icon: 'trash', destructive: true, onPress: () => void deleteOne(m) });
    if (m.sender === 'them' && !m.isRecalled) {
      acts.push({
        label: t('reportTitle'), icon: 'flag',
        onPress: () => router.push({
          pathname: '/report',
          params: {
            reportedUserId: m.senderId, messageId: m.id,
            messageKind: 'group', excerpt: m.text, blockableUserId: m.senderId,
          },
        }),
      });
      acts.push({ label: t('blockAction'), icon: 'hand-left', destructive: true, onPress: () => void blockSender(m) });
    }
    return acts;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [menuMsg, pinned, t]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      {/* Nav bar — selection mode swaps to a count + close. */}
      {selectMode ? (
        <View style={[styles.navbar, { backgroundColor: c.paper }]}>
          <Pressable onPress={exitSelect} style={[styles.iconBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Ionicons name="close" size={20} color={c.ink} />
          </Pressable>
          <View style={{ flex: 1, alignItems: 'center' }}>
            <Text style={[styles.navTitle, { color: c.ink }]} numberOfLines={1}>
              {t('chatSelectedLabel')} {selected.size}
            </Text>
          </View>
          <View style={{ width: 40 }} />
        </View>
      ) : (
        <View style={[styles.navbar, { backgroundColor: c.paper }]}>
          <Pressable onPress={() => router.back()} style={[styles.iconBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Ionicons name="chevron-back" size={20} color={c.ink} />
          </Pressable>
          <Avatar colors={avatarGradient(groupId ?? '')} symbol="people" size={40} />
          <View style={{ flex: 1, marginLeft: 2 }}>
            <Text style={[styles.navTitle, { color: c.ink }]} numberOfLines={1}>{title}</Text>
            <Text style={[styles.navSubtitle, { color: c.inkSecondary }]} numberOfLines={1}>
              {memberCount} {t('chatDetailGroupMembers')}
            </Text>
          </View>
          <RoundIconButton
            icon="people"
            onPress={() =>
              router.push({ pathname: '/group-settings/[groupId]', params: { groupId: groupId ?? '', title } })
            }
          />
        </View>
      )}

      {/* Pinned message banner (群公告). */}
      {pinned && !selectMode ? (
        <Pressable
          onPress={() => pinned && jumpToMessage(pinned.id)}
          style={[styles.pinnedBanner, { backgroundColor: c.scheme === 'dark' ? 'rgba(255,77,109,0.16)' : 'rgba(255,77,109,0.10)', borderColor: c.hairline }]}
        >
          <Text style={{ fontSize: 14 }}>📌</Text>
          <View style={{ flex: 1 }}>
            <Text style={{ color: c.coral, fontSize: 11, fontWeight: '700' }} numberOfLines={1}>{t('pinnedLabel')}</Text>
            <Text style={{ color: c.ink, fontSize: 13.5 }} numberOfLines={1}>{pinned.text}</Text>
          </View>
          <Pressable onPress={unpinMessage} hitSlop={8} style={{ padding: 2 }}>
            <Ionicons name="close" size={16} color={c.inkSecondary} />
          </Pressable>
        </Pressable>
      ) : null}

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 8 : 0}
      >
        {loading ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator color={c.coral} />
          </View>
        ) : messages.length === 0 ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 60 }}>
            <Ionicons name="chatbubbles-outline" size={40} color={c.inkTertiary} />
            <Text style={{ color: c.inkSecondary, fontSize: 15, fontWeight: '500', marginTop: 10 }}>
              {t('chatThreadEmpty')}
            </Text>
          </View>
        ) : (
          <FlatList
            ref={listRef}
            data={rows}
            keyExtractor={(r) => r.message.id}
            renderItem={({ item }) => (
              <Bubble
                row={item}
                myName={myName}
                selectMode={selectMode}
                selected={selected.has(item.message.id)}
                highlighted={highlightId === item.message.id}
                repliedTo={item.message.replyTo ? byId.get(item.message.replyTo) ?? null : null}
                onLongPress={() => { if (!selectMode) setMenuMsg(item.message); }}
                onPress={() => {
                  if (selectMode) toggleSelect(item.message);
                  else if (item.message.kind === 'image' && item.message.imagePath) openImage(item.message);
                  else if (item.message.kind === 'video' && item.message.imagePath) openVideo(item.message);
                }}
                onJumpToReply={item.message.replyTo ? () => jumpToMessage(item.message.replyTo!) : undefined}
                onPressAvatar={
                  item.message.sender === 'them'
                    ? () =>
                        router.push({
                          pathname: '/contact/[id]',
                          params: {
                            id: item.message.senderId,
                            name: item.message.senderName,
                            handle: '',
                            avatarUrl: item.message.senderAvatarUrl ?? '',
                          },
                        })
                    : undefined
                }
              />
            )}
            contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 10 }}
            onContentSizeChange={() => { if (!highlightId) listRef.current?.scrollToEnd({ animated: false }); }}
            onScrollToIndexFailed={(info) => {
              listRef.current?.scrollToOffset({ offset: info.averageItemLength * info.index, animated: true });
              setTimeout(() => listRef.current?.scrollToIndex({ index: info.index, animated: true, viewPosition: 0.35 }), 300);
            }}
            keyboardDismissMode="interactive"
          />
        )}

        {/* Reply preview */}
        {replyTo && !selectMode ? (
          <View style={[styles.replyBar, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
            <View style={[styles.replyAccent, { backgroundColor: c.coral }]} />
            <View style={{ flex: 1 }}>
              <Text style={{ color: c.coral, fontSize: 12, fontWeight: '700' }} numberOfLines={1}>
                {t('chatReplyingTo')} {replyTo.sender === 'me' ? t('chatYou') : replyTo.senderName}
              </Text>
              <Text style={{ color: c.inkSecondary, fontSize: 13, marginTop: 1 }} numberOfLines={1}>
                {excerptOf(replyTo, t)}
              </Text>
            </View>
            <Pressable onPress={() => setReplyTo(null)} hitSlop={8} style={{ padding: 4 }}>
              <Ionicons name="close-circle" size={20} color={c.inkTertiary} />
            </Pressable>
          </View>
        ) : null}

        {/* Composer / selection action bar */}
        {selectMode ? (
          <View style={[styles.selectBar, { backgroundColor: c.paper, borderColor: c.hairline }]}>
            <Pressable onPress={forwardSelected} disabled={selected.size === 0} style={styles.selectAction} hitSlop={6}>
              <Ionicons name="arrow-redo" size={22} color={selected.size === 0 ? c.inkTertiary : c.ink} />
              <Text style={{ color: selected.size === 0 ? c.inkTertiary : c.ink, fontSize: 12, marginTop: 3 }}>{t('chatForward')}</Text>
            </Pressable>
            <Pressable onPress={deleteSelected} disabled={selected.size === 0} style={styles.selectAction} hitSlop={6}>
              <Ionicons name="trash" size={22} color={selected.size === 0 ? c.inkTertiary : c.danger} />
              <Text style={{ color: selected.size === 0 ? c.inkTertiary : c.danger, fontSize: 12, marginTop: 3 }}>{t('chatDelete')}</Text>
            </Pressable>
          </View>
        ) : (
          <View style={[styles.inputBar, { backgroundColor: c.paper }]}>
            {sendingImage ? (
              <ActivityIndicator color={c.coral} style={{ width: 30, height: 30 }} />
            ) : (
              <Pressable onPress={() => setShowAttach(true)} style={{ width: 30, height: 30, alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons name="add" size={24} color={c.inkSecondary} />
              </Pressable>
            )}
            <View style={[styles.inputField, { backgroundColor: c.card, borderColor: c.hairline, flexDirection: 'row', alignItems: 'center' }]}>
              <TextInput
                value={draft}
                onChangeText={setDraft}
                placeholder={t('chatDetailMessagePlaceholder')}
                placeholderTextColor={c.inkTertiary}
                style={{ flex: 1, fontSize: 16, color: c.ink, maxHeight: 110 }}
                multiline
              />
              <Pressable onPress={openMentions} hitSlop={8} style={{ paddingLeft: 8 }}>
                <Ionicons name="at" size={20} color={c.inkSecondary} />
              </Pressable>
            </View>
            {canSend ? (
              <Pressable onPress={send}>
                <LinearGradient colors={gradients.sunset} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.sendBtn}>
                  <Ionicons name="arrow-up" size={20} color="#fff" />
                </LinearGradient>
              </Pressable>
            ) : (
              <VoiceRecordButton onComplete={sendVoice} sending={sendingVoice} />
            )}
          </View>
        )}
      </KeyboardAvoidingView>

      {menuMsg ? (
        <ActionSheet
          visible={!!menuMsg}
          title={menuMsg.sender === 'them' ? menuMsg.senderName : undefined}
          cancelLabel={t('authCancel')}
          onClose={() => setMenuMsg(null)}
          actions={menuActions}
        />
      ) : null}

      {showAttach ? (
        <ActionSheet
          visible={showAttach}
          cancelLabel={t('authCancel')}
          onClose={() => setShowAttach(false)}
          actions={[
            { label: t('chatAttachPhoto'), icon: 'image', onPress: pickImage },
            { label: t('chatAttachVideo'), icon: 'videocam', onPress: pickVideo },
            { label: t('chatAttachFile'), icon: 'document', onPress: pickDocument },
          ]}
        />
      ) : null}

      {showMentions ? (
        <ActionSheet
          visible={showMentions}
          title={t('groupSettingsMembers')}
          cancelLabel={t('authCancel')}
          onClose={() => setShowMentions(false)}
          actions={[
            { label: t('mentionAll'), icon: 'megaphone' as const, onPress: () => insertMention(t('mentionAll')) },
            ...members
              .filter((m) => m.id !== userId)
              .map((m) => ({ label: m.name, icon: 'at' as const, onPress: () => insertMention(m.name) })),
          ]}
        />
      ) : null}

      <ImageViewer
        visible={!!viewerUri}
        uri={viewerUri}
        cacheKey={viewerKey}
        onClose={() => { setViewerUri(null); setViewerKey(null); }}
      />
      <VideoViewer visible={!!viewerVideoPath} path={viewerVideoPath} onClose={() => setViewerVideoPath(null)} />
    </SafeAreaView>
  );
}

// ─────────────────────────── Bubble ───────────────────────────

function Bubble({
  row, myName, selectMode, selected, highlighted, repliedTo, onLongPress, onPress, onJumpToReply, onPressAvatar,
}: {
  row: GroupRow;
  myName: string;
  selectMode: boolean;
  selected: boolean;
  highlighted: boolean;
  repliedTo: GroupMessage | null;
  onLongPress: () => void;
  onPress: () => void;
  onJumpToReply?: () => void;
  onPressAvatar?: () => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const { message: m, showSenderHeader, startsRun } = row;
  const isMe = m.sender === 'me';
  // Incoming message that @-mentions me (or @everyone) → highlighted bubble.
  const mentionedMe = !isMe && !m.isRecalled && messageMentionsMe(m.text, myName);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [imageFailed, setImageFailed] = useState(false);

  // Resolve a signed URL for image attachments.
  useEffect(() => {
    let alive = true;
    if (!m.isRecalled && m.kind === 'image' && m.imagePath) {
      api.signedMediaUrl(m.imagePath).then((u) => { if (alive) setImageUrl(u); }).catch(() => { if (alive) setImageFailed(true); });
    }
    return () => { alive = false; };
  }, [m.imagePath, m.kind, m.isRecalled]);

  const imageBox = useMemo(() => {
    const w = m.imageWidth ?? 0;
    const h = m.imageHeight ?? 0;
    if (w > 0 && h > 0) {
      const maxW = 220;
      const scale = Math.min(1, maxW / w);
      return { width: Math.round(w * scale), height: Math.min(MAX_IMAGE_DIM, Math.round(h * scale)) };
    }
    return { width: 200, height: 200 };
  }, [m.imageWidth, m.imageHeight]);

  function quote() {
    if (!repliedTo) return null;
    return (
      <Pressable
        onPress={onJumpToReply}
        disabled={selectMode}
        style={[styles.quote, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}
      >
        <Text style={{ color: c.inkTertiary, fontSize: 11.5 }} numberOfLines={1}>
          {repliedTo.sender === 'me' ? t('chatYou') : repliedTo.senderName}: {excerptOf(repliedTo, t)}
        </Text>
      </Pressable>
    );
  }

  function renderContent() {
    if (m.isRecalled) {
      return (
        <View style={[styles.recalled, { backgroundColor: c.cardSubtle }]}>
          <Text style={{ color: c.inkTertiary, fontSize: 13, fontWeight: '500', fontStyle: 'italic' }}>
            {t('chatMessageRecalled')}
          </Text>
        </View>
      );
    }
    if (m.kind === 'audio' && m.imagePath) {
      return (
        <AudioBubble
          path={m.imagePath}
          isMe={isMe}
          onLongPress={onLongPress}
          onPress={onPress}
          selectMode={selectMode}
        />
      );
    }
    if (m.kind === 'video' && m.imagePath) {
      return (
        <View style={styles.videoBox}>
          <View style={styles.playCircle}>
            <Ionicons name="play" size={26} color="#fff" />
          </View>
          <View style={styles.videoBadge}>
            <Ionicons name="videocam" size={12} color="#fff" />
          </View>
        </View>
      );
    }
    if (m.kind === 'file' && m.imagePath) {
      return (
        <FileBubble
          message={m}
          isMe={isMe}
          onLongPress={onLongPress}
          onPress={onPress}
          selectMode={selectMode}
        />
      );
    }
    if (m.kind === 'image' && m.imagePath) {
      return (
        <View>
          {imageFailed ? (
            <View style={{
              width: imageBox.width, height: imageBox.height, borderRadius: radius.lg,
              backgroundColor: c.cardSubtle, alignItems: 'center', justifyContent: 'center',
            }}>
              <Ionicons name="image-outline" size={26} color={c.inkTertiary} />
              <Text style={{ color: c.inkTertiary, fontSize: 12, marginTop: 6 }}>{t('chatImageExpired')}</Text>
            </View>
          ) : (
            <Image
              source={imageUrl ? { uri: imageUrl, cacheKey: m.imagePath ?? undefined } : undefined}
              cachePolicy="memory-disk"
              style={{ width: imageBox.width, height: imageBox.height, borderRadius: radius.lg, backgroundColor: c.cardSubtle }}
              contentFit="cover"
              onError={() => setImageFailed(true)}
            />
          )}
          {m.text ? (
            <Text style={{ color: isMe ? '#fff' : c.ink, fontSize: 15.5, marginTop: 6 }}>{m.text}</Text>
          ) : null}
        </View>
      );
    }
    if (isMe) {
      return (
        <LinearGradient colors={gradients.sunset} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.bubble}>
          <MentionText text={m.text} color="#fff" mentionColor="#FFEAD9" />
        </LinearGradient>
      );
    }
    return (
      <View style={[
        styles.bubble,
        mentionedMe
          ? { backgroundColor: c.coral + '26', borderWidth: 1, borderColor: c.coral }
          : { backgroundColor: c.scheme === 'dark' ? c.card : '#F0EBE4' },
      ]}>
        <MentionText text={m.text} color={c.ink} mentionColor={c.coral} />
      </View>
    );
  }

  const inner = isMe ? (
    <View style={styles.rowRight}>
      <Text style={[styles.time, { color: c.inkTertiary, marginRight: 6 }]}>{m.time}</Text>
      <View style={{ maxWidth: '78%', alignItems: 'flex-end' }}>
        {quote()}
        {renderContent()}
      </View>
    </View>
  ) : (
    <View style={styles.rowLeft}>
      {showSenderHeader ? (
        <Pressable onPress={onPressAvatar} disabled={selectMode || !onPressAvatar} hitSlop={4}>
          <Avatar colors={avatarGradient(m.senderId)} name={m.senderName} imageUrl={m.senderAvatarUrl} size={34} />
        </Pressable>
      ) : (
        <View style={{ width: 34 }} />
      )}
      <View style={{ marginLeft: 8, flex: 1 }}>
        {showSenderHeader ? (
          <Text style={{ color: c.inkSecondary, fontSize: 12, fontWeight: '600', marginLeft: 2, marginBottom: 3 }} numberOfLines={1}>
            {m.senderName}
          </Text>
        ) : null}
        {quote()}
        <View style={{ flexDirection: 'row', alignItems: 'flex-end', maxWidth: '88%' }}>
          <View style={{ flexShrink: 1 }}>{renderContent()}</View>
          <Text style={[styles.time, { color: c.inkTertiary, marginLeft: 6 }]}>{m.time}</Text>
        </View>
      </View>
    </View>
  );

  return (
    <Pressable
      onPress={onPress}
      onLongPress={selectMode ? undefined : onLongPress}
      delayLongPress={350}
      style={[{ marginTop: startsRun ? 8 : 2 }, highlighted && { backgroundColor: c.cardSubtle, borderRadius: 12 }]}
    >
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        {selectMode ? (
          <View style={[styles.checkCircle, { borderColor: selected ? c.coral : c.hairline, backgroundColor: selected ? c.coral : 'transparent' }]}>
            {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
          </View>
        ) : null}
        <View style={{ flex: 1 }}>{inner}</View>
      </View>
    </Pressable>
  );
}

/** Renders message text with @mentions highlighted. */
function MentionText({ text, color, mentionColor }: { text: string; color: string; mentionColor: string }) {
  const parts = text.split(/(@[^\s@]+)/g);
  return (
    <Text style={{ color, fontSize: 15.5 }}>
      {parts.map((p, i) =>
        p.startsWith('@')
          ? <Text key={i} style={{ color: mentionColor, fontWeight: '600' }}>{p}</Text>
          : p,
      )}
    </Text>
  );
}

const styles = StyleSheet.create({
  navbar: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 12, gap: 10 },
  iconBtn: { width: 40, height: 40, borderRadius: 20, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  navTitle: { fontSize: 16, fontWeight: '600' },
  navSubtitle: { fontSize: 12, fontWeight: '500', marginTop: 1 },
  pinnedBanner: { flexDirection: 'row', alignItems: 'center', gap: 9, marginHorizontal: 12, marginBottom: 6, paddingHorizontal: 12, paddingVertical: 9, borderRadius: radius.md, borderWidth: 1 },
  rowRight: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'flex-end' },
  rowLeft: { flexDirection: 'row', alignItems: 'flex-start' },
  bubble: { paddingHorizontal: 14, paddingVertical: 10, borderRadius: radius.lg },
  recalled: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: radius.sm },
  videoBox: {
    width: 200, height: 140, borderRadius: radius.lg, backgroundColor: '#1a1a1a',
    alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
  },
  playCircle: {
    width: 50, height: 50, borderRadius: 25, backgroundColor: 'rgba(0,0,0,0.45)',
    alignItems: 'center', justifyContent: 'center',
  },
  videoBadge: { position: 'absolute', top: 8, right: 8 },
  quote: { maxWidth: '88%', borderRadius: 10, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 6, marginBottom: 4 },
  checkCircle: { width: 22, height: 22, borderRadius: 11, borderWidth: 2, marginRight: 8, alignItems: 'center', justifyContent: 'center' },
  time: { fontSize: 10, fontWeight: '500', marginBottom: 6 },
  inputBar: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 14, paddingTop: 8, paddingBottom: 8 },
  inputField: { flex: 1, borderRadius: 20, borderWidth: 1, paddingHorizontal: 16, paddingVertical: 7, justifyContent: 'center' },
  selectBar: { flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center', borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 8, paddingBottom: 14 },
  selectAction: { alignItems: 'center', justifyContent: 'center', paddingHorizontal: 24, paddingVertical: 4 },
  replyBar: { flexDirection: 'row', alignItems: 'center', gap: 10, borderTopWidth: StyleSheet.hairlineWidth, paddingHorizontal: 16, paddingVertical: 8 },
  replyAccent: { width: 3, alignSelf: 'stretch', borderRadius: 2 },
  sendBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
