import { Ionicons } from '@expo/vector-icons';
import { useFocusEffect, useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useCallback, useMemo, useState } from 'react';
import {
  FlatList, Pressable, RefreshControl, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Swipeable } from 'react-native-gesture-handler';

import { ActionSheet } from '@/components/ActionSheet';
import { Avatar, EmptyState, RoundIconButton } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { setMuted, setPinned } from '@/lib/convPrefs';
import { confirmAsync } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, space, useTheme } from '@/lib/theme';
import type { Conversation } from '@/lib/types';
import type { Href } from 'expo-router';

export default function ChatsScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const {
    conversations, loadingConversations, refreshConversations, unreadTotal, mutedIds, pinnedIds,
  } = useAppData();

  const [search, setSearch] = useState('');
  const [showSearch, setShowSearch] = useState(false);
  const [showAddMenu, setShowAddMenu] = useState(false);
  const [menuConv, setMenuConv] = useState<Conversation | null>(null);

  // Refresh on focus (silently) so the "@me" indicator clears after you read a
  // group and the inbox stays current without a manual pull-to-refresh.
  useFocusEffect(
    useCallback(() => {
      void refreshConversations(true);
    }, [refreshConversations]),
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const base = q
      ? conversations.filter(
          (conv) =>
            conv.name.toLowerCase().includes(q) ||
            conv.lastMessage.toLowerCase().includes(q),
        )
      : conversations;
    // Pinned conversations float to the top (stable — keeps recency within groups).
    return [...base].sort((a, b) => (pinnedIds.has(b.id) ? 1 : 0) - (pinnedIds.has(a.id) ? 1 : 0));
  }, [conversations, search, pinnedIds]);

  async function togglePin(conv: Conversation) {
    await setPinned(conv.id, !pinnedIds.has(conv.id));
    await refreshConversations();
  }

  async function toggleMute(conv: Conversation) {
    await setMuted(conv.id, !mutedIds.has(conv.id));
    await refreshConversations();
  }

  async function deleteConversation(conv: Conversation) {
    const ok = await confirmAsync(t('convDelete'), t('chatDeleteConversationWarn'), {
      confirmLabel: t('convDelete'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    try {
      // Clear the history (unrecoverable, as warned) then remove it from the list.
      if (conv.isGroup) await api.clearGroupHistory(conv.id);
      else await api.clearDMHistory(conv.id);
      await api.hideConversation(conv.id, conv.isGroup ? 'group' : 'dm');
      await refreshConversations();
    } catch {
      // best effort
    }
  }

  function previewText(conv: Conversation): string {
    const youPrefix = `${t('chatYou')}: `;
    if (conv.lastMessageRecalled) {
      const recalled = t('chatMessageRecalled');
      return conv.lastFromMe ? youPrefix + recalled : recalled;
    }
    let base: string;
    switch (conv.lastMessageType) {
      case 'file': base = t('chatFilePreview'); break;
      case 'audio': base = t('chatVoicePreview'); break;
      case 'video': base = t('chatVideoPreview'); break;
      case 'image': base = conv.lastMessage.length > 0 ? conv.lastMessage : t('chatImagePreview'); break;
      default: base = conv.lastMessage;
    }
    if (!base) return '';
    return conv.lastFromMe ? youPrefix + base : base;
  }

  function openConversation(conv: Conversation) {
    if (conv.isGroup) {
      router.push({
        pathname: '/group/[groupId]',
        params: {
          groupId: conv.id,
          title: conv.name,
          memberCount: String(conv.participantCount),
        },
      });
    } else {
      router.push({
        pathname: '/chat/[threadId]',
        params: {
          threadId: conv.id,
          otherUserId: conv.otherUserId ?? conv.id,
          title: conv.name,
          avatarUrl: conv.avatarUrl ?? '',
        },
      });
    }
  }

  function renderRow({ item, index }: { item: Conversation; index: number }) {
    const isLast = index === filtered.length - 1;
    const muted = mutedIds.has(item.id);
    const pinned = pinnedIds.has(item.id);
    return (
      <Swipeable
        renderRightActions={() => (
          <Pressable
            onPress={() => deleteConversation(item)}
            style={[styles.swipeDelete, { backgroundColor: c.danger }]}
          >
            <Ionicons name="trash" size={22} color="#fff" />
          </Pressable>
        )}
        overshootRight={false}
      >
      <View style={[styles.rowWrap, { backgroundColor: c.card, borderColor: c.hairline }]}>
        <Pressable
          onPress={() => openConversation(item)}
          onLongPress={() => setMenuConv(item)}
          delayLongPress={350}
          style={({ pressed }) => [styles.row, { backgroundColor: pressed || pinned ? c.cardSubtle : c.card }]}
        >
          <Avatar
            colors={item.avatarColors}
            name={item.name}
            imageUrl={item.avatarUrl}
            size={54}
            online={item.isOnline}
            symbol={item.isGroup ? 'people' : undefined}
          />
          <View style={styles.rowBody}>
            <View style={styles.rowTitleLine}>
              <Text style={[styles.rowName, { color: c.ink }]} numberOfLines={1}>
                {item.name}
              </Text>
              {item.isOfficial ? (
                <Ionicons name="checkmark-circle" size={13} color={c.coral} style={{ marginLeft: 6 }} />
              ) : null}
              {item.isGroup ? (
                <Ionicons name="people" size={12} color={c.inkSecondary} style={{ marginLeft: 6 }} />
              ) : null}
              {pinned ? (
                <Ionicons name="pin" size={11} color={c.coral} style={{ marginLeft: 6 }} />
              ) : null}
            </View>
            <Text style={[styles.rowPreview, { color: c.inkSecondary }]} numberOfLines={1}>
              {item.mentioned ? (
                <Text style={{ color: c.coral, fontWeight: '700' }}>[{t('mentionsYouLabel')}] </Text>
              ) : null}
              {previewText(item)}
            </Text>
          </View>
          <View style={styles.rowTrailing}>
            <Text style={[styles.rowTime, { color: item.unread > 0 && !muted ? c.coral : c.inkTertiary }]}>
              {item.time}
            </Text>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4 }}>
              {muted ? <Ionicons name="notifications-off" size={13} color={c.inkTertiary} /> : null}
              {item.unread > 0 ? (
                <View style={[styles.unreadBadge, { backgroundColor: muted ? c.inkTertiary : c.coral }]}>
                  <Text style={styles.unreadText}>{item.unread > 99 ? '99+' : item.unread}</Text>
                </View>
              ) : null}
            </View>
          </View>
        </Pressable>
        {!isLast ? (
          <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: 82 }} />
        ) : null}
      </View>
      </Swipeable>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={[styles.title, { color: c.ink }]}>{t('chatsTitle')}</Text>
          <Text style={[styles.subtitle, { color: c.inkSecondary }]}>
            {unreadTotal > 0 ? `${unreadTotal} ${t('chatsUnread')}` : t('chatsCaughtUp')}
          </Text>
        </View>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
          <RoundIconButton
            icon={showSearch ? 'close' : 'search'}
            onPress={() => setShowSearch((v) => { if (v) setSearch(''); return !v; })}
          />
          <RoundIconButton icon="add" onPress={() => setShowAddMenu(true)} />
        </View>
      </View>

      <WeListeningBanner onPress={() => router.push('/support' as Href)} />

      {showSearch ? (
        <View style={styles.searchWrap}>
          <View style={[styles.searchField, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Ionicons name="search" size={16} color={c.inkSecondary} style={{ marginRight: 8 }} />
            <TextInput
              value={search}
              onChangeText={setSearch}
              placeholder={t('chatsSearch')}
              placeholderTextColor={c.inkTertiary}
              style={[styles.searchInput, { color: c.ink }]}
              returnKeyType="search"
              autoCapitalize="none"
              autoCorrect={false}
              autoFocus
            />
            {search.length > 0 ? (
              <Pressable onPress={() => setSearch('')} hitSlop={8}>
                <Ionicons name="close-circle" size={18} color={c.inkTertiary} />
              </Pressable>
            ) : null}
          </View>
        </View>
      ) : null}

      <FlatList
        data={filtered}
        keyExtractor={(item) => item.id}
        renderItem={renderRow}
        contentContainerStyle={
          filtered.length === 0
            ? styles.emptyContainer
            : { paddingHorizontal: space.lg, paddingTop: space.xs, paddingBottom: space.xxl }
        }
        ListHeaderComponent={
          filtered.length > 0 ? (
            <View
              style={[styles.cardTop, { backgroundColor: c.card, borderColor: c.hairline }]}
            />
          ) : null
        }
        ListFooterComponent={
          filtered.length > 0 ? (
            <View
              style={[styles.cardBottom, { backgroundColor: c.card, borderColor: c.hairline }]}
            />
          ) : null
        }
        ListEmptyComponent={
          <EmptyState icon="chatbubbles-outline" title={t('chatsEmpty')} />
        }
        refreshControl={
          <RefreshControl
            refreshing={loadingConversations}
            onRefresh={refreshConversations}
            tintColor={c.coral}
          />
        }
      />

      {menuConv ? (
        <ActionSheet
          visible={!!menuConv}
          title={menuConv.name}
          cancelLabel={t('authCancel')}
          onClose={() => setMenuConv(null)}
          actions={[
            {
              label: pinnedIds.has(menuConv.id) ? t('convUnpin') : t('convPin'),
              icon: 'pin',
              onPress: () => togglePin(menuConv),
            },
            {
              label: mutedIds.has(menuConv.id) ? t('convUnmute') : t('convMute'),
              icon: 'notifications-off',
              onPress: () => toggleMute(menuConv),
            },
            {
              label: t('convDelete'),
              icon: 'trash',
              destructive: true,
              onPress: () => deleteConversation(menuConv),
            },
          ]}
        />
      ) : null}

      {showAddMenu ? (
        <ActionSheet
          visible={showAddMenu}
          cancelLabel={t('authCancel')}
          onClose={() => setShowAddMenu(false)}
          actions={[
            { label: t('chatsNewGroup'), icon: 'people', onPress: () => router.push('/create-group') },
            { label: t('chatsAddFriend'), icon: 'person-add', onPress: () => router.push('/add-friend') },
            { label: t('chatsScan'), icon: 'scan', onPress: () => router.push('/qr-scan') },
          ]}
        />
      ) : null}
    </SafeAreaView>
  );
}

/** "We're Listening" — a pinned feedback banner at the top of Chats. Opens the
 *  feedback form. Kept here until the team asks to remove it. */
function WeListeningBanner({ onPress }: { onPress: () => void }) {
  const { t } = useI18n();
  return (
    <Pressable onPress={onPress} style={{ paddingHorizontal: space.lg, marginBottom: space.md }}>
      <LinearGradient colors={gradients.sunset} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.banner}>
        <View style={styles.bannerIcon}>
          <Ionicons name="megaphone" size={20} color="#fff" />
        </View>
        <View style={{ flex: 1 }}>
          <Text style={styles.bannerTitle}>{t('supportTitle')}</Text>
          <Text style={styles.bannerSubtitle} numberOfLines={2}>{t('weListeningSub')}</Text>
        </View>
        <Ionicons name="chevron-forward" size={16} color="rgba(255,255,255,0.9)" />
      </LinearGradient>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: space.lg,
    paddingTop: space.sm,
    paddingBottom: space.md,
    gap: space.md,
  },
  title: { fontSize: 32, fontWeight: '700' },
  subtitle: { fontSize: 14, fontWeight: '500', marginTop: 2 },
  searchWrap: { paddingHorizontal: space.lg, paddingBottom: space.md },
  searchField: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  searchInput: { flex: 1, fontSize: 16 },
  rowWrap: { borderLeftWidth: 1, borderRightWidth: 1 },
  swipeDelete: { justifyContent: 'center', alignItems: 'center', width: 72 },
  cardTop: {
    height: 6,
    borderTopLeftRadius: radius.card,
    borderTopRightRadius: radius.card,
    borderWidth: 1,
    borderBottomWidth: 0,
  },
  cardBottom: {
    height: 6,
    borderBottomLeftRadius: radius.card,
    borderBottomRightRadius: radius.card,
    borderWidth: 1,
    borderTopWidth: 0,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 14,
  },
  rowBody: { flex: 1, justifyContent: 'center', gap: 4 },
  rowTitleLine: { flexDirection: 'row', alignItems: 'center' },
  rowName: { fontSize: 16, fontWeight: '600', flexShrink: 1 },
  rowPreview: { fontSize: 14 },
  rowTrailing: { alignItems: 'flex-end', gap: 8, minWidth: 44 },
  rowTime: { fontSize: 12, fontWeight: '500' },
  unreadBadge: {
    minWidth: 22,
    height: 22,
    borderRadius: 11,
    paddingHorizontal: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  unreadText: { color: '#fff', fontSize: 12, fontWeight: '700' },
  emptyContainer: { flexGrow: 1, paddingHorizontal: space.lg },
  banner: {
    flexDirection: 'row', alignItems: 'center', gap: 14,
    borderRadius: radius.card, padding: 16,
  },
  bannerIcon: {
    width: 46, height: 46, borderRadius: 14, alignItems: 'center', justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.18)',
  },
  bannerTitle: { color: '#fff', fontSize: 17, fontWeight: '700' },
  bannerSubtitle: { color: 'rgba(255,255,255,0.9)', fontSize: 13, fontWeight: '500', marginTop: 3 },
});
