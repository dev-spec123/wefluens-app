import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { EmptyState, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, space, useTheme } from '@/lib/theme';
import type { Brand, Campaign } from '@/lib/types';

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
  const { brands, campaigns, refreshDiscover } = useAppData();

  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter] = useState<string>('filterAll');
  const [selectedBrand, setSelectedBrand] = useState<string | null>(null);

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

  // Featured = a Glossier campaign if present, else the first one. Drives the hero.
  const featured = useMemo<Campaign | null>(() => {
    if (campaigns.length === 0) return null;
    return campaigns.find((c) => /glossier/i.test(c.brand)) ?? campaigns[0];
  }, [campaigns]);

  // Filter campaigns by the selected category (tag / title / brand match). Falls
  // back to the full list when a category has no matches, so it never looks broken.
  const shownCampaigns = useMemo<Campaign[]>(() => {
    // Tapping a brand filters to that brand and takes precedence over the category bar.
    if (selectedBrand) return campaigns.filter((c) => c.brand === selectedBrand);
    const f = FILTERS.find((x) => x.key === filter);
    if (!f?.match) return campaigns;
    const needle = f.match;
    const matched = campaigns.filter((c) =>
      c.tags.some((tag) => tag.toLowerCase().includes(needle))
      || c.title.toLowerCase().includes(needle)
      || c.brand.toLowerCase().includes(needle));
    return matched.length > 0 ? matched : campaigns;
  }, [campaigns, filter, selectedBrand]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <ScrollView
        contentContainerStyle={{ paddingBottom: space.xxl }}
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

        {/* Featured hero */}
        <LinearGradient
          colors={gradients.dusk}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.hero, { shadowColor: c.plum }]}
        >
          <View style={styles.heroAccent} />
          <View style={{ gap: 12 }}>
            <View style={styles.featuredChip}>
              <Text style={styles.featuredChipText}>{t('discoverFeatured')}</Text>
            </View>
            <Text style={styles.heroTitle}>
              {featured ? featured.title : 'Glossier Summer\nGlow Launch'}
            </Text>
            <Text style={styles.heroSubtitle}>
              {featured ? `${featured.brand} · ${featured.budget}` : '3 creator spots · $8K–12K budget'}
            </Text>
            {featured ? (
              <Pressable onPress={() => openCampaign(featured)} style={styles.heroBtn}>
                <Text style={[styles.heroBtnText, { color: c.plum }]}>{t('discoverViewBrief')}</Text>
              </Pressable>
            ) : null}
          </View>
        </LinearGradient>

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

        {/* Top Brands */}
        <Text style={[styles.sectionTitle, { color: c.ink }]}>{t('discoverTopBrands')}</Text>
        {brands.length > 0 ? (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.brandRow}
          >
            {brands.map((brand) => (
              <BrandCard
                key={brand.id}
                brand={brand}
                selected={selectedBrand === brand.name}
                onPress={() => setSelectedBrand((cur) => (cur === brand.name ? null : brand.name))}
              />
            ))}
          </ScrollView>
        ) : (
          <Text style={[styles.emptyRowText, { color: c.inkTertiary }]}>{t('discoverNoBrands')}</Text>
        )}

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
              <CampaignCard key={campaign.id} campaign={campaign} onPress={() => openCampaign(campaign)} />
            ))}
          </View>
        ) : (
          <EmptyState icon="megaphone-outline" title={t('discoverNoCampaigns')} />
        )}
      </ScrollView>
    </SafeAreaView>
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
      <LinearGradient
        colors={brand.colors}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.brandIconWrap}
      >
        <Ionicons name={iconFor(brand.symbol)} size={26} color="#fff" />
      </LinearGradient>

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

