/**
 * Event participant roster — who signed up for one event, newest first. Reached
 * from admin/events.tsx. Admin-only: the RPC is is_admin-gated server-side, so
 * influencers only ever see the aggregate count on Discover.
 * Mirrors the Swift EventSignupsView.
 */
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, FlatList, RefreshControl, StyleSheet, Text, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Card, EmptyState, NavBar } from '@/components/ui';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, useTheme } from '@/lib/theme';
import type { Event, EventSignup } from '@/lib/types';

/** "12 Jun" — the compact signed-up-on stamp on each row. */
function shortDay(raw: string | null): string {
  if (!raw) return '';
  const d = new Date(raw);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export default function EventSignups() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();

  const [signups, setSignups] = useState<EventSignup[]>([]);
  const [event, setEvent] = useState<Event | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    try {
      // The roster plus the event itself, so the header can show the fill level.
      // Both come from admin reads, so drafts resolve here too.
      const [rows, events] = await Promise.all([
        api.loadEventSignups(id),
        api.loadEventsForAdmin().catch(() => [] as Event[]),
      ]);
      setSignups(rows);
      setEvent(events.find((e) => e.id === id) ?? null);
    } catch {
      notify(t('adminLoadError'));
    }
  }, [id, t]);

  useEffect(() => {
    (async () => {
      setLoading(true);
      await load();
      setLoading(false);
    })();
  }, [load]);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  function displayName(p: EventSignup): string {
    if (p.name) return p.name;
    if (p.handle) return p.handle;
    return p.email || t('adminSignupUnnamed');
  }

  /** "@handle · role" when we have them, else the email — whatever identifies
   *  the participant for an admin who needs to reach them. */
  function secondaryLine(p: EventSignup): string {
    const parts = [p.handle, p.role].filter(Boolean);
    return parts.length ? parts.join(' · ') : p.email;
  }

  function capacityLine(): string {
    if (!event) return `${signups.length}`;
    if (event.capacity != null) {
      return `${signups.length} / ${event.capacity} ${t('adminSpotsTaken')}`;
    }
    return `${signups.length} ${t('adminSignedUpCount')} · ${t('eventDetailOpenToAll')}`;
  }

  function renderRow({ item }: { item: EventSignup }) {
    return (
      <View style={{ paddingHorizontal: 16, paddingBottom: 8 }}>
        <Card>
          <View style={styles.row}>
            <Avatar
              colors={avatarGradient(item.id)}
              name={displayName(item)}
              imageUrl={item.avatarUrl}
              size={44}
            />
            <View style={{ flex: 1 }}>
              <Text style={{ color: c.ink, fontSize: 15, fontWeight: '600' }} numberOfLines={1}>
                {displayName(item)}
              </Text>
              <Text style={{ color: c.inkSecondary, fontSize: 12, marginTop: 2 }} numberOfLines={1}>
                {secondaryLine(item)}
              </Text>
            </View>
            {item.signedUpAt ? (
              <Text style={{ color: c.inkTertiary, fontSize: 11, fontWeight: '500' }}>
                {shortDay(item.signedUpAt)}
              </Text>
            ) : null}
          </View>
        </Card>
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('adminEventSignups')} onBack={() => router.back()} />
      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <FlatList
          data={signups}
          keyExtractor={(p) => p.id}
          renderItem={renderRow}
          ListHeaderComponent={
            <View style={styles.header}>
              <Text style={[styles.headerTitle, { color: c.ink }]} numberOfLines={2}>
                {event?.title ?? ''}
              </Text>
              <Text style={[styles.headerSub, { color: c.inkSecondary }]}>{capacityLine()}</Text>
            </View>
          }
          ListEmptyComponent={
            <EmptyState
              icon="people-outline"
              title={t('adminNoSignups')}
              subtitle={event && !event.published ? t('adminNoSignupsDraft') : undefined}
            />
          }
          contentContainerStyle={{ paddingBottom: 24, flexGrow: 1 }}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />
          }
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { paddingHorizontal: 20, paddingTop: 8, paddingBottom: 14 },
  headerTitle: { fontSize: 20, fontWeight: '700' },
  headerSub: { fontSize: 13, fontWeight: '500', marginTop: 4 },
  row: { flexDirection: 'row', alignItems: 'center', padding: 12, gap: 12 },
});
