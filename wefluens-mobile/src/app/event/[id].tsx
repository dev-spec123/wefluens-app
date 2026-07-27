/**
 * Event detail — the published-event counterpart to campaign/[id].tsx, with the
 * sign-up / cancel bar. Unlike the campaign screen (which keeps applied state on
 * device), sign-up state here is server-backed: the RPC is the source of truth,
 * so the same account sees the same state on iOS and RN.
 */
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, EmptyState, GradientButton, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { cancelEventSignup, loadMyEventSignups, signUpForEvent } from '@/lib/api';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';
import type { Event } from '@/lib/types';

/** Map an SF Symbol-ish name from the backend to an Ionicons glyph. */
function iconFor(symbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    calendar: 'calendar', 'calendar.badge.plus': 'calendar',
    sparkles: 'sparkles', 'star.fill': 'star', star: 'star',
    'megaphone.fill': 'megaphone', megaphone: 'megaphone',
    'camera.fill': 'camera', camera: 'camera',
    'gift.fill': 'gift', gift: 'gift',
    'flame.fill': 'flame', flame: 'flame',
    'music.note': 'musical-notes', 'mic.fill': 'mic',
  };
  return map[symbol] ?? 'calendar';
}

/** Long form: "Saturday, 12 July 2026 at 7:00 PM". */
function formatFullDate(raw: string | null, fallback: string): string {
  if (!raw) return fallback;
  const d = new Date(raw);
  if (isNaN(d.getTime())) return fallback;
  return d.toLocaleString(undefined, {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  });
}

export default function EventDetail() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { events, refreshDiscover } = useAppData();
  const { id } = useLocalSearchParams<{ id: string }>();

  const event: Event | undefined = events.find((x) => x.id === id);

  const [signedUp, setSignedUp] = useState(event?.signedUp ?? false);
  const [busy, setBusy] = useState(false);

  // Seed from the row's own flag, then refine against my live signups so leaving
  // and returning stays in sync.
  useEffect(() => {
    let active = true;
    setSignedUp(event?.signedUp ?? false);
    loadMyEventSignups()
      .then((ids) => { if (active && id) setSignedUp(ids.includes(id)); })
      .catch(() => {});
    return () => { active = false; };
  }, [id, event?.signedUp]);

  if (!event) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <Pressable onPress={() => router.back()} style={[styles.backBtn, { top: 8, left: 18, backgroundColor: 'rgba(0,0,0,0.25)' }]}>
          <Ionicons name="chevron-back" size={20} color="#fff" />
        </Pressable>
        <EmptyState icon="calendar-outline" title={t('eventNotFound')} />
      </SafeAreaView>
    );
  }

  // Full only matters when the user isn't already in — their own slot is theirs.
  const isFull = event.spotsLeft != null && event.spotsLeft <= 0 && !signedUp;

  async function signUp() {
    if (busy || isFull || !id) return;
    setBusy(true);
    setSignedUp(true);
    try {
      await signUpForEvent(id);
      await refreshDiscover();
    } catch {
      setSignedUp(false);   // roll back optimistic UI
      notify(t('discoverSignUpFailed'));
    } finally {
      setBusy(false);
    }
  }

  async function cancel() {
    if (busy || !id) return;
    const ok = await confirmAsync(t('eventDetailCancelSignup'), t('eventDetailCancelConfirm'), {
      confirmLabel: t('eventDetailCancelSignup'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    setSignedUp(false);
    try {
      await cancelEventSignup(id);
      await refreshDiscover();
    } catch {
      setSignedUp(true);    // roll back optimistic UI
      notify(t('discoverSignUpFailed'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: c.paper }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 40 }} showsVerticalScrollIndicator={false}>
        {/* Hero — uploaded icon over the gradient, or the oversized glyph default. */}
        <LinearGradient
          colors={event.colors}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.hero}
        >
          {event.iconUrl ? (
            <Image source={{ uri: event.iconUrl }} style={StyleSheet.absoluteFill} contentFit="cover" />
          ) : (
            <Ionicons name={iconFor(event.symbol)} size={120} color="rgba(255,255,255,0.15)" style={styles.heroIcon} />
          )}
          <LinearGradient colors={['transparent', 'rgba(0,0,0,0.35)']} style={StyleSheet.absoluteFill} />
          <SafeAreaView edges={['top']} style={styles.heroContent}>
            <View>
              {event.brand ? <Text style={styles.heroBrand}>{event.brand.toUpperCase()}</Text> : null}
              <Text style={styles.heroTitle}>{event.title}</Text>
            </View>
          </SafeAreaView>
        </LinearGradient>

        {/* Quick stats */}
        <View style={styles.statsRow}>
          <Stat
            icon="calendar-outline"
            value={formatFullDate(event.startsAt, t('eventDetailTBA'))}
            label={t('eventDetailWhen')}
          />
          <Stat
            icon="location-outline"
            value={event.location || t('eventDetailTBA')}
            label={t('eventDetailWhere')}
          />
          <Stat
            icon="people-outline"
            value={event.spotsLeft != null ? String(event.spotsLeft) : t('eventDetailOpenToAll')}
            label={t('eventDetailSpots')}
          />
        </View>

        {/* About */}
        {event.description || event.tags.length > 0 ? (
          <Card style={styles.sectionCard}>
            <Text style={[styles.sectionTitle, { color: c.ink }]}>{t('eventDetailAbout')}</Text>
            {event.description ? (
              <Text style={[styles.aboutText, { color: c.inkSecondary }]}>{event.description}</Text>
            ) : null}
            {event.tags.length > 0 ? (
              <View style={styles.tagsRow}>
                {event.tags.map((tag) => (
                  <TagChip key={tag} text={tag} />
                ))}
              </View>
            ) : null}
          </Card>
        ) : null}
      </ScrollView>

      {/* Sign-up bar */}
      <SafeAreaView edges={['bottom']} style={[styles.signUpBar, { backgroundColor: c.card, borderTopColor: c.hairline }]}>
        <View style={styles.signUpBarInner}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.countValue, { color: c.ink }]}>{event.signupCount}</Text>
            <Text style={[styles.countLabel, { color: c.inkSecondary }]}>{t('discoverParticipants')}</Text>
          </View>
          {signedUp ? (
            <Pressable
              onPress={cancel}
              disabled={busy}
              style={[styles.signedUpBtn, { borderColor: c.coral, backgroundColor: c.coral + '14' }, busy && { opacity: 0.6 }]}
            >
              <Ionicons name="checkmark-circle" size={18} color={c.coral} />
              <Text style={[styles.signedUpText, { color: c.coral }]} numberOfLines={1}>
                {t('eventDetailSignedUp')}
              </Text>
            </Pressable>
          ) : isFull ? (
            // Capacity is enforced server-side; showing it disabled means the user
            // never taps into a guaranteed failure.
            <View style={[styles.fullPill, { backgroundColor: c.inkTertiary + '26' }]}>
              <Text style={[styles.signedUpText, { color: c.inkSecondary }]}>{t('discoverEventFull')}</Text>
            </View>
          ) : (
            <GradientButton
              title={t('eventDetailSignUp')}
              onPress={signUp}
              loading={busy}
              style={styles.signUpButton}
            />
          )}
        </View>
      </SafeAreaView>

      {/* Back button */}
      <SafeAreaView edges={['top']} style={styles.backWrap} pointerEvents="box-none">
        <Pressable onPress={() => router.back()} style={[styles.backBtn, { backgroundColor: 'rgba(0,0,0,0.25)' }]}>
          <Ionicons name="chevron-back" size={20} color="#fff" />
        </Pressable>
      </SafeAreaView>
    </View>
  );
}

