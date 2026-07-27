import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { EmptyState, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { applyToCampaign, cancelEventSignup, loadMyEventSignups, signUpForEvent, withdrawFromCampaign } from '@/lib/api';
import { seedAppliedCampaigns, setLocalCampaignApplied } from '@/lib/campaignApplications';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, space, useTheme } from '@/lib/theme';
import type { Brand, Campaign, Event } from '@/lib/types';

/** Map an SF Symbol-ish name from the backend to an Ionicons glyph. */
function iconFor(symbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    'megaphone.fill': 'megaphone',
    megaphone: 'megaphone',
    sparkles: 'sparkles',
    'flame.fill': 'flame',
    flame: 'flame',
    'cart.fill': 'cart',
    cart: 'cart',
    'bag.fill': 'bag',
    bag: 'bag',
    'star.fill': 'star',
    star: 'star',
    'camera.fill': 'camera',
    camera: 'camera',
    'gift.fill': 'gift',
    gift: 'gift',
    'leaf.fill': 'leaf',
    leaf: 'leaf',
    'bolt.fill': 'flash',
    bolt: 'flash',
    'sun.max.fill': 'sunny',
    'tshirt.fill': 'shirt',
    tshirt: 'shirt',
  };
  return map[symbol] ?? 'sparkles';
}

/** Format an ISO deadline ("YYYY-MM-DD") to a short local date; pass anything
 *  else through unchanged (older rows may store a free-text deadline). */
