import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
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
import { NavBar, RoundIconButton } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { confirmAsync, notify } from '@/lib/dialog';
import { addFavorite } from '@/lib/favorites';
import { useI18n } from '@/lib/i18n';
import { getCachedMessages, getMemCachedMessages, setCachedMessages } from '@/lib/messageCache';
import { recallErrorKey, withinRecallWindow } from '@/lib/recall';
import { supabase } from '@/lib/supabase';
import { gradients, radius, useTheme } from '@/lib/theme';
import type { ChatMessage } from '@/lib/types';

export default function ChatDetail() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();
  const { block, contacts } = useAppData();
  const params = useLocalSearchParams<{
    threadId: string; otherUserId: string; title?: string; avatarUrl?: string;
  }>();
  const threadId = params.threadId;
  const otherUserId = params.otherUserId;
  const title = params.title ?? 'Chat';

  // Seed synchronously from the in-memory cache → instant, spinner-free re-entry.
  const [messages, setMessages] = useState<ChatMessage[]>(
    () => getMemCachedMessages<ChatMessage>(`dm.${threadId}`) ?? [],
  );
  const [overflowOpen, setOverflowOpen] = useState(false);
  const [menuMsg, setMenuMsg] = useState<ChatMessage | null>(null);
  const [showAttach, setShowAttach] = useState(false);
  const [loading, setLoading] = useState(() => {
    const c = getMemCachedMessages<ChatMessage>(`dm.${threadId}`);
    return !c || c.length === 0;
  });
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);
  const [sendingImage, setSendingImage] = useState(false);
  const [sendingVoice, setSendingVoice] = useState(false);

  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [selectMode, setSelectMode] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [highlightId, setHighlightId] = useState<string | null>(null);
  const [viewerUri, setViewerUri] = useState<string | null>(null);
  const [viewerKey, setViewerKey] = useState<string | null>(null);
  const [viewerVideoPath, setViewerVideoPath] = useState<string | null>(null);

  const listRef = useRef<FlatList<ChatMessage>>(null);

  const reload = useCallback(async () => {
    if (!userId) return;
    try {
      const rows = await api.loadThreadMessages(threadId, userId);
      setMessages(rows);
      void setCachedMessages(`dm.${threadId}`, rows);
    } catch (e) {
      console.warn('loadThreadMessages failed', e);
    } finally {
      setLoading(false);
    }
  }, [threadId, userId]);

  // Initial load + mark read + realtime subscription.
  useEffect(() => {
    // Show the last cached view instantly, then refresh from the server.
    getCachedMessages<ChatMessage>(`dm.${threadId}`).then((cached) => {
      if (cached && cached.length) {
        setMessages((prev) => (prev.length ? prev : cached));
        setLoading(false);
      }
    });
    void reload();
    api.markThreadRead(threadId).catch(() => {});

    const channel = supabase
      .channel(`dm-${threadId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'dm_messages', filter: `thread_id=eq.${threadId}` },
        () => { void reload(); },
      )
      .subscribe();

    return () => { void supabase.removeChannel(channel); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [threadId, userId]);

  // Keep the newest message visible as the list grows.
  const scrollToEnd = useCallback(() => {
    requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
  }, []);

  useEffect(() => {
    if (messages.length > 0 && !highlightId) scrollToEnd();
  }, [messages.length, scrollToEnd, highlightId]);

  // Fast id → message / index lookups for reply previews and jump-to-quote.
  const byId = useMemo(() => {
    const m = new Map<string, ChatMessage>();
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

  // ─────────────────────────── Overflow menu ───────────────────────────

  function openMenu() {
    setOverflowOpen(true);
  }

  async function confirmBlock() {
    const ok = await confirmAsync(t('blockAction'), t('blockConfirm'), {
      confirmLabel: t('blockAction'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await block(otherUserId);
      router.back();
    } catch {
      notify(t('blockError'));
    }
  }

  async function clearHistory() {
    const ok = await confirmAsync(t('chatClearHistory'), t('chatClearHistoryConfirm'), {
      confirmLabel: t('chatClearHistory'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await api.clearDMHistory(threadId);
      await reload();
    } catch (e) {
      console.warn('clearDMHistory failed', e);
    }
  }

  // ─────────────────────────── Send ───────────────────────────

  async function send() {
    const text = draft.trim();
    if (!text || sending) return;
    const replyId = replyTo?.id ?? null;
    setDraft('');
    setReplyTo(null);
    setSending(true);
    try {
      await api.sendMessage(otherUserId, text, replyId);
      await reload();
    } catch {
      setDraft(text);
      // If they're no longer in our friends list, the send was rejected because
      // the friendship was removed — say so instead of a generic error.
      const stillFriend = contacts.some((ct) => ct.id === otherUserId);
      notify(stillFriend ? t('chatSendError') : t('chatFriendRemoved'));
    } finally {
      setSending(false);
    }
  }

  async function pickImage() {
    if (sendingImage) return;
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      // quality 1 + no editing is required to keep animated GIFs animated (Android).
      quality: 1,
      allowsEditing: false,
    });
    if (result.canceled || !result.assets.length) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendImageMessage(otherUserId, threadId, asset.uri, asset.width ?? 0, asset.height ?? 0, '', asset.mimeType || asset.fileName || asset.uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingImage(false);
    }
  }

  async function pickVideo() {
    if (sendingImage) return;
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['videos'],
      quality: 1,
      allowsEditing: false,
    });
    if (result.canceled || !result.assets.length) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendVideoMessage(otherUserId, threadId, asset.uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingImage(false);
    }
  }

  async function pickDocument() {
    if (sendingImage) return;
    const result = await DocumentPicker.getDocumentAsync({ copyToCacheDirectory: true });
    if (result.canceled || !result.assets?.length) return;
    const asset = result.assets[0];
    setSendingImage(true);
    try {
      await api.sendFileMessage(
        otherUserId, threadId, asset.uri, asset.name, asset.size ?? null,
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
    if (sendingVoice) return;
    setSendingVoice(true);
    try {
      await api.sendVoiceMessage(otherUserId, threadId, uri);
      await reload();
    } catch {
      notify(t('chatSendError'));
    } finally {
      setSendingVoice(false);
    }
  }

  // ─────────────────────────── Message actions ───────────────────────────

  function excerpt(msg: ChatMessage): string {
    if (msg.isRecalled) return t('chatMessageRecalled');
    const text = msg.text?.trim();
    if (text) return text;
    if (msg.kind === 'image') return t('chatImagePreview');
    if (msg.kind === 'audio') return t('chatVoicePreview');
    return t('chatFilePreview');
  }

  function favoriteMessage(msg: ChatMessage) {
    void addFavorite({
      id: msg.id, text: excerpt(msg), kind: msg.kind, sender: msg.sender, source: title, at: Date.now(),
      imagePath: (msg.kind === 'image' || msg.kind === 'audio' || msg.kind === 'video' || msg.kind === 'file') ? msg.imagePath : null,
      fileName: msg.fileName ?? null,
      fileMime: msg.fileMime ?? null,
    });
  }

  async function copyMessage(msg: ChatMessage) {
    await Clipboard.setStringAsync(msg.text ?? '');
    notify(t('chatCopied'));
  }

  async function recall(msg: ChatMessage) {
    try {
      await api.recallMessage(msg.id, 'dm');
      await reload();
    } catch (e) {
      notify(t(recallErrorKey(e)));
    }
  }

  async function deleteOne(msg: ChatMessage) {
    const ok = await confirmAsync(t('chatDelete'), t('chatDeleteConfirm'), {
      confirmLabel: t('chatDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      await api.deleteMessageForMe(msg.id, 'dm');
      await reload();
    } catch (e) {
      console.warn('deleteMessageForMe failed', e);
    }
  }

  function reportMessage(msg: ChatMessage) {
    router.push({
      pathname: '/report',
      params: {
        reportedUserId: otherUserId,
        messageId: msg.id,
        messageKind: 'dm',
        excerpt: msg.text,
        blockableUserId: otherUserId,
      },
    });
  }

  function enterSelect(msg: ChatMessage) {
    setSelectMode(true);
    setSelected(new Set([msg.id]));
  }

  function exitSelect() {
    setSelectMode(false);
    setSelected(new Set());
  }

  function toggleSelect(msg: ChatMessage) {
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
    router.push({ pathname: '/forward', params: { kind: 'dm', messageIds: ids.join(',') } });
    exitSelect();
  }

  async function deleteSelected() {
    if (selected.size === 0) return;
    const ok = await confirmAsync(t('chatDelete'), t('chatDeleteSelectedConfirm'), {
      confirmLabel: t('chatDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      for (const id of selected) await api.deleteMessageForMe(id, 'dm');
      await reload();
    } catch (e) {
      console.warn('delete selected failed', e);
    } finally {
      exitSelect();
    }
  }

  // Build the long-press action sheet for a single message (QQ-style).
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
        onPress: () => router.push({ pathname: '/forward', params: { kind: 'dm', messageId: m.id } }),
      });
      acts.push({ label: t('favoriteAction'), icon: 'bookmark', onPress: () => favoriteMessage(m) });
    }
    acts.push({ label: t('chatSelect'), icon: 'checkmark-circle', onPress: () => enterSelect(m) });
    if (m.sender === 'me' && !m.isRecalled && withinRecallWindow(m)) {
      acts.push({ label: t('chatRecall'), icon: 'refresh', onPress: () => void recall(m) });
    }
    acts.push({ label: t('chatDelete'), icon: 'trash', destructive: true, onPress: () => void deleteOne(m) });
    if (m.sender !== 'me' && !m.isRecalled) {
      acts.push({ label: t('reportTitle'), icon: 'flag', onPress: () => reportMessage(m) });
    }
    return acts;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [menuMsg, t]);

  const canSend = draft.trim().length > 0 && !sending;
  const lastMineId = [...messages].reverse().find((m) => m.sender === 'me')?.id ?? null;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      {selectMode ? (
        <NavBar
          title={`${t('chatSelectedLabel')} ${selected.size}`}
          onBack={exitSelect}
          backIcon="close"
        />
      ) : (
        <NavBar
          title={title}
          subtitle={t('chatDetailOffline')}
          onBack={() => router.back()}
          onTitlePress={() => {
            const ct = contacts.find((c) => c.id === otherUserId);
            router.push({
              pathname: '/contact/[id]',
              params: {
                id: otherUserId,
                name: ct?.name ?? title,
                handle: ct?.handle ?? '',
                role: ct?.role ?? '',
                followers: ct?.followers ?? '0',
                avatarUrl: ct?.avatarUrl ?? params.avatarUrl ?? '',
              },
            });
          }}
          right={<RoundIconButton icon="ellipsis-horizontal" onPress={openMenu} />}
        />
      )}

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 8 : 0}
      >
        {loading && messages.length === 0 ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator color={c.coral} />
          </View>
        ) : messages.length === 0 ? (
          <View style={styles.emptyWrap}>
            <Ionicons name="chatbubbles-outline" size={40} color={c.inkTertiary} />
            <Text style={{ color: c.inkSecondary, fontSize: 15, fontWeight: '500', marginTop: 12 }}>
              {t('chatThreadEmpty')}
            </Text>
          </View>
        ) : (
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(m) => m.id}
            contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 12, gap: 8 }}
            onContentSizeChange={() => { if (!highlightId) scrollToEnd(); }}
            keyboardShouldPersistTaps="handled"
            onScrollToIndexFailed={(info) => {
              listRef.current?.scrollToOffset({ offset: info.averageItemLength * info.index, animated: true });
              setTimeout(() => {
                listRef.current?.scrollToIndex({ index: info.index, animated: true, viewPosition: 0.35 });
              }, 300);
            }}
            renderItem={({ item }) => (
              <MessageBubble
                message={item}
                otherName={title}
                showReceipt={item.id === lastMineId}
                selectMode={selectMode}
                selected={selected.has(item.id)}
                highlighted={highlightId === item.id}
                repliedTo={item.replyTo ? byId.get(item.replyTo) ?? null : null}
                onLongPress={() => { if (!selectMode) setMenuMsg(item); }}
                onPress={() => {
                  if (selectMode) toggleSelect(item);
                  else if (item.kind === 'image' && item.imagePath) openImage(item);
                  else if (item.kind === 'video' && item.imagePath) openVideo(item);
                }}
                onJumpToReply={item.replyTo ? () => jumpToMessage(item.replyTo!) : undefined}
              />
            )}
          />
        )}

        {/* Reply preview */}
        {replyTo && !selectMode ? (
          <View style={[styles.replyBar, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
            <View style={[styles.replyAccent, { backgroundColor: c.coral }]} />
            <View style={{ flex: 1 }}>
              <Text style={{ color: c.coral, fontSize: 12, fontWeight: '700' }} numberOfLines={1}>
                {t('chatReplyingTo')} {replyTo.sender === 'me' ? t('chatYou') : title}
              </Text>
              <Text style={{ color: c.inkSecondary, fontSize: 13, marginTop: 1 }} numberOfLines={1}>
                {excerpt(replyTo)}
              </Text>
            </View>
            <Pressable onPress={() => setReplyTo(null)} hitSlop={8} style={{ padding: 4 }}>
              <Ionicons name="close-circle" size={20} color={c.inkTertiary} />
            </Pressable>
          </View>
        ) : null}

        {/* Input bar / selection action bar */}
        {selectMode ? (
          <View style={[styles.selectBar, { backgroundColor: c.paper, borderColor: c.hairline }]}>
            <Pressable
              onPress={forwardSelected}
              disabled={selected.size === 0}
              style={styles.selectAction}
              hitSlop={6}
            >
              <Ionicons name="arrow-redo" size={22} color={selected.size === 0 ? c.inkTertiary : c.ink} />
              <Text style={{ color: selected.size === 0 ? c.inkTertiary : c.ink, fontSize: 12, marginTop: 3 }}>
                {t('chatForward')}
              </Text>
            </Pressable>
            <Pressable
              onPress={deleteSelected}
              disabled={selected.size === 0}
              style={styles.selectAction}
              hitSlop={6}
            >
              <Ionicons name="trash" size={22} color={selected.size === 0 ? c.inkTertiary : c.danger} />
              <Text style={{ color: selected.size === 0 ? c.inkTertiary : c.danger, fontSize: 12, marginTop: 3 }}>
                {t('chatDelete')}
              </Text>
            </Pressable>
          </View>
        ) : (
          <View style={[styles.inputBar, { backgroundColor: c.paper }]}>
            <Pressable onPress={() => setShowAttach(true)} disabled={sendingImage} hitSlop={8} style={styles.plusBtn}>
              {sendingImage ? (
                <ActivityIndicator color={c.coral} />
              ) : (
                <Ionicons name="add" size={26} color={c.inkSecondary} />
              )}
            </Pressable>

            <View style={[styles.inputField, { backgroundColor: c.card, borderColor: c.hairline }]}>
              <TextInput
                value={draft}
                onChangeText={setDraft}
                placeholder={t('chatDetailMessagePlaceholder')}
                placeholderTextColor={c.inkTertiary}
                multiline
                style={{ flex: 1, fontSize: 16, color: c.ink, maxHeight: 110 }}
              />
            </View>

            {canSend ? (
              <Pressable onPress={send} disabled={!canSend} hitSlop={6}>
                <LinearGradient
                  colors={gradients.sunset}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.sendBtn}
                >
                  {sending ? (
                    <ActivityIndicator color="#fff" size="small" />
                  ) : (
                    <Ionicons name="arrow-up" size={20} color="#fff" />
                  )}
                </LinearGradient>
              </Pressable>
            ) : (
              <VoiceRecordButton onComplete={sendVoice} sending={sendingVoice} />
            )}
          </View>
        )}
      </KeyboardAvoidingView>

      {overflowOpen ? (
        <ActionSheet
          visible={overflowOpen}
          title={title}
          cancelLabel={t('authCancel')}
          onClose={() => setOverflowOpen(false)}
          actions={[
            {
              label: t('reportTitle'), icon: 'flag',
              onPress: () => router.push({ pathname: '/report', params: { reportedUserId: otherUserId, blockableUserId: otherUserId } }),
            },
            { label: t('blockAction'), icon: 'hand-left', destructive: true, onPress: confirmBlock },
            { label: t('chatClearHistory'), icon: 'trash', destructive: true, onPress: clearHistory },
          ]}
        />
      ) : null}

      {menuMsg ? (
        <ActionSheet
          visible={!!menuMsg}
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

      <ImageViewer
        visible={!!viewerUri}
        uri={viewerUri}
        cacheKey={viewerKey}
        onClose={() => { setViewerUri(null); setViewerKey(null); }}
      />
      <VideoViewer visible={!!viewerVideoPath} path={viewerVideoPath} onClose={() => setViewerVideoPath(null)} />
    </SafeAreaView>
  );

  function openImage(msg: ChatMessage) {
    if (!msg.imagePath) return;
    setViewerKey(msg.imagePath);
    api.signedMediaUrl(msg.imagePath)
      .then((u) => setViewerUri(u))
      .catch(() => notify(t('chatSendError')));
  }

  function openVideo(msg: ChatMessage) {
    if (!msg.imagePath) return;
    setViewerVideoPath(msg.imagePath);
  }
}

// ─────────────────────────── Message bubble ───────────────────────────

function MessageBubble({
  message, otherName, showReceipt, selectMode, selected, highlighted, repliedTo,
  onLongPress, onPress, onJumpToReply,
}: {
  message: ChatMessage;
  otherName: string;
  showReceipt: boolean;
  selectMode: boolean;
  selected: boolean;
  highlighted: boolean;
  repliedTo: ChatMessage | null;
  onLongPress: () => void;
  onPress: () => void;
  onJumpToReply?: () => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const isMe = message.sender === 'me';

  function repliedExcerpt(m: ChatMessage): string {
    if (m.isRecalled) return t('chatMessageRecalled');
    const text = m.text?.trim();
    if (text) return text;
    if (m.kind === 'image') return t('chatImagePreview');
    if (m.kind === 'audio') return t('chatVoicePreview');
    return t('chatFilePreview');
  }

  return (
    <Pressable
      onPress={onPress}
      onLongPress={onLongPress}
      delayLongPress={350}
      style={[
        styles.row,
        { alignItems: 'center' },
        highlighted && { backgroundColor: c.cardSubtle, borderRadius: 12 },
      ]}
    >
      {selectMode ? (
        <View style={[styles.checkCircle, { borderColor: selected ? c.coral : c.hairline, backgroundColor: selected ? c.coral : 'transparent' }]}>
          {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
        </View>
      ) : null}

      <View style={{ flex: 1, alignItems: isMe ? 'flex-end' : 'flex-start' }}>
        {/* Quoted reply preview (tap to jump) */}
        {repliedTo ? (
          <Pressable
            onPress={onJumpToReply}
            disabled={selectMode}
            style={[styles.quote, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}
          >
            <Text style={{ color: c.inkTertiary, fontSize: 11.5 }} numberOfLines={1}>
              {repliedTo.sender === 'me' ? t('chatYou') : otherName}: {repliedExcerpt(repliedTo)}
            </Text>
          </Pressable>
        ) : null}

        <View style={{ maxWidth: '82%' }}>
          {message.isRecalled ? (
            <View style={[styles.recalled, { backgroundColor: c.cardSubtle }]}>
              <Text style={{ color: c.inkTertiary, fontSize: 13, fontStyle: 'italic' }}>
                {t('chatMessageRecalled')}
              </Text>
            </View>
          ) : message.kind === 'audio' && message.imagePath ? (
            <AudioBubble
              path={message.imagePath}
              isMe={isMe}
              onLongPress={onLongPress}
              onPress={onPress}
              selectMode={selectMode}
            />
          ) : message.kind === 'video' && message.imagePath ? (
            <VideoBubble />
          ) : message.kind === 'image' && message.imagePath ? (
            <ImageBubble message={message} isMe={isMe} />
          ) : message.kind === 'file' && message.imagePath ? (
            <FileBubble
              message={message}
              isMe={isMe}
              onLongPress={onLongPress}
              onPress={onPress}
              selectMode={selectMode}
            />
          ) : (
            <View style={isMe ? styles.mineWrap : [styles.theirsWrap, { backgroundColor: c.cardSubtle }]}>
              {isMe ? (
                <LinearGradient
                  colors={gradients.sunset}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.bubble}
                >
                  <Text style={[styles.bubbleText, { color: '#fff' }]}>{message.text}</Text>
                </LinearGradient>
              ) : (
                <View style={styles.bubble}>
                  <Text style={[styles.bubbleText, { color: c.ink }]}>{message.text}</Text>
                </View>
              )}
            </View>
          )}

          <View style={[styles.metaRow, { justifyContent: isMe ? 'flex-end' : 'flex-start' }]}>
            <Text style={{ color: c.inkTertiary, fontSize: 10, fontWeight: '500' }}>{message.time}</Text>
            {isMe && showReceipt && !message.isRecalled && (
              <Text style={{ color: c.inkTertiary, fontSize: 10, fontWeight: '500', marginLeft: 6 }}>
                {message.readAt ? t('chatRead') : t('chatDelivered')}
              </Text>
            )}
          </View>
        </View>
      </View>
    </Pressable>
  );
}

// ─────────────────────────── Image bubble ───────────────────────────

function ImageBubble({ message, isMe }: { message: ChatMessage; isMe: boolean }) {
  const c = useTheme();
  const { t } = useI18n();
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let active = true;
    setFailed(false);
    if (!message.imagePath) return;
    api
      .signedMediaUrl(message.imagePath)
      .then((u) => { if (active) setUrl(u); })
      .catch(() => { if (active) setFailed(true); });
    return () => { active = false; };
  }, [message.imagePath]);

  // Cap to a chat-friendly box while preserving aspect ratio.
  const maxW = 232;
  const maxH = 300;
  const w = Math.max(message.imageWidth ?? 0, 0);
  const h = Math.max(message.imageHeight ?? 0, 0);
  let dw = maxW;
  let dh = maxW * 0.7;
  if (w > 0 && h > 0) {
    const ratio = h / w;
    dw = maxW;
    dh = dw * ratio;
    if (dh > maxH) { dh = maxH; dw = dh / ratio; }
  }

  return (
    <View>
      <View style={[styles.imageBox, { width: dw, height: dh, backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
        {failed ? (
          <View style={{ alignItems: 'center', paddingHorizontal: 12 }}>
            <Ionicons name="image-outline" size={26} color={c.inkTertiary} />
            <Text style={{ color: c.inkTertiary, fontSize: 12, marginTop: 6, textAlign: 'center' }}>
              {t('chatImageExpired')}
            </Text>
          </View>
        ) : url ? (
          <Image
            source={{ uri: url, cacheKey: message.imagePath ?? undefined }}
            cachePolicy="memory-disk"
            style={{ width: dw, height: dh }}
            contentFit="cover"
            onError={() => setFailed(true)}
          />
        ) : (
          <ActivityIndicator color={c.coral} />
        )}
      </View>
      {message.text.length > 0 && (
        <View style={[isMe ? styles.mineWrap : [styles.theirsWrap, { backgroundColor: c.cardSubtle }], { marginTop: 4 }]}>
          {isMe ? (
            <LinearGradient
              colors={gradients.sunset}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.bubble}
            >
              <Text style={[styles.bubbleText, { color: '#fff' }]}>{message.text}</Text>
            </LinearGradient>
          ) : (
            <View style={styles.bubble}>
              <Text style={[styles.bubbleText, { color: c.ink }]}>{message.text}</Text>
            </View>
          )}
        </View>
      )}
    </View>
  );
}

// ─────────────────────────── Video bubble ───────────────────────────

/** Presentational video tile — a dark box with a play overlay. Tapping is handled
 *  by the row's onPress (opens the fullscreen VideoViewer). */
function VideoBubble() {
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

const styles = StyleSheet.create({
  emptyWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingBottom: 60 },
  row: { flexDirection: 'row', width: '100%' },
  checkCircle: {
    width: 22, height: 22, borderRadius: 11, borderWidth: 2, marginRight: 8,
    alignItems: 'center', justifyContent: 'center',
  },
  quote: {
    maxWidth: '82%', borderRadius: 10, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 6, marginBottom: 4,
  },
  mineWrap: { borderRadius: 20, overflow: 'hidden' },
  theirsWrap: { borderRadius: 20, overflow: 'hidden' },
  bubble: { paddingHorizontal: 14, paddingVertical: 10 },
  bubbleText: { fontSize: 15.5 },
  recalled: {
    paddingHorizontal: 14, paddingVertical: 8, borderRadius: radius.sm, alignSelf: 'flex-start',
  },
  metaRow: { flexDirection: 'row', alignItems: 'center', marginTop: 3, paddingHorizontal: 2 },
  videoBox: {
    width: 200, height: 140, borderRadius: 20, backgroundColor: '#1a1a1a',
    alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
  },
  playCircle: {
    width: 50, height: 50, borderRadius: 25, backgroundColor: 'rgba(0,0,0,0.45)',
    alignItems: 'center', justifyContent: 'center',
  },
  videoBadge: { position: 'absolute', top: 8, right: 8 },
  imageBox: {
    borderRadius: 20, borderWidth: 1, overflow: 'hidden',
    alignItems: 'center', justifyContent: 'center',
  },
  replyBar: {
    flexDirection: 'row', alignItems: 'center', gap: 10, borderTopWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: 16, paddingVertical: 8,
  },
  replyAccent: { width: 3, alignSelf: 'stretch', borderRadius: 2 },
  inputBar: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    paddingHorizontal: 14, paddingTop: 8, paddingBottom: 8,
  },
  selectBar: {
    flexDirection: 'row', justifyContent: 'space-around', alignItems: 'center',
    borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 8, paddingBottom: 14,
  },
  selectAction: { alignItems: 'center', justifyContent: 'center', paddingHorizontal: 24, paddingVertical: 4 },
  plusBtn: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  inputField: {
    flex: 1, flexDirection: 'row', alignItems: 'center', borderRadius: 20, borderWidth: 1,
    paddingHorizontal: 16, paddingVertical: 6,
  },
  sendBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
