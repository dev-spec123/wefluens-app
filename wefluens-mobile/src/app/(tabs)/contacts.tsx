import { Ionicons } from '@expo/vector-icons';
import { type Href, useFocusEffect, useRouter } from 'expo-router';
import { pinyin } from 'pinyin-pro';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Alert, Pressable, RefreshControl, SectionList, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, EmptyState, RoundIconButton } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { getRemarks } from '@/lib/friendPrefs';
import { useI18n } from '@/lib/i18n';
import { radius, space, useTheme } from '@/lib/theme';
import type { Contact, FriendRequest } from '@/lib/types';

/** First A-Z letter of a name via pinyin (Chinese → initial), else '#'. */
function sectionLetter(name: string): string {
  const first = pinyin(name, { pattern: 'first', toneType: 'none' })[0]?.toUpperCase() ?? '';
  return /^[A-Z]$/.test(first) ? first : '#';
}

interface ContactSection {
  title: string;
  data: Contact[];
}

export default function ContactsScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const {
    contacts, friendRequests, loadingContacts, refreshContacts,
    friendAcceptedNames, acknowledgeFriendAccepted,
  } = useAppData();

  // Ids of requests currently being accepted/declined (to disable buttons).
  const [busyIds, setBusyIds] = useState<Set<string>>(new Set());
  const [query, setQuery] = useState('');
  const [remarks, setRemarks] = useState<Record<string, string>>({});

  // On focus: reload remarks AND refresh contacts + friend requests (silently),
  // so new requests appear and resolved ones disappear without a manual pull.
  useFocusEffect(
    useCallback(() => {
      let active = true;
      getRemarks().then((m) => { if (active) setRemarks(m); });
      void refreshContacts(true);
      return () => { active = false; };
    }, [refreshContacts]),
  );

  // Surface "X accepted your friend request" once, then mark it seen.
  useEffect(() => {
    if (friendAcceptedNames.length === 0) return;
    Alert.alert(t('friendAcceptedTitle'), `${friendAcceptedNames.join('、')} ${t('friendAcceptedBody')}`);
    void acknowledgeFriendAccepted();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [friendAcceptedNames]);

  // Resolve the display name: remark overrides the profile name.
  const displayName = useCallback(
    (contact: Contact) => remarks[contact.id]?.trim() || contact.name,
    [remarks],
  );

  // Filter (name / remark / handle) then group into A-Z sections, '#' last.
  const sections = useMemo<ContactSection[]>(() => {
    const q = query.trim().toLowerCase();
    const filtered = q
      ? contacts.filter((ct) => {
        const remark = remarks[ct.id]?.toLowerCase() ?? '';
        return ct.name.toLowerCase().includes(q)
          || remark.includes(q)
          || ct.handle.toLowerCase().includes(q);
      })
      : contacts;

    const groups = new Map<string, Contact[]>();
    for (const ct of filtered) {
      const letter = sectionLetter(displayName(ct));
      const bucket = groups.get(letter);
      if (bucket) bucket.push(ct);
      else groups.set(letter, [ct]);
    }

    return Array.from(groups.entries())
      .sort(([a], [b]) => {
        if (a === '#') return 1;
        if (b === '#') return -1;
        return a.localeCompare(b);
      })
      .map(([title, data]) => ({
        title,
        data: data.sort((x, y) => displayName(x).localeCompare(displayName(y))),
      }));
  }, [contacts, remarks, query, displayName]);

  async function respond(req: FriendRequest, accept: boolean) {
    if (busyIds.has(req.id)) return;
    setBusyIds((prev) => new Set(prev).add(req.id));
    try {
      await api.respondFriendRequest(req.id, accept);
      await refreshContacts();
    } catch {
      Alert.alert(t('addFriendError'));
    } finally {
      setBusyIds((prev) => {
        const next = new Set(prev);
        next.delete(req.id);
        return next;
      });
    }
  }

  function openContact(contact: Contact) {
    router.push({
      pathname: '/contact/[id]',
      params: {
        id: contact.id,
        name: contact.name,
        handle: contact.handle,
        role: contact.role,
        followers: contact.followers,
        avatarUrl: contact.avatarUrl ?? '',
      },
    });
  }

  function renderContact({ item }: { item: Contact }) {
    const name = displayName(item);
    return (
      <View style={{ backgroundColor: c.card }}>
        <Pressable
          onPress={() => openContact(item)}
          style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : c.card }]}
        >
          <Avatar
            colors={item.avatarColors}
            name={name}
            imageUrl={item.avatarUrl}
            size={50}
            online={item.isOnline}
          />
          <View style={styles.rowBody}>
            <Text style={[styles.rowName, { color: c.ink }]} numberOfLines={1}>
              {name}
            </Text>
            {item.handle ? (
              <Text style={[styles.rowSub, { color: c.inkSecondary }]} numberOfLines={1}>
                {item.handle}
              </Text>
            ) : null}
            {item.role ? (
              <Text style={[styles.rowSub, { color: c.inkTertiary }]} numberOfLines={1}>
                {item.role}
              </Text>
            ) : null}
          </View>
          <Ionicons name="chevron-forward" size={18} color={c.inkTertiary} />
        </Pressable>
        <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: 78 }} />
      </View>
    );
  }

  function renderRequest(req: FriendRequest, index: number) {
    const isLast = index === friendRequests.length - 1;
    const busy = busyIds.has(req.id);
    return (
      <View key={req.id} style={[styles.rowWrap, { backgroundColor: c.card, borderColor: c.hairline }]}>
        <View style={styles.reqRow}>
          <Avatar colors={req.avatarColors} name={req.name} size={50} />
          <View style={styles.rowBody}>
            <Text style={[styles.rowName, { color: c.ink }]} numberOfLines={1}>
              {req.name}
            </Text>
            <Text style={[styles.rowSub, { color: c.inkSecondary }]} numberOfLines={2}>
              {req.requestMessage}
            </Text>
          </View>
        </View>
        <View style={styles.reqActions}>
          {busy ? (
            <ActivityIndicator color={c.coral} />
          ) : (
            <>
              <Pressable
                onPress={() => respond(req, false)}
                style={[styles.declineBtn, { borderColor: c.hairline, backgroundColor: c.cardSubtle }]}
              >
                <Text style={[styles.declineText, { color: c.inkSecondary }]}>{t('friendRequestDecline')}</Text>
              </Pressable>
              <Pressable
                onPress={() => respond(req, true)}
                style={[styles.acceptBtn, { backgroundColor: c.coral }]}
              >
                <Text style={styles.acceptText}>{t('friendRequestAccept')}</Text>
              </Pressable>
            </>
          )}
        </View>
        {!isLast ? (
          <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline }} />
        ) : null}
      </View>
    );
  }

  const header = (
    <>
      <View style={[styles.search, { backgroundColor: c.card, borderColor: c.hairline }]}>
        <Ionicons name="search" size={16} color={c.inkSecondary} style={{ marginRight: 8 }} />
        <TextInput
          value={query}
          onChangeText={setQuery}
          placeholder={t('contactsSearch')}
          placeholderTextColor={c.inkTertiary}
          style={[styles.searchInput, { color: c.ink }]}
          autoCapitalize="none"
          autoCorrect={false}
          returnKeyType="search"
          clearButtonMode="while-editing"
        />
        {query ? (
          <Pressable onPress={() => setQuery('')} hitSlop={8}>
            <Ionicons name="close-circle" size={16} color={c.inkTertiary} />
          </Pressable>
        ) : null}
      </View>

      {friendRequests.length > 0 ? (
        <View style={styles.section}>
          <Text style={[styles.sectionLabel, { color: c.inkTertiary }]}>
            {t('contactsNewFriends').toUpperCase()}
          </Text>
          <View style={[styles.cardTop, { backgroundColor: c.card, borderColor: c.hairline }]} />
          {friendRequests.map((req, i) => renderRequest(req, i))}
          <View style={[styles.cardBottom, { backgroundColor: c.card, borderColor: c.hairline }]} />
        </View>
      ) : null}
    </>
  );

  const hasRows = sections.length > 0 || friendRequests.length > 0;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <View style={styles.headerBar}>
        <View style={{ flex: 1 }}>
          <Text style={[styles.title, { color: c.ink }]}>{t('contactsTitle')}</Text>
          <Text style={[styles.subtitle, { color: c.inkSecondary }]}>
            {`${contacts.length} ${contacts.length === 1 ? 'contact' : 'contacts'}`}
          </Text>
        </View>
        <View style={{ flexDirection: 'row', gap: 8 }}>
          {/* '/top-talent' & '/brands-directory' are new routes; cast until typegen runs. */}
          <RoundIconButton icon="star-outline" onPress={() => router.push('/top-talent' as Href)} />
          <RoundIconButton icon="briefcase-outline" onPress={() => router.push('/brands-directory' as Href)} />
          <RoundIconButton icon="person-add" onPress={() => router.push('/add-friend')} />
        </View>
      </View>

      <SectionList
        sections={sections}
        keyExtractor={(item) => item.id}
        renderItem={renderContact}
        renderSectionHeader={({ section }) => (
          <View style={[styles.sectionHeader, { backgroundColor: c.paper }]}>
            <Text style={[styles.sectionHeaderText, { color: c.inkSecondary }]}>{section.title}</Text>
          </View>
        )}
        stickySectionHeadersEnabled
        ListHeaderComponent={header}
        ListEmptyComponent={
          friendRequests.length === 0 ? (
            query ? (
              <EmptyState icon="search-outline" title={t('chatsEmpty')} />
            ) : (
              <EmptyState
                icon="people-outline"
                title="No contacts yet"
                subtitle="Add friends to start connecting."
              />
            )
          ) : null
        }
        contentContainerStyle={
          !hasRows
            ? styles.emptyContainer
            : { paddingHorizontal: space.lg, paddingTop: space.xs, paddingBottom: space.xxl }
        }
        refreshControl={
          <RefreshControl
            refreshing={loadingContacts}
            onRefresh={refreshContacts}
            tintColor={c.coral}
          />
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  headerBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: space.lg,
    paddingTop: space.sm,
    paddingBottom: space.md,
    gap: space.md,
  },
  title: { fontSize: 32, fontWeight: '700' },
  subtitle: { fontSize: 14, fontWeight: '500', marginTop: 2 },

  search: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: space.lg,
  },
  searchInput: { flex: 1, fontSize: 16, padding: 0 },

  section: { marginBottom: space.lg },
  sectionLabel: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
    marginBottom: space.sm,
    marginLeft: space.xs,
  },

  sectionHeader: { paddingVertical: 4, marginLeft: space.xs },
  sectionHeaderText: { fontSize: 13, fontWeight: '700' },

  rowWrap: { borderLeftWidth: 1, borderRightWidth: 1 },
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
  rowBody: { flex: 1, justifyContent: 'center', gap: 3 },
  rowName: { fontSize: 16, fontWeight: '600' },
  rowSub: { fontSize: 13 },

  reqRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingTop: 12,
    gap: 14,
  },
  reqActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    minHeight: 36,
  },
  declineBtn: {
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingVertical: 8,
    paddingHorizontal: 18,
  },
  declineText: { fontSize: 14, fontWeight: '600' },
  acceptBtn: {
    borderRadius: radius.pill,
    paddingVertical: 8,
    paddingHorizontal: 22,
  },
  acceptText: { color: '#fff', fontSize: 14, fontWeight: '600' },

  emptyContainer: { flexGrow: 1, paddingHorizontal: space.lg },
});