function formatDeadline(raw: string): string {
  if (!raw) return '';
  const d = new Date(/^\d{4}-\d{2}-\d{2}$/.test(raw) ? `${raw}T00:00:00` : raw);
  if (isNaN(d.getTime())) return raw;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

/** "Sat, 12 Jul \u00b7 7:00 PM" — the one date style used across the event surfaces.
 *  Returns the fallback when the event has no start date yet. */
function formatEventDate(raw: string | null, fallback: string): string {
  if (!raw) return fallback;
  const d = new Date(raw);
  if (isNaN(d.getTime())) return fallback;
  return d.toLocaleString(undefined, {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  });
}

const FILTERS = [
  { key: 'filterAll', match: null },
  { key: 'filterBeauty', match: 'beauty' },
  { key: 'filterFashion', match: 'fashion' },
  { key: 'filterWellness', match: 'wellness' },
  { key: 'filterTech', match: 'tech' },
] as const;

export default function DiscoverScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { brands, campaigns, events, refreshDiscover } = useAppData();

  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<string>('filterAll');
  const [selectedBrand, setSelectedBrand] = useState<string | null>(null);

  // Server-seeded applied state, keyed by campaign id. Seeded from each
  // campaign.applied flag (the RPC already resolves "applied" per caller) and
  // mirrored into the on-device cache so detail screens read it instantly.
  const [appliedIds, setAppliedIds] = useState<Set<string>>(new Set());
  const [busyId, setBusyId] = useState<string | null>(null);

  // Server-seeded signed-up state, keyed by event id. Seeded from each event's
  // own signed_up flag, then refined against list_my_event_signups.
  const [signedUpIds, setSignedUpIds] = useState<Set<string>>(new Set());
  const [busyEventId, setBusyEventId] = useState<string | null>(null);

  useEffect(() => {
    const ids = campaigns.filter((cm) => cm.applied).map((cm) => cm.id);
    setAppliedIds(new Set(ids));
    void seedAppliedCampaigns(ids);
  }, [campaigns]);

  useEffect(() => {
    setSignedUpIds(new Set(events.filter((e) => e.signedUp).map((e) => e.id)));
    let active = true;
    loadMyEventSignups()
      .then((ids) => { if (active && ids.length) setSignedUpIds(new Set(ids)); })
      .catch(() => {});
    return () => { active = false; };
  }, [events]);

  async function onRefresh() {
    setRefreshing(true);
    try {
      await refreshDiscover();
    } finally {
      setRefreshing(false);
    }
  }

  function openCampaign(campaign: Campaign) {
    router.push({ pathname: '/campaign/[id]', params: { id: campaign.id } });
  }

  function openEvent(event: Event) {
    router.push({ pathname: '/event/[id]', params: { id: event.id } });
  }

  // Sign up / cancel toggle with optimistic UI + server refresh, mirroring the
  // campaign apply toggle. A full event can be left but not joined.
  const toggleSignUp = useCallback(async (event: Event) => {
    if (busyEventId) return;
    const id = event.id;
    const wasSignedUp = signedUpIds.has(id);
    const isFull = event.spotsLeft != null && event.spotsLeft <= 0;
    if (!wasSignedUp && isFull) return;
    setBusyEventId(id);
    setSignedUpIds((prev) => {
      const next = new Set(prev);
      if (wasSignedUp) next.delete(id); else next.add(id);
      return next;
    });
    try {
      if (wasSignedUp) await cancelEventSignup(id);
      else await signUpForEvent(id);
      await refreshDiscover();
    } catch {
      setSignedUpIds((prev) => {
        const next = new Set(prev);
        if (wasSignedUp) next.add(id); else next.delete(id);
        return next;
      });
      notify(t('discoverSignUpFailed'));
    } finally {
      setBusyEventId(null);
    }
  }, [busyEventId, refreshDiscover, signedUpIds, t]);

  // Apply / withdraw toggle with optimistic UI + server refresh. The server is
  // the source of truth: on success we refresh so spots_left / application_count
  // reflect the real counts; on failure we roll the optimistic flip back.
  const toggleApply = useCallback(async (campaign: Campaign) => {
    if (busyId) return;
    const id = campaign.id;
    const wasApplied = appliedIds.has(id);
    setBusyId(id);
    setAppliedIds((prev) => {
      const next = new Set(prev);
      if (wasApplied) next.delete(id); else next.add(id);
      return next;
    });
    void setLocalCampaignApplied(id, !wasApplied);
    try {
      if (wasApplied) await withdrawFromCampaign(id);
      else await applyToCampaign(id);
      await refreshDiscover();
    } catch {
      // Roll back the optimistic flip.
      setAppliedIds((prev) => {
        const next = new Set(prev);
        if (wasApplied) next.add(id); else next.delete(id);
        return next;
      });
      void setLocalCampaignApplied(id, wasApplied);
      notify(t('discoverApplyError'));
    } finally {
      setBusyId(null);
    }
  }, [appliedIds, busyId, refreshDiscover, t]);

  // Featured (精选) = brands with a featured_rank (admin toggle). list_discover_brands
  // already orders these first, by rank.
  const featuredBrands = useMemo<Brand[]>(
    () => brands.filter((b) => b.featuredRank != null),
    [brands],
  );

  // Hot (热门品牌) = brands sorted by application_count desc (most-applied first).
  const hotBrands = useMemo<Brand[]>(
    () => [...brands].sort((a, b) => b.applicationCount - a.applicationCount),
    [brands],
  );

  // Filter campaigns by the selected category (tag / title / brand match). Falls
  // back to the full list when a category has no matches, so it never looks broken.
  const shownCampaigns = useMemo<Campaign[]>(() => {
    // Tapping a brand filters to that brand and takes precedence over the category bar.
    if (selectedBrand) return campaigns.filter((cm) => cm.brand === selectedBrand);
    const f = FILTERS.find((x) => x.key === filter);
    if (!f?.match) return campaigns;
    const needle = f.match;
    const matched = campaigns.filter((cm) =>
      cm.tags.some((tag) => tag.toLowerCase().includes(needle))
      || cm.title.toLowerCase().includes(needle)
      || cm.brand.toLowerCase().includes(needle));
    return matched.length > 0 ? matched : campaigns;
  }, [campaigns, filter, selectedBrand]);

  const hasContent = brands.length > 0 || campaigns.length > 0 || events.length > 0;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <ScrollView
        contentContainerStyle={{ paddingBottom: space.xxl, flexGrow: 1 }}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />
        }
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={[styles.title, { color: c.ink }]}>{t('discoverTitle')}</Text>
          <Text style={[styles.subtitle, { color: c.inkSecondary }]}>{t('discoverSubtitle')}</Text>
        </View>

        {!hasContent ? (
          <View style={styles.emptyWrap}>
            <EmptyState
              icon="sparkles-outline"
              title={t('discoverEmptyTitle')}
              subtitle={t('discoverEmptySubtitle')}
            />
          </View>
        ) : (
          <>
            {/* Featured / 精选 — brands the admin toggled featured. */}
            {featuredBrands.length > 0 ? (
              <>
                <Text style={[styles.sectionTitle, { color: c.ink }]}>{t('discoverFeatured')}</Text>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.brandRow}
                >
                  {featuredBrands.map((brand) => (
                    <BrandCard
                      key={`feat-${brand.id}`}
                      brand={brand}
                      selected={selectedBrand === brand.name}
                      onPress={() => setSelectedBrand((cur) => (cur === brand.name ? null : brand.name))}
                    />
                  ))}
                </ScrollView>
              </>
            ) : null}

            {/* Hot / 热门品牌 — brands by application_count desc. */}
            {hotBrands.length > 0 ? (
              <>
                <Text style={[styles.sectionTitle, { color: c.ink, marginTop: featuredBrands.length > 0 ? 26 : 12 }]}>
                  {t('discoverHotBrands')}
                </Text>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.brandRow}
                >
                  {hotBrands.map((brand) => (
                    <BrandCard
                      key={`hot-${brand.id}`}
                      brand={brand}
                      selected={selectedBrand === brand.name}
                      onPress={() => setSelectedBrand((cur) => (cur === brand.name ? null : brand.name))}
                    />
                  ))}
                </ScrollView>
              </>
            ) : null}

            {/* Events — admin-published, soonest first (server-ordered). Hidden
                entirely when there are none, so Discover looks unchanged until
                the first event goes live. */}
            {events.length > 0 ? (
              <>
                <Text style={[styles.sectionTitle, { color: c.ink, marginTop: 26 }]}>
                  {t('discoverEvents')}
                </Text>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.brandRow}
                >
                  {events.map((event) => (
                    <EventCard
                      key={event.id}
                      event={event}
                      signedUp={signedUpIds.has(event.id)}
                      busy={busyEventId === event.id}
                      onPress={() => openEvent(event)}
                      onToggle={() => toggleSignUp(event)}
                    />
                  ))}
                </ScrollView>
              </>
            ) : null}

            {/* Filter bar */}
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.filterRow}
            >
              {FILTERS.map((f) => (
                <Pressable key={f.key} onPress={() => setFilter(f.key)}>
                  <TagChip text={t(f.key)} filled={filter === f.key} />
                </Pressable>
              ))}
            </ScrollView>

            {/* Open Campaigns */}
            <View style={styles.campaignHeader}>
              <Text style={[styles.sectionTitle, { color: c.ink, marginBottom: 0 }]}>
                {t('discoverOpenCampaigns')}
              </Text>
              {selectedBrand ? (
                <Pressable
                  onPress={() => setSelectedBrand(null)}
                  style={[styles.brandFilterPill, { backgroundColor: c.coral }]}
                  hitSlop={6}
                >
                  <Text style={styles.brandFilterText} numberOfLines={1}>{selectedBrand}</Text>
                  <Ionicons name="close" size={13} color="#fff" />
                </Pressable>
              ) : null}
            </View>
            {shownCampaigns.length > 0 ? (
              <View style={styles.campaignList}>
                {shownCampaigns.map((campaign) => (
                  <CampaignCard
                    key={campaign.id}
                    campaign={campaign}
                    applied={appliedIds.has(campaign.id)}
                    busy={busyId === campaign.id}
                    onPress={() => openCampaign(campaign)}
                    onToggleApply={() => toggleApply(campaign)}
                  />
                ))}
              </View>
            ) : (
              <EmptyState icon="megaphone-outline" title={t('discoverNoCampaigns')} />
            )}
          </>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

