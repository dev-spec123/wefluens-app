/**
 * App data — the shared, live state behind the tabs: the chat inbox (with a
 * realtime subscription), contacts + friend requests, discover, and the set of
 * blocked users that filters everything. Mirrors the Swift AppDataService state.
 */
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';

import * as api from '@/lib/api';
import { getMutedSet, getPinnedSet } from '@/lib/convPrefs';
import { supabase } from '@/lib/supabase';
import { getCachedMessages, getMemCachedMessages, setCachedMessages } from '@/lib/messageCache';
import type { Brand, Campaign, Contact, Conversation, FriendRequest } from '@/lib/types';
import { useAuth } from './AuthContext';

interface AppDataValue {
  blockedIds: Set<string>;
  mutedIds: Set<string>;
  pinnedIds: Set<string>;
  conversations: Conversation[];
  contacts: Contact[];
  friendRequests: FriendRequest[];
  brands: Brand[];
  campaigns: Campaign[];
  unreadTotal: number;
  loadingConversations: boolean;
  loadingContacts: boolean;
  refreshConversations: (silent?: boolean) => Promise<void>;
  refreshContacts: (silent?: boolean) => Promise<void>;
  /** Names of people who accepted a request I sent, not yet acknowledged. */
  friendAcceptedNames: string[];
  acknowledgeFriendAccepted: () => Promise<void>;
  refreshDiscover: () => Promise<void>;
  block: (otherId: string) => Promise<void>;
  unblock: (otherId: string) => Promise<void>;
}

const AppDataContext = createContext<AppDataValue | undefined>(undefined);

export function AppDataProvider({ children }: { children: React.ReactNode }) {
  const { userId, profile } = useAuth();
  const [blockedIds, setBlockedIds] = useState<Set<string>>(new Set());
  const [mutedIds, setMutedIds] = useState<Set<string>>(new Set());
  const [pinnedIds, setPinnedIds] = useState<Set<string>>(new Set());
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [friendRequests, setFriendRequests] = useState<FriendRequest[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loadingConversations, setLoadingConversations] = useState(false);
  const [loadingContacts, setLoadingContacts] = useState(false);
  const [friendAcceptedNames, setFriendAcceptedNames] = useState<string[]>([]);
  const blockedRef = useRef(blockedIds);
  blockedRef.current = blockedIds;
  const myNameRef = useRef('');
  myNameRef.current = profile?.name ?? '';

  const refreshConversations = useCallback(async (silent = false) => {
    if (!userId) return;
    if (!silent) setLoadingConversations(true);
    try {
      const [convs, muted, pinned] = await Promise.all([
        api.loadConversations(userId, blockedRef.current, myNameRef.current),
        getMutedSet(),
        getPinnedSet(),
      ]);
      setConversations(convs);
      setMutedIds(muted);
      setPinnedIds(pinned);
      if (userId) void setCachedMessages(`conv.${userId}`, convs);
    } finally {
      if (!silent) setLoadingConversations(false);
    }
  }, [userId]);

  const refreshContacts = useCallback(async (silent = false) => {
    if (!userId) return;
    if (!silent) setLoadingContacts(true);
    try {
      const blocks = await api.loadBlocks(userId);
      setBlockedIds(blocks);
      blockedRef.current = blocks;
      const [c, r, accepted] = await Promise.all([
        api.loadContacts(userId, blocks),
        api.loadFriendRequests(userId),
        api.loadAcceptedFriendNames(userId).catch(() => [] as string[]),
      ]);
      setContacts(c);
      setFriendRequests(r);
      setFriendAcceptedNames(accepted);
    } finally {
      if (!silent) setLoadingContacts(false);
    }
  }, [userId]);

  const acknowledgeFriendAccepted = useCallback(async () => {
    if (!userId) return;
    setFriendAcceptedNames([]);
    await api.markFriendAcceptancesSeen(userId).catch(() => {});
  }, [userId]);

  const refreshDiscover = useCallback(async () => {
    const { brands: b, campaigns: c } = await api.loadDiscover();
    setBrands(b);
    setCampaigns(c);
  }, []);

  const block = useCallback(async (otherId: string) => {
    if (!userId) return;
    await api.blockUser(userId, otherId);
    const next = new Set(blockedRef.current);
    next.add(otherId);
    setBlockedIds(next);
    blockedRef.current = next;
    await Promise.all([refreshConversations(), refreshContacts()]);
  }, [userId, refreshConversations, refreshContacts]);

  const unblock = useCallback(async (otherId: string) => {
    if (!userId) return;
    await api.unblockUser(userId, otherId);
    const next = new Set(blockedRef.current);
    next.delete(otherId);
    setBlockedIds(next);
    blockedRef.current = next;
    await Promise.all([refreshConversations(), refreshContacts()]);
  }, [userId, refreshConversations, refreshContacts]);

  // Initial load + realtime inbox subscription.
  useEffect(() => {
    if (!userId) {
      setConversations([]); setContacts([]); setFriendRequests([]); setBlockedIds(new Set());
      return;
    }
    // Show cached conversations instantly so the chats list doesn't spin on every
    // open; the refresh below then updates it silently in the background.
    const memConv = getMemCachedMessages<Conversation>(`conv.${userId}`);
    if (memConv && memConv.length) {
      setConversations(memConv);
    } else {
      getCachedMessages<Conversation>(`conv.${userId}`).then((cached) => {
        if (cached && cached.length) setConversations((prev) => (prev.length ? prev : cached));
      });
    }

    (async () => {
      const blocks = await api.loadBlocks(userId);
      setBlockedIds(blocks);
      blockedRef.current = blocks;
      await Promise.all([refreshConversations(true), refreshContacts(), refreshDiscover()]);
    })();

    const channel = supabase
      .channel(`inbox-${userId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dm_messages' }, () => { void refreshConversations(true); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'group_messages' }, () => { void refreshConversations(true); })
      // Incoming friend requests + new/removed friendships → live contacts.
      .on('postgres_changes', { event: '*', schema: 'public', table: 'friend_requests' }, () => { void refreshContacts(true); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'friendships' }, () => { void refreshContacts(true); })
      .subscribe();

    return () => { void supabase.removeChannel(channel); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  const unreadTotal = useMemo(
    () => conversations.reduce((s, c) => s + (mutedIds.has(c.id) ? 0 : c.unread), 0),
    [conversations, mutedIds],
  );

  const value = useMemo<AppDataValue>(() => ({
    blockedIds, mutedIds, pinnedIds, conversations, contacts, friendRequests, brands, campaigns, unreadTotal,
    loadingConversations, loadingContacts, friendAcceptedNames, acknowledgeFriendAccepted,
    refreshConversations, refreshContacts, refreshDiscover, block, unblock,
  }), [blockedIds, mutedIds, pinnedIds, conversations, contacts, friendRequests, brands, campaigns, unreadTotal,
    loadingConversations, loadingContacts, friendAcceptedNames, acknowledgeFriendAccepted,
    refreshConversations, refreshContacts, refreshDiscover, block, unblock]);

  return <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>;
}

export function useAppData(): AppDataValue {
  const ctx = useContext(AppDataContext);
  if (!ctx) throw new Error('useAppData must be used within an AppDataProvider');
  return ctx;
}