function Stat({ icon, value, label }: { icon: keyof typeof Ionicons.glyphMap; value: string; label: string }) {
  const c = useTheme();
  return (
    <View style={[styles.statCard, { backgroundColor: c.card, borderColor: c.hairline }]}>
      <Ionicons name={icon} size={18} color={c.coral} />
      <Text style={[styles.statValue, { color: c.ink }]} numberOfLines={2} adjustsFontSizeToFit minimumFontScale={0.6}>
        {value}
      </Text>
      <Text style={[styles.statLabel, { color: c.inkSecondary }]} numberOfLines={1}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { height: 260, justifyContent: 'flex-end', overflow: 'hidden' },
  heroIcon: { position: 'absolute', right: -10, top: 40 },
  heroContent: { width: '100%' },
  heroBrand: { color: 'rgba(255,255,255,0.85)', fontSize: 13, fontWeight: '700', letterSpacing: 2, marginHorizontal: 22 },
  heroTitle: { color: '#fff', fontSize: 28, fontWeight: '700', marginTop: 8, marginHorizontal: 22, marginBottom: 22 },
  statsRow: { flexDirection: 'row', gap: 12, paddingHorizontal: 18, marginTop: 20 },
  statCard: {
    flex: 1, alignItems: 'center', gap: 6, paddingVertical: 16, paddingHorizontal: 6,
    borderRadius: 18, borderWidth: 1,
  },
  statValue: { fontSize: 14, fontWeight: '700', textAlign: 'center' },
  statLabel: { fontSize: 11, fontWeight: '500' },
  sectionCard: { marginHorizontal: 18, marginTop: 20, padding: 18 },
  sectionTitle: { fontSize: 17, fontWeight: '700', marginBottom: 12 },
  aboutText: { fontSize: 14, lineHeight: 22 },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 16 },
  signUpBar: { borderTopWidth: StyleSheet.hairlineWidth },
  signUpBarInner: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 20, paddingVertical: 14 },
  countValue: { fontSize: 18, fontWeight: '700' },
  countLabel: { fontSize: 12, fontWeight: '500', marginTop: 2 },
  signUpButton: { borderRadius: radius.pill, overflow: 'hidden' },
  signedUpBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7,
    borderRadius: radius.pill, borderWidth: 1.5, paddingHorizontal: 22, paddingVertical: 13,
  },
  fullPill: {
    alignItems: 'center', justifyContent: 'center',
    borderRadius: radius.pill, paddingHorizontal: 26, paddingVertical: 14,
  },
  signedUpText: { fontSize: 15, fontWeight: '700' },
  backWrap: { position: 'absolute', top: 0, left: 0, right: 0 },
  backBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginLeft: 18, marginTop: 8 },
});