/** Icon: an uploaded image if the row has one, else the default gradient + SF-symbol. */
function DiscoverIcon({
  iconUrl, colors, symbol, size, rounding,
}: { iconUrl: string | null; colors: [string, string]; symbol: string; size: number; rounding: number }) {
  if (iconUrl) {
    return (
      <Image
        source={{ uri: iconUrl }}
        style={{ width: size, height: size, borderRadius: rounding }}
        contentFit="cover"
      />
    );
  }
  return (
    <LinearGradient
      colors={colors}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={{ width: size, height: size, borderRadius: rounding, alignItems: 'center', justifyContent: 'center' }}
    >
      <Ionicons name={iconFor(symbol)} size={size * 0.45} color="#fff" />
    </LinearGradient>
  );
}

function BrandCard({ brand, selected, onPress }: { brand: Brand; selected: boolean; onPress: () => void }) {
  const c = useTheme();
  const { t } = useI18n();
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.brandCard,
        { backgroundColor: pressed ? c.cardSubtle : c.card, borderColor: selected ? c.coral : c.hairline, borderWidth: selected ? 2 : 1 },
      ]}
    >
      <DiscoverIcon iconUrl={brand.iconUrl} colors={brand.colors} symbol={brand.symbol} size={56} rounding={18} />

      <View style={{ marginTop: 12 }}>
        <Text style={[styles.brandName, { color: c.ink }]} numberOfLines={1}>{brand.name}</Text>
        <Text style={[styles.brandCategory, { color: c.inkSecondary }]} numberOfLines={1}>
          {brand.category}
        </Text>
      </View>

      <Text style={[styles.brandTagline, { color: c.inkSecondary }]} numberOfLines={2}>
        {brand.tagline}
      </Text>

      <View style={styles.brandActiveRow}>
        <View style={[styles.dot, { backgroundColor: c.coral }]} />
        <Text style={[styles.brandActiveText, { color: c.coral }]}>
          {brand.activeCampaigns} {t('discoverActive')}
        </Text>
      </View>
    </Pressable>
  );
}

