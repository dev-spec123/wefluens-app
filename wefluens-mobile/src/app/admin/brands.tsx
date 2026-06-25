/**
 * Admin brand management + curation — create/edit/delete brands, and feature /
 * order them for Discover's Top Brands strip. Mirrors the Swift ManageBrandsView.
 * Writes go through is_admin-gated RPCs (admin_upsert_brand / admin_delete_brand /
 * admin_set_featured_brand). English UI strings are localized via i18n.
 */
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform, Pressable, RefreshControl,
  ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, GradientButton, NavBar } from '@/components/ui';
import * as api from '@/lib/api';
import type { AdminBrand } from '@/lib/api';
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

/** Map an SF Symbol-ish name from the backend to an Ionicons glyph (mirrors brands-directory). */
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

export default function ManageBrands() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const [brands, setBrands] = useState<AdminBrand[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState<AdminBrand | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    try {
      setBrands(await api.loadBrandsForAdmin());
    } catch {
      notify(t('adminLoadError'));
    }
  }, [t]);

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

  const featured = useMemo(
    () => brands.filter((b) => b.featuredRank != null).sort((a, b) => (a.featuredRank ?? 0) - (b.featuredRank ?? 0)),
    [brands],
  );
  const others = useMemo(
    () => brands.filter((b) => b.featuredRank == null).sort((a, b) => a.name.localeCompare(b.name)),
    [brands],
  );

  async function setFeatured(brand: AdminBrand, rank: number | null) {
    if (busy) return;
    setBusy(true);
    try {
      await api.adminSetFeaturedBrand(brand.id, rank);
      await load();
    } catch {
      notify(t('adminSaveError'));
    } finally {
      setBusy(false);
    }
  }

  // Swap a featured brand's rank with its neighbor (up = -1, down = +1).
  async function move(brand: AdminBrand, delta: number) {
    if (busy) return;
    const i = featured.findIndex((b) => b.id === brand.id);
    const target = i + delta;
    if (i < 0 || target < 0 || target >= featured.length) return;
    setBusy(true);
    try {
      const a = featured[i];
      const b = featured[target];
      await api.adminSetFeaturedBrand(a.id, b.featuredRank);
      await api.adminSetFeaturedBrand(b.id, a.featuredRank);
      await load();
    } catch {
      notify(t('adminSaveError'));
    } finally {
      setBusy(false);
    }
  }

  function renderRow(brand: AdminBrand, featuredIndex: number | null) {
    return (
      <View key={brand.id} style={styles.row}>
        {brand.iconUrl ? (
          <Image source={{ uri: brand.iconUrl }} style={styles.rowIcon} contentFit="cover" />
        ) : (
          <LinearGradient colors={brand.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowIcon}>
            <Ionicons name={iconFor(brand.symbol)} size={16} color="#fff" />
          </LinearGradient>
        )}
        <View style={{ flex: 1 }}>
          <Text style={[styles.rowTitle, { color: c.ink }]} numberOfLines={1}>{brand.name}</Text>
          <Text style={[styles.rowSub, { color: c.inkSecondary }]} numberOfLines={1}>{brand.category}</Text>
        </View>
        {featuredIndex != null ? (
          <>
            <Pressable
              onPress={() => move(brand, -1)}
              disabled={featuredIndex === 0 || busy}
              hitSlop={6}
              style={[styles.arrow, { backgroundColor: c.cardSubtle, opacity: featuredIndex === 0 ? 0.4 : 1 }]}
            >
              <Ionicons name="chevron-up" size={14} color={c.inkSecondary} />
            </Pressable>
            <Pressable
              onPress={() => move(brand, 1)}
              disabled={featuredIndex === featured.length - 1 || busy}
              hitSlop={6}
              style={[styles.arrow, { backgroundColor: c.cardSubtle, opacity: featuredIndex === featured.length - 1 ? 0.4 : 1 }]}
            >
              <Ionicons name="chevron-down" size={14} color={c.inkSecondary} />
            </Pressable>
            <Pressable onPress={() => setFeatured(brand, null)} disabled={busy} hitSlop={6} style={styles.action}>
              <Ionicons name="star" size={18} color={c.coral} />
            </Pressable>
          </>
        ) : (
          <Pressable
            onPress={() => setFeatured(brand, (Math.max(0, ...featured.map((b) => b.featuredRank ?? 0))) + 1)}
            disabled={busy}
            hitSlop={6}
            style={styles.action}
          >
            <Ionicons name="star-outline" size={18} color={c.inkTertiary} />
          </Pressable>
        )}
        <Pressable onPress={() => setEditing(brand)} hitSlop={6} style={styles.action}>
          <Ionicons name="pencil" size={17} color={c.inkSecondary} />
        </Pressable>
      </View>
    );
  }

  function SectionTitle({ text }: { text: string }) {
    return <Text style={[styles.sectionTitle, { color: c.inkTertiary }]}>{text.toUpperCase()}</Text>;
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('adminManageBrands')} onBack={() => router.back()} />
      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.content}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />}
        >
          <GradientButton title={`+ ${t('adminNewBrand')}`} onPress={() => setCreating(true)} style={{ marginBottom: 4 }} />

          {brands.length === 0 ? (
            <View style={styles.empty}>
              <Ionicons name="business" size={40} color={c.inkTertiary} />
              <Text style={[styles.emptyText, { color: c.inkSecondary }]}>{t('adminNoBrands')}</Text>
            </View>
          ) : (
            <>
              {featured.length > 0 ? (
                <View>
                  <SectionTitle text={t('adminBrandsFeatured')} />
                  <Card style={styles.listCard}>
                    {featured.map((b, i) => renderRow(b, i))}
                  </Card>
                </View>
              ) : null}
              <View>
                <SectionTitle text={t('adminBrandsAll')} />
                <Card style={styles.listCard}>
                  {others.length === 0 ? (
                    <Text style={[styles.noOthers, { color: c.inkSecondary }]}>{t('adminBrandsNoOthers')}</Text>
                  ) : (
                    others.map((b) => renderRow(b, null))
                  )}
                </Card>
              </View>
            </>
          )}
        </ScrollView>
      )}

      <BrandEditor
        visible={creating || editing != null}
        brand={editing}
        onClose={() => { setCreating(false); setEditing(null); }}
        onDone={async () => { setCreating(false); setEditing(null); await load(); }}
      />
    </SafeAreaView>
  );
}

