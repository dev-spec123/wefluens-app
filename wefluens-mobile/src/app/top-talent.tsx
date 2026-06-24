import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Card, Divider, NavBar } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, gradients, radius, useTheme } from '@/lib/theme';
import type { SearchUserResult } from '@/lib/types';

type Relationship = SearchUserResult['relationship'];

/**
 * Top Talent — the opt-in creator directory (mirrors the Swift TopTalentView).
 * Empty search → the followers-ranked directory via `loadTopTalent`. Typing 2+
 * chars → live `searchUsers` (so anyone is findable by handle/name even if not
 * opted in). Each row offers Add / Pending / Friends / Accept like Add Friend.
 */
export default function TopTalent() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { blockedIds, refreshContacts } = useAppData();

  const [directory, setDirectory] = useState<SearchUserResult[]>([]);
  const [loadingDir, setLoadingDir] = useState(true);
  const [loadFailed, setLoadFailed] = useState(false);

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchUserResult[]>([]);
  const [searching, setSearching] = useState(false);

  // Per-user relationship overrides applied immediately after an action.
  const [overrides, setOverrides] = useState<Record<string, Relationship>>({});
  const [acting, setActing] = useState<Set<string>>(new Set());

  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reqIdRef = useRef(0);

  const loadDirectory = useCallback(async () => {
    setLoadFailed(false);
    try {
      setDirectory(await api.loadTopTalent(blockedIds));
    } catch {
      setDirectory([]);
      setLoadFailed(true);
    } finally {
      setLoadingDir(false);
    }
  }, [blockedIds]);

  useEffect(() => { void loadDirectory(); }, [loadDirectory]);

  const runSearch = useCallback(async (raw: string) => {
    const trimmed = raw.trim();
    if (trimmed.length < 2) { setResults([]); setSearching(false); return; }
    const reqId = ++reqIdRef.current;
    setSearching(true);
    try {
      const res = await api.searchUsers(trimmed, blockedIds);
      if (reqId !== reqIdRef.current) return; // a newer search superseded this one
      setResults(res);
    } catch {
      if (reqId !== reqIdRef.current) return;
      setResults([]);
    } finally {
      if (reqId === reqIdRef.current) setSearching(false);
    }
  }, [blockedIds]);

  // Debounced search on text change.
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    const trimmed = query.trim();
    if (trimmed.length < 2) { setResults([]); setSearching(false); return; }
    debounceRef.current = setTimeout(() => { void runSearch(query); }, 350);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [query, runSearch]);

  function relationshipFor(user: SearchUserResult): Relationship {
    return overrides[user.id] ?? user.relationship;
  }
  function subtitleFor(user: SearchUserResult): string {
    const base = [user.handle, user.role].filter((s) => s && s.length > 0).join(' · ');
    if (!user.followers) return base;
    return base ? `${base} · ${user.followers}` : user.followers;
  }
  function setOverride(id: string, value: Relationship) {
    setOverrides((prev) => ({ ...prev, [id]: value }));
  }
  function startActing(id: string) { setActing((prev) => new Set(prev).add(id)); }
  function stopActing(id: string) {
    setActing((prev) => { const next = new Set(prev); next.delete(id); return next; });
  }

  async function addFriend(user: SearchUserResult) {
    if (acting.has(user.id)) return;
    startActing(user.id);
    try {
      const status = await api.sendFriendRequest(user.id, t('friendRequestMessage'));
      switch (status) {
        case 'sent': setOverride(user.id, 'request_sent'); Alert.alert(t('addFriendSent')); break;
        case 'already_sent': setOverride(user.id, 'request_sent'); break;
        case 'already_friends': setOverride(user.id, 'friends'); break;
        case 'incoming_exists': setOverride(user.id, 'request_received'); break;
        default: setOverride(user.id, 'request_sent'); break;
      }
      await refreshContacts().catch(() => {});
    } catch {
      Alert.alert(t('addFriendError'));
    } finally {
      stopActing(user.id);
    }
  }

  async function acceptIncoming(user: SearchUserResult) {
    if (!user.incoming_request_id || acting.has(user.id)) return;
    startActing(user.id);
    try {
      const status = await api.respondFriendRequest(user.incoming_request_id, true);
      if (status === 'accepted') setOverride(user.id, 'friends');
      await refreshContacts().catch(() => {});
    } catch {
      Alert.alert(t('addFriendError'));
    } finally {
      stopActing(user.id);
    }
  }

  function clearSearch() {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    reqIdRef.current++;
    setQuery('');
    setResults([]);
    setSearching(false);
  }

  const trimmed = query.trim();
  const isSearchActive = trimmed.length >= 2;
  const displayed = isSearchActive ? results : directory;

  function renderActionButton(user: SearchUserResult) {
    if (acting.has(user.id)) {
      return <View style={styles.pillSlot}><ActivityIndicator color={c.coral} /></View>;
    }
    const rel = relationshipFor(user);
    if (rel === 'friends') return <Pill text={t('addFriendFriends')} icon="checkmark" filled={false} disabled />;
    if (rel === 'request_sent') return <Pill text={t('addFriendRequested')} icon="time-outline" filled={false} disabled />;
    if (rel === 'request_received' && user.incoming_request_id) {
      return <Pill text={t('friendRequestAccept')} icon="checkmark" filled onPress={() => acceptIncoming(user)} />;
    }
    return <Pill text={t('addFriendAdd')} icon="person-add" filled onPress={() => addFriend(user)} />;
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('contactsTopTalent')} onBack={() => router.back()} />

      <View style={{ flex: 1, paddingHorizontal: 18, paddingTop: 10 }}>
        <View style={[styles.searchField, { backgroundColor: c.card, borderColor: c.hairline }]}>
          <Ionicons name="search" size={16} color={c.inkSecondary} style={{ marginRight: 10 }} />
          <TextInput
            value={query}
            onChangeText={setQuery}
            onSubmitEditing={() => void runSearch(query)}
            placeholder={t('talentSearch')}
            placeholderTextColor={c.inkTertiary}
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="search"
            style={{ flex: 1, fontSize: 16, color: c.ink }}
          />
          {query.length > 0 && (
            <Pressable onPress={clearSearch} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={c.inkTertiary} />
            </Pressable>
          )}
        </View>

        {loadingDir && !isSearchActive ? (
          <View style={styles.centered}><ActivityIndicator color={c.coral} size="large" /></View>
        ) : isSearchActive && searching && results.length === 0 ? (
          <View style={styles.centered}>
            <ActivityIndicator color={c.coral} size="large" />
            <Text style={[styles.centeredText, { color: c.inkSecondary }]}>{t('addFriendSearching')}</Text>
          </View>
        ) : displayed.length === 0 ? (
          <CenteredState
            icon={loadFailed && !isSearchActive ? 'cloud-offline' : isSearchActive ? 'search' : 'people'}
            title={loadFailed && !isSearchActive ? t('addFriendError') : isSearchActive ? t('addFriendNoResults') : t('talentEmpty')}
            subtitle={!loadFailed && !isSearchActive ? t('talentOptInHint') : undefined}
          />
        ) : (
          <ScrollView contentContainerStyle={{ paddingTop: 16, paddingBottom: 24 }} keyboardShouldPersistTaps="handled">
            <Card style={{ paddingVertical: 6 }}>
              {displayed.map((user, index) => (
                <View key={user.id}>
                  <View style={styles.row}>
                    <Avatar colors={avatarGradient(user.id)} name={user.name} imageUrl={user.avatar_url} size={48} />
                    <View style={{ flex: 1, marginLeft: 14 }}>
                      <Text style={[styles.name, { color: c.ink }]} numberOfLines={1}>
                        {user.name && user.name.length > 0 ? user.name : user.handle}
                      </Text>
                      <Text style={[styles.sub, { color: c.inkSecondary }]} numberOfLines={1}>{subtitleFor(user)}</Text>
                    </View>
                    {renderActionButton(user)}
                  </View>
                  {index < displayed.length - 1 && <Divider inset={76} />}
                </View>
              ))}
            </Card>
          </ScrollView>
        )}
      </View>
    </SafeAreaView>
  );
}