function CampaignCard({ campaign, onPress }: { campaign: Campaign; onPress: () => void }) {
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
      <LinearGradient
        colors={campaign.colors}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.campaignIconWrap}
      >
        <Ionicons name={iconFor(campaign.symbol)} size={24} color="#fff" />
      </LinearGradient>

      <View style={styles.campaignBody}>
        <Text style={[styles.campaignTitle, { color: c.ink }]} numberOfLines={1}>{campaign.title}</Text>
        <Text style={[styles.campaignMeta, { color: c.inkSecondary }]} numberOfLines={1}>
          {campaign.brand} · {campaign.budget}
        </Text>

        <View style={styles.campaignInfoRow}>
          <Ionicons name="time-outline" size={12} color={c.inkTertiary} />
          <Text style={[styles.campaignInfoText, { color: c.inkTertiary }]}>
            {t('discoverDue')} {campaign.deadline}
          </Text>
          <Text style={[styles.campaignInfoText, { color: c.inkTertiary }]}>·</Text>
          <Text style={[styles.campaignSpots, { color: spotsColor }]}>
            {campaign.spotsLeft} {t('discoverSpotsLeft')}
          </Text>
        </View>

        {campaign.tags.length > 0 ? (
          <View style={styles.tagsRow}>
            {campaign.tags.map((tag) => (
              <TagChip key={tag} text={tag} />
            ))}
          </View>
        ) : null}
      </View>

      <Ionicons name="chevron-forward" size={14} color={c.inkTertiary} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: 18, paddingTop: space.sm, paddingBottom: 14 },
  title: { fontSize: 32, fontWeight: '700' },
  subtitle: { fontSize: 14, fontWeight: '500', marginTop: 2 },
  sectionTitle: { fontSize: 20, fontWeight: '700', paddingHorizontal: 18, marginBottom: 12 },
  emptyRowText: { fontSize: 14, fontWeight: '500', paddingHorizontal: 18, paddingVertical: 8 },

  // Featured hero
  hero: {
    marginHorizontal: 18,
    borderRadius: 28,
    padding: 22,
    minHeight: 200,
    justifyContent: 'flex-end',
    overflow: 'hidden',
    shadowOpacity: 0.3,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 12 },
    elevation: 8,
  },
  heroAccent: {
    position: 'absolute',
    width: 200, height: 200, borderRadius: 100,
    backgroundColor: 'rgba(255,255,255,0.12)',
    top: -60, right: -50,
  },
  featuredChip: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(255,255,255,0.18)',
    borderRadius: radius.pill,
    paddingHorizontal: 12, paddingVertical: 5,
  },
  featuredChipText: { color: '#fff', fontSize: 12, fontWeight: '700' },
  heroTitle: { color: '#fff', fontSize: 26, fontWeight: '800' },
  heroSubtitle: { color: 'rgba(255,255,255,0.85)', fontSize: 14, fontWeight: '500' },
  heroBtn: {
    alignSelf: 'flex-start',
    backgroundColor: '#fff',
    borderRadius: radius.pill,
    paddingHorizontal: 22, paddingVertical: 11,
    marginTop: 4,
  },
  heroBtnText: { fontSize: 15, fontWeight: '700' },

  // Filter bar
  filterRow: { paddingHorizontal: 18, gap: 10, paddingVertical: 16 },

  campaignHeader: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingHorizontal: 18, marginTop: 26, marginBottom: 12, gap: 10,
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
  brandIconWrap: {
    width: 56,
    height: 56,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  brandName: { fontSize: 16, fontWeight: '700' },
  brandCategory: { fontSize: 12, fontWeight: '500', marginTop: 3 },
  brandTagline: { fontSize: 12, marginTop: 8, height: 32 },
  brandActiveRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 8 },
  dot: { width: 6, height: 6, borderRadius: 3 },
  brandActiveText: { fontSize: 12, fontWeight: '600' },

  campaignList: { paddingHorizontal: 18, gap: 14 },
  campaignCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 14,
  },
  campaignIconWrap: {
    width: 60,
    height: 60,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  campaignBody: { flex: 1, gap: 5 },
  campaignTitle: { fontSize: 16, fontWeight: '700' },
  campaignMeta: { fontSize: 13, fontWeight: '500' },
  campaignInfoRow: { flexDirection: 'row', alignItems: 'center', gap: 6, flexWrap: 'wrap' },
  campaignInfoText: { fontSize: 12, fontWeight: '500' },
  campaignSpots: { fontSize: 12, fontWeight: '600' },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 4 },
});
