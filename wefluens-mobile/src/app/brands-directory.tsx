import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, LayoutAnimation, Platform, Pressable, ScrollView, StyleSheet, Text,
  TextInput, UIManager, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';
import type { Brand } from '@/lib/types';

// Enable LayoutAnimation on Android (no-op on iOS / web where it's already on).
if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

/** Mirror of the Swift withAnimation(.spring) on category chip selection. */
function animateChip() {
  LayoutAnimation.configureNext(LayoutAnimation.create(220, 'easeInEaseOut', 'opacity'));
}

/** Map an SF Symbol-ish name from the backend to an Ionicons glyph. */
function iconFor(symbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    'megaphone.fill': 'megaphone', megaphone: 'megaphone', sparkles: 'sparkles',
    'flame.fill': 'flame', flame: 'flame', 'cart.fill': 'cart', cart: 'cart',
    'bag.fill': 'bag', bag: 'bag', 'star.fill': 'star', star: 'star',
    'camera.fill': 'camera', camera: 'camera', 'gift.fill': 'gift', gift: 'gift',
    'leaf.fill': 'leaf', leaf: 'leaf', 'bolt.fill': 'flash', bolt: 'flash',
    'sun.max.fill': 'sunny', 'tshirt.fill': 'shirt', tshirt: 'shirt',
  };
  return map[symbol] ?? 'sparkles';
}

/**
 * Brands directory (mirrors the Swift BrandsDirectoryView). Searchable +
 * category-filterable list of brands; tapping a brand drills into that brand's
 * open campaigns. Reuses the Discover brands/campaigns from AppData.
 */
