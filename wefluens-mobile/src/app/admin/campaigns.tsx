/**
 * Admin campaign management — create/edit/delete the "Open Campaigns" shown on
 * Discover, without an app update. Mirrors the Swift ManageCampaignsView.
 * Campaigns have no featured_rank — Discover shows every row. Writes go through
 * is_admin-gated RPCs (admin_upsert_campaign / admin_delete_campaign).
 */
import { Ionicons } from '@expo/vector-icons';
import DateTimePicker, { type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
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
import type { Campaign } from '@/lib/types';

/** Format a Date as an ISO "YYYY-MM-DD" calendar string (local, no time/zone). */
function toISODate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Parse an ISO "YYYY-MM-DD" string back into a local Date (noon to dodge DST
 *  edge cases); falls back to today when missing/invalid. */
function fromISODate(s: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s.trim());
  if (m) return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12, 0, 0);
  return new Date();
}

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

export default function ManageCampaigns() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [editing, setEditing] = useState<Campaign | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    try {
      setCampaigns(await api.loadCampaignsForAdmin());
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

  function subtitle(cm: Campaign): string {
    const brand = cm.brand && cm.brand.length ? cm.brand : '—';
    return `${brand} · ${cm.spotsLeft} ${t('discoverSpotsLeft')}`;
  }

  function renderRow(cm: Campaign) {
    return (
      <Pressable key={cm.id} onPress={() => setEditing(cm)} style={({ pressed }) => [styles.row, pressed && { backgroundColor: c.cardSubtle }]}>
        {cm.iconUrl ? (
          <Image source={{ uri: cm.iconUrl }} style={styles.rowIcon} contentFit="cover" />
        ) : (
          <LinearGradient colors={cm.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowIcon}>
            <Ionicons name={iconFor(cm.symbol)} size={16} color="#fff" />
          </LinearGradient>
        )}
        <View style={{ flex: 1 }}>
          <Text style={[styles.rowTitle, { color: c.ink }]} numberOfLines={1}>{cm.title}</Text>
          <Text style={[styles.rowSub, { color: c.inkSecondary }]} numberOfLines={1}>{subtitle(cm)}</Text>
        </View>
        <Ionicons name="pencil" size={17} color={c.inkSecondary} />
      </Pressable>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('adminManageCampaigns')} onBack={() => router.back()} />
      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.content}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />}
        >
          <GradientButton title={`+ ${t('adminNewCampaign')}`} onPress={() => setCreating(true)} style={{ marginBottom: 4 }} />

          {campaigns.length === 0 ? (
            <View style={styles.empty}>
              <Ionicons name="megaphone" size={40} color={c.inkTertiary} />
              <Text style={[styles.emptyText, { color: c.inkSecondary }]}>{t('adminNoCampaigns')}</Text>
            </View>
          ) : (
            <View>
              <Text style={[styles.sectionTitle, { color: c.inkTertiary }]}>{t('adminCampaignsOpen').toUpperCase()}</Text>
              <Card style={styles.listCard}>
                {campaigns.map(renderRow)}
              </Card>
            </View>
          )}
        </ScrollView>
      )}

      <CampaignEditor
        visible={creating || editing != null}
        campaign={editing}
        onClose={() => { setCreating(false); setEditing(null); }}
        onDone={async () => { setCreating(false); setEditing(null); await load(); }}
      />
    </SafeAreaView>
  );
}

// ─────────────────────────── Campaign editor (create / edit) ───────────────────────────