/** A horizontal-strip card for one published event, with an inline sign-up toggle. */
function EventCard({
  event, signedUp, busy, onPress, onToggle,
}: {
  event: Event; signedUp: boolean; busy: boolean;
  onPress: () => void; onToggle: () => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  // Full only blocks people who aren't already in — their own slot is theirs.
  const isFull = event.spotsLeft != null && event.spotsLeft <= 0 && !signedUp;

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.eventCard,
        { backgroundColor: pressed ? c.cardSubtle : c.card, borderColor: c.hairline },
      ]}
    >
      <DiscoverIcon iconUrl={event.iconUrl} colors={event.colors} symbol={event.symbol} size={56} rounding={18} />

      <Text style={[styles.eventTitle, { color: c.ink }]} numberOfLines={2}>{event.title}</Text>

      <View style={styles.eventInfoRow}>
        <Ionicons name="calendar-outline" size={12} color={c.inkSecondary} />
        <Text style={[styles.eventInfoText, { color: c.inkSecondary }]} numberOfLines={1}>
          {formatEventDate(event.startsAt, t('eventDetailTBA'))}
        </Text>
      </View>

      {event.location ? (
        <View style={styles.eventInfoRow}>
          <Ionicons name="location-outline" size={12} color={c.inkTertiary} />
          <Text style={[styles.eventInfoText, { color: c.inkTertiary }]} numberOfLines={1}>
            {event.location}
          </Text>
        </View>
      ) : null}

      <View style={styles.eventInfoRow}>
        <Ionicons name="people-outline" size={12} color={c.inkTertiary} />
        <Text style={[styles.eventCount, { color: c.inkTertiary }]}>
          {event.signupCount} {t('discoverParticipants')}
        </Text>
      </View>

      {isFull ? (
        <View style={[styles.eventBtn, { backgroundColor: c.inkTertiary + '26', borderColor: 'transparent' }]}>
          <Text style={[styles.eventBtnText, { color: c.inkSecondary }]}>{t('discoverEventFull')}</Text>
        </View>
      ) : (
        <Pressable
          onPress={onToggle}
          disabled={busy}
          hitSlop={6}
          style={[
            styles.eventBtn,
            signedUp
              ? { backgroundColor: c.coral + '14', borderColor: c.coral }
              : { backgroundColor: c.coral, borderColor: c.coral },
            busy && { opacity: 0.6 },
          ]}
        >
          {signedUp ? <Ionicons name="checkmark" size={14} color={c.coral} /> : null}
          <Text style={[styles.eventBtnText, { color: signedUp ? c.coral : '#fff' }]}>
            {signedUp ? t('discoverJoined') : t('discoverJoin')}
          </Text>
        </Pressable>
      )}
    </Pressable>
  );
}

