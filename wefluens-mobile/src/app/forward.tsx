import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator, LayoutAnimation, Platform, Pressable, ScrollView, StyleSheet, Text,
  TextInput, UIManager, Vibration, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Divider, EmptyState, NavBar } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

// Enable LayoutAnimation on Android (no-op on iOS / web where it's already on).
if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

/** Mirror of the Swift withAnimation(.spring) + UISelectionFeedbackGenerator. */
function animateSelection() {
  LayoutAnimation.configureNext(LayoutAnimation.create(180, 'easeInEaseOut', 'opacity'));
  Vibration.vibrate(10);
}

export default function Forward() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { contacts, conversations, loadingContacts, loadingConversations } = useAppData();
  const params = useLocalSearchParams<{ kind?: string; messageId?: string; messageIds?: string }>();
  const sourceKind = params.kind === 'group' ? 'group' : 'dm';
  const messageIds = (params.messageIds ?? params.messageId ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  const groups = useMemo(() => conversations.filter((cv) => cv.isGroup), [conversations]);
  const [search, setSearch] = useState('');
  const [friendIds, setFriendIds] = useState<Set<string>>(new Set());
  const [groupIds, setGroupIds] = useState<Set<string>>(new Set());
  const [sending, setSending] = useState(false);

  const q = search.trim().toLowerCase();
  const shownFriends = useMemo(
    () =>
      q
        ? contacts.filter(
            (ct) =>
              ct.name.toLowerCase().includes(q) ||
              ct.handle.toLowerCase().includes(q) ||
              ct.role.toLowerCase().includes(q),
          )
        : contacts,
    [contacts, q],
  );
  const shownGroups = useMemo(
    () => (q ? groups.filter((g) => g.name.toLowerCase().includes(q)) : groups),
    [groups, q],
  );

  const selectedFriends = useMemo(() => contacts.filter((ct) => friendIds.has(ct.id)), [contacts, friendIds]);
  const selectedGroups = useMemo(() => groups.filter((g) => groupIds.has(g.id)), [groups, groupIds]);

  const total = friendIds.size + groupIds.size;
  const canSend = total > 0 && !sending && messageIds.length > 0;

  function toggle(set: Set<string>, setSet: (s: Set<string>) => void, id: string) {
    animateSelection();
    const next = new Set(set);
    if (next.has(id)) next.delete(id); else next.add(id);
    setSet(next);
  }

  async function send() {
    if (!canSend || messageIds.length === 0) return;
    setSending(true);
    try {
      const friends = Array.from(friendIds);
      const groupsTo = Array.from(groupIds);
      // Forward oldest→newest so they arrive in original order.
      for (const id of messageIds) {
        await api.forwardMessage({ kind: sourceKind, messageId: id }, friends, groupsTo);
      }
      // Success haptic (mirror of UINotificationFeedbackGenerator .success).
      Vibration.vibrate([0, 30, 60, 30]);
      router.back();
    } catch {
      notify(t('forwardTitle'), t('forwardError'));
    } finally {
      setSending(false);
    }
  }

  const empty = contacts.length === 0 && groups.length === 0;
  const loading = loadingContacts || loadingConversations;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar
        title={t('forwardTitle')}
        subtitle={total > 0 ? `${total} ${t('createGroupSelected')}` : undefined}
        onBack={() => router.back()}
        right={
          sending ? (
            <ActivityIndicator color={c.coral} style={{ width: 56 }} />
          ) : (
            <Pressable onPress={send} disabled={!canSend} hitSlop={8}>
              <Text style={{ color: canSend ? c.coral : c.inkTertiary, fontSize: 15, fontWeight: '700' }}>
                {t('forwardSend')}
              </Text>
            </Pressable>
          )
        }
      />

      {total > 0 && (
        <View style={[styles.selectedBar, { backgroundColor: c.coral + (c.scheme === 'dark' ? '1F' : '10') }]}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.selectedBarInner}>
            {selectedFriends.map((ct) => (
              <Chip
                key={`f-${ct.id}`} name={ct.name} colors={ct.avatarColors} imageUrl={ct.avatarUrl}
                onRemove={() => toggle(friendIds, setFriendIds, ct.id)}
              />
            ))}
            {selectedGroups.map((g) => (
              <Chip
                key={`g-${g.id}`} name={g.name} colors={g.avatarColors} imageUrl={g.avatarUrl} group
                onRemove={() => toggle(groupIds, setGroupIds, g.id)}
              />
            ))}
          </ScrollView>
        </View>
      )}

      {empty ? (
        loading ? (
          <View style={styles.loading}>
            <ActivityIndicator color={c.coral} size="large" />
          </View>
        ) : (
          <EmptyState icon="paper-plane-outline" title={t('forwardNoTargets')} />
        )
      ) : (
        <ScrollView contentContainerStyle={{ paddingBottom: 30 }}>
          <View style={[styles.search, { backgroundColor: c.card, borderColor: c.hairline }]}>
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

          {shownFriends.length > 0 && (
            <>
              <Text style={[styles.section, { color: c.inkTertiary }]}>{t('forwardFriends').toUpperCase()}</Text>
              <View style={[styles.card, { backgroundColor: c.card, borderColor: c.hairline }]}>
                {shownFriends.map((ct, i) => (
                  <View key={ct.id}>
                    <Row
                      name={ct.name} subtitle={ct.role.trim() ? ct.role : `@${ct.handle}`}
                      colors={ct.avatarColors} imageUrl={ct.avatarUrl} online={ct.isOnline}
                      selected={friendIds.has(ct.id)} onPress={() => toggle(friendIds, setFriendIds, ct.id)}
                    />
                    {i < shownFriends.length - 1 && <Divider inset={76} />}
                  </View>
                ))}
              </View>
            </>
          )}

          {shownGroups.length > 0 && (
            <>
              <Text style={[styles.section, { color: c.inkTertiary }]}>{t('forwardGroups').toUpperCase()}</Text>
              <View style={[styles.card, { backgroundColor: c.card, borderColor: c.hairline }]}>
                {shownGroups.map((g, i) => (
                  <View key={g.id}>
                    <Row
                      name={g.name} subtitle={`${g.participantCount} ${t('chatDetailGroupMembers')}`}
                      colors={g.avatarColors} imageUrl={g.avatarUrl} group
                      selected={groupIds.has(g.id)} onPress={() => toggle(groupIds, setGroupIds, g.id)}
                    />
                    {i < shownGroups.length - 1 && <Divider inset={76} />}
                  </View>
                ))}
              </View>
            </>
          )}
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

function Chip({
  name, colors, imageUrl, group, onRemove,
}: {
  name: string; colors: [string, string]; imageUrl: string | null; group?: boolean; onRemove: () => void;
}) {
  const c = useTheme();
  return (
    <Pressable onPress={onRemove} style={[styles.chip, { backgroundColor: c.card, borderColor: c.hairline }]}>
      <Avatar colors={colors} name={name} imageUrl={imageUrl} size={28} symbol={group ? 'people' : undefined} />
      <Text style={{ color: c.ink, fontSize: 12, fontWeight: '500', marginHorizontal: 6, maxWidth: 110 }} numberOfLines={1}>
        {name}
      </Text>
      <Ionicons name="close-circle" size={14} color={c.inkTertiary} />
    </Pressable>
  );
}

function Row({
  name, subtitle, colors, imageUrl, group, online, selected, onPress,
}: {
  name: string; subtitle: string; colors: [string, string]; imageUrl: string | null;
  group?: boolean; online?: boolean; selected: boolean; onPress: () => void;
}) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} style={styles.row}>
      <Avatar colors={colors} name={name} imageUrl={imageUrl} size={46} online={online} symbol={group ? 'people' : undefined} />
      <View style={{ flex: 1, marginLeft: 14 }}>
        <Text style={{ color: c.ink, fontSize: 16, fontWeight: '600' }} numberOfLines={1}>{name}</Text>
        {subtitle.length > 0 && (
          <Text style={{ color: c.inkSecondary, fontSize: 13, marginTop: 2 }} numberOfLines={1}>{subtitle}</Text>
        )}
      </View>
      <View style={[styles.check, { borderColor: selected ? c.coral : c.hairline, backgroundColor: selected ? c.coral : 'transparent' }]}>
        {selected && <Ionicons name="checkmark" size={13} color="#fff" />}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  selectedBar: { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: 'transparent' },
  selectedBarInner: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, gap: 10 },
  chip: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.pill, borderWidth: 1,
    paddingLeft: 6, paddingRight: 8, paddingVertical: 6,
  },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  search: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.pill, borderWidth: 1,
    paddingHorizontal: 16, paddingVertical: 12, marginHorizontal: 16, marginTop: 14,
  },
  section: { fontSize: 12, fontWeight: '700', letterSpacing: 1, marginHorizontal: 20, marginTop: 18, marginBottom: 8 },
  card: { marginHorizontal: 16, borderRadius: radius.md, borderWidth: 1, paddingVertical: 4 },
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 10 },
  check: { width: 24, height: 24, borderRadius: 12, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
});