function CampaignEditor({
  visible, campaign, onClose, onDone,
}: {
  visible: boolean; campaign: Campaign | null; onClose: () => void; onDone: () => Promise<void>;
}) {
  const c = useTheme();
  const { t } = useI18n();

  const [title, setTitle] = useState('');
  const [budget, setBudget] = useState('');
  const [tags, setTags] = useState('');
  const [description, setDescription] = useState('');
  const [deadline, setDeadline] = useState(''); // ISO "YYYY-MM-DD"
  const [spotsLeft, setSpotsLeft] = useState('1');
  // Owning brand (chosen from a picker, not free text) → sets both id + name.
  const [brandId, setBrandId] = useState<string | null>(null);
  const [brandName, setBrandName] = useState('');
  // Icon: saved URL + an optional locally-picked uri (uploaded on Save).
  const [iconUrl, setIconUrl] = useState<string | null>(null);
  const [localIconUri, setLocalIconUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [brands, setBrands] = useState<AdminBrand[]>([]);
  const [showBrandPicker, setShowBrandPicker] = useState(false);
  const [showDatePicker, setShowDatePicker] = useState(false);

  const fallbackColors: [string, string] = campaign?.colors ?? ['#FF4D6D', '#FF9A5A'];
  const fallbackSymbol = campaign?.symbol ?? 'sparkles';

  // Seed fields whenever the editor opens (edit → existing values, create → defaults).
  useEffect(() => {
    if (!visible) return;
    if (campaign) {
      setTitle(campaign.title);
      setBudget(campaign.budget);
      setTags(campaign.tags.join(', '));
      setDescription(campaign.description);
      setDeadline(campaign.deadline);
      setSpotsLeft(String(campaign.spotsLeft));
      setBrandId(campaign.brandId);
      setBrandName(campaign.brand);
      setIconUrl(campaign.iconUrl ?? null);
    } else {
      setTitle(''); setBudget(''); setTags(''); setDescription(''); setDeadline('');
      setSpotsLeft('1'); setBrandId(null); setBrandName(''); setIconUrl(null);
    }
    setLocalIconUri(null);
    setShowBrandPicker(false);
    setShowDatePicker(false);
    // Load brands for the picker (best-effort; an empty list shows an empty state).
    api.loadBrandsForAdmin().then(setBrands).catch(() => setBrands([]));
  }, [visible, campaign]);

  const isEditing = campaign != null;
  const canSave = title.trim().length > 0 && !busy;
  const previewUri = localIconUri ?? iconUrl;

  function parsedTags(): string[] {
    return tags.split(',').map((s) => s.trim()).filter((s) => s.length > 0);
  }

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

  function onDateChange(event: DateTimePickerEvent, date?: Date) {
    // Android fires once then auto-dismisses; iOS stays inline until the user
    // taps Done. Either way, 'set' carries the chosen date.
    if (Platform.OS === 'android') setShowDatePicker(false);
    if (event.type === 'set' && date) setDeadline(toISODate(date));
  }

  async function save() {
    if (!canSave) return;
    setBusy(true);
    try {
      let finalIconUrl = iconUrl;
      const id = await api.adminUpsertCampaign({
        id: campaign?.id ?? null,
        title: title.trim(),
        brand: brandName.trim() || null,
        brandId,
        budget: budget.trim() || null,
        tags: parsedTags(),
        deadline: deadline.trim() || null,
        description: description.trim() || null,
        spotsLeft: spotsLeft.trim() ? parseInt(spotsLeft, 10) || 0 : 0,
        iconUrl: finalIconUrl,
      });
      if (localIconUri) {
        finalIconUrl = await api.uploadDiscoverIcon('campaigns', id, localIconUri);
        await api.adminUpsertCampaign({
          id,
          title: title.trim(),
          brand: brandName.trim() || null,
          brandId,
          budget: budget.trim() || null,
          tags: parsedTags(),
          deadline: deadline.trim() || null,
          description: description.trim() || null,
          spotsLeft: spotsLeft.trim() ? parseInt(spotsLeft, 10) || 0 : 0,
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
    if (!campaign || busy) return;
    const ok = await confirmAsync(t('adminDeleteCampaign'), t('adminDeleteCampaignConfirm'), {
      confirmLabel: t('adminDeleteCampaign'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    try {
      await api.adminDeleteCampaign(campaign.id);
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
          title={isEditing ? t('adminEditCampaign') : t('adminNewCampaign')}
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

            <FieldRow label={t('adminFieldTitle')} value={title} onChangeText={setTitle} />

            {/* Brand picker (selecting sets brandId + name; not free text). */}
            <View style={{ marginBottom: 14 }}>
              <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{t('adminPickBrand').toUpperCase()}</Text>
              <Pressable
                onPress={() => setShowBrandPicker(true)}
                style={[styles.input, styles.pickerInput, { backgroundColor: c.card, borderColor: c.hairline }]}
              >
                <Text style={{ color: brandName ? c.ink : c.inkTertiary, fontSize: 16, flex: 1 }} numberOfLines={1}>
                  {brandName || t('adminPickBrandNone')}
                </Text>
                <Ionicons name="chevron-down" size={18} color={c.inkTertiary} />
              </Pressable>
            </View>

            <FieldRow label={t('adminFieldBudget')} value={budget} onChangeText={setBudget} />
            <FieldRow label={t('adminFieldTags')} value={tags} onChangeText={setTags} />

            {/* Deadline date picker (stores an ISO YYYY-MM-DD string). */}
            <View style={{ marginBottom: 14 }}>
              <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{t('adminPickDeadline').toUpperCase()}</Text>
              <Pressable
                onPress={() => setShowDatePicker(true)}
                style={[styles.input, styles.pickerInput, { backgroundColor: c.card, borderColor: c.hairline }]}
              >
                <Text style={{ color: deadline ? c.ink : c.inkTertiary, fontSize: 16, flex: 1 }}>
                  {deadline || t('adminPickDeadlineNone')}
                </Text>
                <Ionicons name="calendar-outline" size={18} color={c.inkTertiary} />
              </Pressable>
              {showDatePicker && Platform.OS === 'ios' ? (
                <View style={{ marginTop: 8 }}>
                  <DateTimePicker
                    value={fromISODate(deadline)}
                    mode="date"
                    display="inline"
                    onChange={onDateChange}
                  />
                  <Pressable onPress={() => setShowDatePicker(false)} style={{ alignSelf: 'flex-end', paddingVertical: 6 }}>
                    <Text style={{ color: c.coral, fontSize: 15, fontWeight: '700' }}>{t('adminPickDate')}</Text>
                  </Pressable>
                </View>
              ) : null}
              {showDatePicker && Platform.OS !== 'ios' ? (
                <DateTimePicker
                  value={fromISODate(deadline)}
                  mode="date"
                  display="default"
                  onChange={onDateChange}
                />
              ) : null}
            </View>

            {/* Multi-line description. */}
            <View style={{ marginBottom: 14 }}>
              <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{t('adminFieldDescription').toUpperCase()}</Text>
              <TextInput
                value={description}
                onChangeText={setDescription}
                multiline
                style={[styles.input, styles.multiline, { color: c.ink, backgroundColor: c.card, borderColor: c.hairline }]}
              />
            </View>

            <FieldRow label={t('adminFieldSpotsLeft')} value={spotsLeft} onChangeText={setSpotsLeft} keyboardType="number-pad" />

            {isEditing ? (
              <Pressable
                onPress={del}
                disabled={busy}
                style={[styles.deleteBtn, { backgroundColor: c.danger + '1A' }]}
              >
                <Text style={{ color: c.danger, fontSize: 15, fontWeight: '700' }}>{t('adminDeleteCampaign')}</Text>
              </Pressable>
            ) : null}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>

      {/* Brand picker sheet. */}
      <BrandPickerSheet
        visible={showBrandPicker}
        brands={brands}
        selectedId={brandId}
        onClose={() => setShowBrandPicker(false)}
        onPick={(b) => { setBrandId(b.id); setBrandName(b.name); setShowBrandPicker(false); }}
      />
    </Modal>
  );
}

// ─────────────────────────── Brand picker sheet ───────────────────────────

function BrandPickerSheet({
  visible, brands, selectedId, onClose, onPick,
}: {
  visible: boolean; brands: AdminBrand[]; selectedId: string | null;
  onClose: () => void; onPick: (b: AdminBrand) => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <Pressable style={styles.sheetBackdrop} onPress={onClose}>
        <Pressable style={[styles.sheet, { backgroundColor: c.paper }]} onPress={(e) => e.stopPropagation()}>
          <View style={styles.sheetHeader}>
            <Text style={[styles.sheetTitle, { color: c.ink }]}>{t('adminPickBrandNone')}</Text>
            <Pressable onPress={onClose} hitSlop={8}>
              <Ionicons name="close" size={22} color={c.inkSecondary} />
            </Pressable>
          </View>
          {brands.length === 0 ? (
            <Text style={[styles.sheetEmpty, { color: c.inkSecondary }]}>{t('adminPickBrandEmpty')}</Text>
          ) : (
            <ScrollView style={{ maxHeight: 380 }}>
              {brands.map((b) => (
                <Pressable
                  key={b.id}
                  onPress={() => onPick(b)}
                  style={({ pressed }) => [styles.sheetRow, pressed && { backgroundColor: c.cardSubtle }]}
                >
                  {b.iconUrl ? (
                    <Image source={{ uri: b.iconUrl }} style={styles.sheetRowIcon} contentFit="cover" />
                  ) : (
                    <LinearGradient colors={b.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.sheetRowIcon}>
                      <Ionicons name={iconFor(b.symbol)} size={15} color="#fff" />
                    </LinearGradient>
                  )}
                  <Text style={[styles.sheetRowText, { color: c.ink }]} numberOfLines={1}>{b.name}</Text>
                  {b.id === selectedId ? <Ionicons name="checkmark" size={20} color={c.coral} /> : null}
                </Pressable>
              ))}
            </ScrollView>
          )}
        </Pressable>
      </Pressable>
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

  editorContent: { padding: 18, paddingBottom: 40 },
  fieldLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 6 },
  input: { borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  multiline: { minHeight: 88, paddingTop: 12, textAlignVertical: 'top' },
  pickerInput: { flexDirection: 'row', alignItems: 'center' },
  iconRow: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 20 },
  iconPreview: { width: 64, height: 64, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  iconHint: { fontSize: 11.5, marginTop: 8 },
  deleteBtn: { marginTop: 18, alignItems: 'center', paddingVertical: 14, borderRadius: radius.pill },

  sheetBackdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  sheet: { borderTopLeftRadius: 20, borderTopRightRadius: 20, paddingHorizontal: 16, paddingTop: 14, paddingBottom: 30 },
  sheetHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8, paddingHorizontal: 4 },
  sheetTitle: { fontSize: 17, fontWeight: '700' },
  sheetEmpty: { fontSize: 14, paddingHorizontal: 4, paddingVertical: 24, textAlign: 'center' },
  sheetRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 6, paddingVertical: 12 },
  sheetRowIcon: { width: 34, height: 34, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  sheetRowText: { flex: 1, fontSize: 15, fontWeight: '600' },
});