function CampaignCard({
  campaign, applied, busy, onPress, onToggleApply,
}: {
  campaign: Campaign; applied: boolean; busy: boolean;
  onPress: () => void; onToggleApply: () => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const spotsColor = campaign.spotsLeft <= 2 ? c.coral : c.inkSecondary;
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.campaignCard,
        { backgroundColor: pressed ? c.cardSubtle : c.card, borderColor: c.hairline },
      ]}
    >
      <View style={styles.campaignTopRow}>
        <DiscoverIcon iconUrl={campaign.iconUrl} colors={campaign.colors} symbol={campaign.symbol} size={56} rounding={16} />

        <View style={styles.campaignBody}>
          <Text style={[styles.campaignTitle, { color: c.ink }]} numberOfLines={1}>{campaign.title}</Text>
          <Text style={[styles.campaignMeta, { color: c.inkSecondary }]} numberOfLines={1}>
            {campaign.brand} · {campaign.budget}
          </Text>

          <View style={styles.campaignInfoRow}>
            <Ionicons name="time-outline" size={12} color={c.inkTertiary} />
            <Text style={[styles.campaignInfoText, { color: c.inkTertiary }]}>
              {t('discoverDue')} {formatDeadline(campaign.deadline)}
            </Text>
            <Text style={[styles.campaignInfoText, { color: c.inkTertiary }]}>·</Text>
            <Text style={[styles.campaignSpots, { color: spotsColor }]}>
              {campaign.spotsLeft} {t('discoverSpotsLeft')}
            </Text>
          </View>
        </View>
      </View>

      {campaign.description ? (
        <Text style={[styles.campaignDesc, { color: c.inkSecondary }]} numberOfLines={2}>
          {campaign.description}
        </Text>
      ) : null}

      {campaign.tags.length > 0 ? (
        <View style={styles.tagsRow}>
          {campaign.tags.map((tag) => (
            <TagChip key={tag} text={tag} />
          ))}
        </View>
      ) : null}

      <View style={styles.campaignFooter}>
        <View style={styles.applicantsRow}>
          <Ionicons name="people-outline" size={13} color={c.inkTertiary} />
          <Text style={[styles.applicantsText, { color: c.inkTertiary }]}>
            {campaign.applicationCount} {t('discoverApplicants')}
          </Text>
        </View>
        <Pressable
          onPress={onToggleApply}
          disabled={busy}
          hitSlop={6}
          style={[
            styles.applyBtn,
            applied
              ? { backgroundColor: c.coral + '14', borderColor: c.coral }
              : { backgroundColor: c.coral, borderColor: c.coral },
            busy && { opacity: 0.6 },
          ]}
        >
          {applied ? <Ionicons name="checkmark" size={14} color={c.coral} /> : null}
          <Text style={[styles.applyBtnText, { color: applied ? c.coral : '#fff' }]}>
            {applied ? t('discoverApplied') : t('discoverApply')}
          </Text>
        </Pressable>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: 18, paddingTop: space.sm, paddingBottom: 14 },
  title: { fontSize: 32, fontWeight: '700' },
  subtitle: { fontSize: 14, fontWeight: '500', marginTop: 2 },
  sectionTitle: { fontSize: 20, fontWeight: '700', paddingHorizontal: 18, marginBottom: 12 },

  emptyWrap: { flex: 1, minHeight: 320 },

  // Filter bar
  filterRow: { paddingHorizontal: 18, gap: 10, paddingVertical: 16 },

  campaignHeader: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 18, marginTop: 8, marginBottom: 12, gap: 10,
  },
  brandFilterPill: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    borderRadius: 999, paddingHorizontal: 12, paddingVertical: 5, maxWidth: 180,
  },
  brandFilterText: { color: '#fff', fontSize: 12.5, fontWeight: '700' },

  brandRow: { paddingHorizontal: 18, gap: 14 },
  brandCard: {
    width: 180,
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 16,
  },
  brandName: { fontSize: 16, fontWeight: '700' },
  brandCategory: { fontSize: 12, fontWeight: '500', marginTop: 3 },
  brandTagline: { fontSize: 12, marginTop: 8, height: 32 },
  brandActiveRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 8 },
  dot: { width: 6, height: 6, borderRadius: 3 },
  brandActiveText: { fontSize: 12, fontWeight: '600' },

  eventCard: {
    width: 232,
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 16,
    gap: 8,
  },
  eventTitle: { fontSize: 16, fontWeight: '700', marginTop: 4, height: 42 },
  eventInfoRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  eventInfoText: { fontSize: 12, fontWeight: '500', flex: 1 },
  eventCount: { fontSize: 11.5, fontWeight: '600' },
  eventBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 5,
    borderRadius: radius.pill, borderWidth: 1.5,
    paddingVertical: 9, marginTop: 4,
  },
  eventBtnText: { fontSize: 13.5, fontWeight: '700' },

  campaignList: { paddingHorizontal: 18, gap: 14 },
  campaignCard: {
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 14,
    gap: 10,
  },
  campaignTopRow: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  campaignBody: { flex: 1, gap: 5 },
  campaignTitle: { fontSize: 16, fontWeight: '700' },
  campaignMeta: { fontSize: 13, fontWeight: '500' },
  campaignInfoRow: { flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap' },
  campaignInfoText: { fontSize: 12, fontWeight: '500' },
  campaignSpots: { fontSize: 12, fontWeight: '600' },
  campaignDesc: { fontSize: 13, lineHeight: 19 },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  campaignFooter: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    marginTop: 2,
  },
  applicantsRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  applicantsText: { fontSize: 12, fontWeight: '600' },
  applyBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 5,
    borderRadius: radius.pill, borderWidth: 1.5,
    paddingHorizontal: 18, paddingVertical: 8,
  },
  applyBtnText: { fontSize: 13.5, fontWeight: '700' },
});