function Pill({
  text, icon, filled, disabled, onPress,
}: {
  text: string;
  icon: keyof typeof Ionicons.glyphMap;
  filled: boolean;
  disabled?: boolean;
  onPress?: () => void;
}) {
  const c = useTheme();
  const content = (
    <>
      <Ionicons name={icon} size={12} color={filled ? '#fff' : c.inkSecondary} />
      <Text style={[styles.pillText, { color: filled ? '#fff' : c.inkSecondary }]}>{text}</Text>
    </>
  );

  if (filled) {
    return (
      <Pressable onPress={onPress} disabled={disabled}>
        <LinearGradient
          colors={gradients.sunset}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.pill, { opacity: disabled ? 0.65 : 1 }]}
        >
          {content}
        </LinearGradient>
      </Pressable>
    );
  }

  return (
    <View style={[styles.pill, { backgroundColor: c.cardSubtle, borderWidth: 1, borderColor: c.hairline, opacity: disabled ? 0.65 : 1 }]}>
      {content}
    </View>
  );
}

function CenteredState({ icon, title, subtitle }: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
}) {
  const c = useTheme();
  return (
    <View style={styles.centered}>
      <View style={[styles.iconCircle, { backgroundColor: c.coral + '1A' }]}>
        <Ionicons name={icon} size={32} color={c.coral} />
      </View>
      <Text style={[styles.centeredText, { color: c.inkSecondary }]}>{title}</Text>
      {subtitle ? <Text style={[styles.centeredSub, { color: c.inkTertiary }]}>{subtitle}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  searchField: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 13,
  },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 24, gap: 12 },
  centeredText: { fontSize: 15, fontWeight: '500', textAlign: 'center' },
  centeredSub: { fontSize: 13, textAlign: 'center', lineHeight: 18 },
  iconCircle: { width: 76, height: 76, borderRadius: 38, alignItems: 'center', justifyContent: 'center' },
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 11 },
  name: { fontSize: 16, fontWeight: '600' },
  sub: { fontSize: 13, marginTop: 3 },
  pillSlot: { width: 96, height: 36, alignItems: 'center', justifyContent: 'center' },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    height: 36,
    paddingHorizontal: 14,
    borderRadius: radius.pill,
  },
  pillText: { fontSize: 13, fontWeight: '600' },
});