// ─────────────────────────── Brand editor (create / edit) ───────────────────────────

function BrandEditor({
  visible, brand, onClose, onDone,
}: {
  visible: boolean; brand: AdminBrand | null; onClose: () => void; onDone: () => Promise<void>;
}) {
  const c = useTheme();
  const { t } = useI18n();

  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [tagline, setTagline] = useState('');
  // Icon: the already-saved public URL, plus an optional locally-picked uri that
  // hasn't been uploaded yet (uploaded on Save). The gradient+symbol is the
  // default fallback shown whenever there's no image.
  const [iconUrl, setIconUrl] = useState<string | null>(null);
  const [localIconUri, setLocalIconUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // Keep the existing default look (gradient + symbol) for brands without an icon.
  const fallbackColors: [string, string] = brand?.colors ?? ['#FF4D6D', '#FF9A5A'];
  const fallbackSymbol = brand?.symbol ?? 'sparkles';

  // Seed fields whenever the editor opens (edit → existing values, create → defaults).
  useEffect(() => {
    if (!visible) return;
    if (brand) {
      setName(brand.name);
      setCategory(brand.category);
      setTagline(brand.tagline);
      setIconUrl(brand.iconUrl ?? null);
    } else {
      setName(''); setCategory(''); setTagline(''); setIconUrl(null);
    }
    setLocalIconUri(null);
  }, [visible, brand]);

  const isEditing = brand != null;
  const canSave = name.trim().length > 0 && !busy;
  const previewUri = localIconUri ?? iconUrl;

  async function pickIcon() {
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });
    if (result.canceled || !result.assets.length) return;
    setLocalIconUri(result.assets[0].uri);
  }

  function removeIcon() {
    setLocalIconUri(null);
    setIconUrl(null);
  }

  async function save() {
    if (!canSave) return;
    setBusy(true);
    try {
      // Upsert first so a brand-new row has an id to key its icon path under,
      // then (if a fresh image was picked) upload it and re-save the URL.
      let finalIconUrl = iconUrl;
      const id = await api.adminUpsertBrand({
        id: brand?.id ?? null,
        name: name.trim(),
        category: category.trim() || null,
        tagline: tagline.trim() || null,
        featuredRank: brand?.featuredRank ?? null,
        iconUrl: finalIconUrl,
      });
      if (localIconUri) {
        finalIconUrl = await api.uploadDiscoverIcon('brands', id, localIconUri);
        await api.adminUpsertBrand({
          id,
          name: name.trim(),
          category: category.trim() || null,
          tagline: tagline.trim() || null,
          featuredRank: brand?.featuredRank ?? null,
          iconUrl: finalIconUrl,
        });
      }
      await onDone();
    } catch {
      notify(t('adminSaveError'));
    } finally {
      setBusy(false);
    }
  }

  async function del() {
    if (!brand || busy) return;
    const ok = await confirmAsync(t('adminDeleteBrand'), t('adminDeleteBrandConfirm'), {
      confirmLabel: t('adminDeleteBrand'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    try {
      await api.adminDeleteBrand(brand.id);
      await onDone();
    } catch {
      notify(t('adminSaveError'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={visible} animationType="slide" onRequestClose={onClose} transparent={false}>
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <NavBar
          title={isEditing ? t('adminEditBrand') : t('adminNewBrand')}
          onBack={onClose}
          backIcon="close"
          right={
            <Pressable onPress={save} disabled={!canSave} hitSlop={8}>
              <Text style={{ color: canSave ? c.coral : c.inkTertiary, fontSize: 16, fontWeight: '700' }}>{t('adminSave')}</Text>
            </Pressable>
          }
        />
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
          <ScrollView contentContainerStyle={styles.editorContent} keyboardShouldPersistTaps="handled">
            {/* Icon upload — image when set, default gradient+symbol otherwise. */}
            <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{t('adminUploadIcon').toUpperCase()}</Text>
            <View style={styles.iconRow}>
              <Pressable onPress={pickIcon} disabled={busy}>
                {previewUri ? (
                  <Image source={{ uri: previewUri }} style={styles.iconPreview} contentFit="cover" />
                ) : (
                  <LinearGradient
                    colors={fallbackColors}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.iconPreview}
                  >
                    <Ionicons name={iconFor(fallbackSymbol)} size={26} color="#fff" />
                  </LinearGradient>
                )}
              </Pressable>
              <View style={{ flex: 1 }}>
                <Pressable onPress={pickIcon} disabled={busy} hitSlop={6}>
                  <Text style={{ color: c.coral, fontSize: 14, fontWeight: '600' }}>
                    {previewUri ? t('adminChangeIcon') : t('adminUploadIcon')}
                  </Text>
                </Pressable>
                {previewUri ? (
                  <Pressable onPress={removeIcon} disabled={busy} hitSlop={6} style={{ marginTop: 8 }}>
                    <Text style={{ color: c.inkSecondary, fontSize: 13 }}>{t('adminRemoveIcon')}</Text>
                  </Pressable>
                ) : null}
                <Text style={[styles.iconHint, { color: c.inkTertiary }]}>{t('adminIconHint')}</Text>
              </View>
            </View>

            <FieldRow label={t('adminFieldName')} value={name} onChangeText={setName} />
            <FieldRow label={t('adminFieldCategory')} value={category} onChangeText={setCategory} />
            <FieldRow label={t('adminFieldTagline')} value={tagline} onChangeText={setTagline} />

            {isEditing ? (
              <Pressable
                onPress={del}
                disabled={busy}
                style={[styles.deleteBtn, { backgroundColor: c.danger + '1A' }]}
              >
                <Text style={{ color: c.danger, fontSize: 15, fontWeight: '700' }}>{t('adminDeleteBrand')}</Text>
              </Pressable>
            ) : null}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </Modal>
  );
}

/** A labelled single-line text input row (module-level so it isn't re-created
 *  every render — keeping a stable component identity avoids the input losing
 *  focus on each keystroke). */
function FieldRow({ label, value, onChangeText, keyboardType }: {
  label: string; value: string; onChangeText: (v: string) => void;
  keyboardType?: 'default' | 'number-pad';
}) {
  const c = useTheme();
  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{label.toUpperCase()}</Text>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        keyboardType={keyboardType ?? 'default'}
        autoCapitalize="none"
        autoCorrect={false}
        style={[styles.input, { color: c.ink, backgroundColor: c.card, borderColor: c.hairline }]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  content: { padding: 16, gap: 18, paddingBottom: 40 },
  empty: { alignItems: 'center', justifyContent: 'center', paddingVertical: 50, gap: 12 },
  emptyText: { fontSize: 14, fontWeight: '500', textAlign: 'center', paddingHorizontal: 30 },
  sectionTitle: { fontSize: 12, fontWeight: '700', letterSpacing: 1, marginLeft: 4, marginBottom: 8 },
  listCard: { paddingVertical: 4 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 12, paddingVertical: 10 },
  rowIcon: { width: 40, height: 40, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  rowTitle: { fontSize: 15, fontWeight: '600' },
  rowSub: { fontSize: 12, marginTop: 2 },
  arrow: { width: 30, height: 30, borderRadius: 15, alignItems: 'center', justifyContent: 'center' },
  action: { width: 32, height: 32, alignItems: 'center', justifyContent: 'center' },
  noOthers: { fontSize: 14, paddingHorizontal: 14, paddingVertical: 10 },

  editorContent: { padding: 18, paddingBottom: 40 },
  fieldLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 6 },
  input: { borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  iconRow: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 20 },
  iconPreview: { width: 64, height: 64, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  iconHint: { fontSize: 11.5, marginTop: 8 },
  deleteBtn: { marginTop: 18, alignItems: 'center', paddingVertical: 14, borderRadius: radius.pill },
});