export default function BrandsDirectory() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { brands, campaigns, refreshDiscover } = useAppData();

  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<string | null>(null);
  const [selectedBrand, setSelectedBrand] = useState<Brand | null>(null);
  // Mirrors Swift's `@State private var isLoading = true`; cleared once the
  // initial Discover load settles so the spinner only shows on a cold start.
  const [isLoading, setIsLoading] = useState(brands.length === 0);

  // Safety net — Discover normally loads these at app start.
  useEffect(() => {
    let active = true;
    if (brands.length === 0) {
      void refreshDiscover().finally(() => { if (active) setIsLoading(false); });
    } else {
      setIsLoading(false);
    }
    return () => { active = false; };
    // Run once on mount — mirrors Swift's `.task`.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const categories = useMemo(() => {
    const set = new Set<string>();
    brands.forEach((b) => { if (b.category) set.add(b.category); });
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [brands]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return brands.filter((b) => {
      if (category && b.category !== category) return false;
      if (!q) return true;
      return b.name.toLowerCase().includes(q)
        || b.category.toLowerCase().includes(q)
        || b.tagline.toLowerCase().includes(q);
    });
  }, [brands, query, category]);

  function campaignCount(brand: Brand): number {
    return campaigns.filter((cm) => cm.brand === brand.name).length;
  }

  // --- Nested campaigns view (drill-down into one brand) ---
  if (selectedBrand) {
    const list = campaigns.filter((cm) => cm.brand === selectedBrand.name);
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <NavBar title={selectedBrand.name} onBack={() => setSelectedBrand(null)} />
        {list.length === 0 ? (
          <View style={styles.centered}>
            <View style={[styles.iconCircle, { backgroundColor: c.coral + '1A' }]}>
              <Ionicons name="file-tray-outline" size={30} color={c.coral} />
            </View>
            <Text style={[styles.centeredText, { color: c.inkSecondary }]}>{t('brandsNoCampaigns')}</Text>
          </View>
        ) : (
          <ScrollView contentContainerStyle={{ padding: 18, gap: 14 }}>
            {list.map((cm) => (
              <Pressable
                key={cm.id}
                onPress={() => router.push({ pathname: '/campaign/[id]', params: { id: cm.id } })}
                style={({ pressed }) => [styles.campaignCard, { backgroundColor: pressed ? c.cardSubtle : c.card, borderColor: c.hairline }]}
              >
                <LinearGradient colors={cm.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.campaignIconWrap}>
                  <Ionicons name={iconFor(cm.symbol)} size={24} color="#fff" />
                </LinearGradient>
                <View style={{ flex: 1 }}>
                  <Text style={[styles.campaignTitle, { color: c.ink }]} numberOfLines={1}>{cm.title}</Text>
                  <Text style={[styles.campaignMeta, { color: c.inkSecondary }]} numberOfLines={1}>{cm.budget}</Text>
                </View>
                <Ionicons name="chevron-forward" size={14} color={c.inkTertiary} />
              </Pressable>
            ))}
          </ScrollView>
        )}
      </SafeAreaView>
    );
  }

  // --- Main brands list ---
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('contactsBrands')} onBack={() => router.back()} />

      {isLoading && brands.length === 0 ? (
        <View style={styles.centered}>
          <ActivityIndicator color={c.coral} size="large" />
        </View>
      ) : (
      <View style={{ flex: 1 }}>
        <View style={{ paddingHorizontal: 18, paddingTop: 10 }}>
          <View style={[styles.searchField, { backgroundColor: c.card, borderColor: c.hairline }]}>
            <Ionicons name="search" size={16} color={c.inkSecondary} style={{ marginRight: 10 }} />
            <TextInput
              value={query}
              onChangeText={setQuery}
              placeholder={t('brandsSearch')}
              placeholderTextColor={c.inkTertiary}
              autoCapitalize="none"
              autoCorrect={false}
              style={{ flex: 1, fontSize: 16, color: c.ink }}
            />
            {query.length > 0 && (
              <Pressable onPress={() => setQuery('')} hitSlop={8}>
                <Ionicons name="close-circle" size={18} color={c.inkTertiary} />
              </Pressable>
            )}
          </View>
        </View>

        {categories.length > 0 && (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            <Pressable onPress={() => { animateChip(); setCategory(null); }}>
              <TagChip text={t('filterAll')} filled={category === null} />
            </Pressable>
            {categories.map((cat) => (
              <Pressable key={cat} onPress={() => { animateChip(); setCategory((cur) => (cur === cat ? null : cat)); }}>
                <TagChip text={cat} filled={category === cat} />
              </Pressable>
            ))}
          </ScrollView>
        )}

        {filtered.length === 0 ? (
          <View style={styles.centered}>
            <View style={[styles.iconCircle, { backgroundColor: c.coral + '1A' }]}>
              <Ionicons name={brands.length === 0 ? 'business' : 'search'} size={32} color={c.coral} />
            </View>
            <Text style={[styles.centeredText, { color: c.inkSecondary }]}>
              {brands.length === 0 ? t('brandsEmpty') : t('brandsNoMatches')}
            </Text>
          </View>
        ) : (
          <ScrollView contentContainerStyle={{ padding: 18, gap: 12 }}>
            {filtered.map((brand) => (
              <Pressable
                key={brand.id}
                onPress={() => setSelectedBrand(brand)}
                style={({ pressed }) => [styles.brandRow, { backgroundColor: pressed ? c.cardSubtle : c.card, borderColor: c.hairline }]}
              >
                <LinearGradient colors={brand.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.brandIconWrap}>
                  <Ionicons name={iconFor(brand.symbol)} size={22} color="#fff" />
                </LinearGradient>
                <View style={{ flex: 1 }}>
                  <Text style={[styles.brandName, { color: c.ink }]} numberOfLines={1}>{brand.name}</Text>
                  <Text style={[styles.brandCategory, { color: c.inkSecondary }]} numberOfLines={1}>{brand.category}</Text>
                </View>
                <View style={styles.activeBadge}>
                  <View style={[styles.dot, { backgroundColor: c.coral }]} />
                  <Text style={[styles.activeText, { color: c.coral }]}>{campaignCount(brand)} {t('discoverActive')}</Text>
                </View>
                <Ionicons name="chevron-forward" size={13} color={c.inkTertiary} style={{ marginLeft: 6 }} />
              </Pressable>
            ))}
          </ScrollView>
        )}
      </View>
      )}
    </SafeAreaView>
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
  chipRow: { paddingHorizontal: 18, gap: 10, paddingVertical: 14 },
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32, gap: 12 },
  centeredText: { fontSize: 15, fontWeight: '500', textAlign: 'center' },
  iconCircle: { width: 76, height: 76, borderRadius: 38, alignItems: 'center', justifyContent: 'center' },

  brandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 14,
  },
  brandIconWrap: { width: 54, height: 54, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  brandName: { fontSize: 16, fontWeight: '700' },
  brandCategory: { fontSize: 13, fontWeight: '500', marginTop: 3 },
  activeBadge: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  dot: { width: 6, height: 6, borderRadius: 3 },
  activeText: { fontSize: 12, fontWeight: '600' },

  campaignCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    borderRadius: radius.card,
    borderWidth: 1,
    padding: 14,
  },
  campaignIconWrap: { width: 56, height: 56, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  campaignTitle: { fontSize: 16, fontWeight: '700' },
  campaignMeta: { fontSize: 13, fontWeight: '500', marginTop: 3 },
});
