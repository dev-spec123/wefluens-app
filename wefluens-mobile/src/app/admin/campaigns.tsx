/**
 * Admin campaign management — create/edit/delete the "Open Campaigns" shown on
 * Discover, without an app update. Mirrors the Swift ManageCampaignsView.
 * Campaigns have no featured_rank — Discover shows every row. Writes go through
 * is_admin-gated RPCs (admin_upsert_campaign / admin_delete_campaign).
 */
import { Ionicons } from '@expo/vector-icons';
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
import { confirmAsync, notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';
import type { Campaign } from '@/lib/types';

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

/** Normalize a hex string for the gradient preview ("FF4D6D" → "#FF4D6D"). */
function hexColor(s: string, fallback: string): string {
  const cleaned = s.trim().replace(/^#/, '');
  return /^[0-9a-fA-F]{6}$/.test(cleaned) ? `#${cleaned.toUpperCase()}` : fallback;
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
        <LinearGradient colors={cm.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowIcon}>
          <Ionicons name={iconFor(cm.symbol)} size={16} color="#fff" />
        </LinearGradient>
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
  const [brand, setBrand] = useState('');
  const [budget, setBudget] = useState('');
  const [tags, setTags] = useState('');
  const [deadline, setDeadline] = useState('');
  const [symbol, setSymbol] = useState('sparkles');
  const [color1, setColor1] = useState('FF4D6D');
  const [color2, setColor2] = useState('FF9A5A');
  const [spotsLeft, setSpotsLeft] = useState('1');
  const [busy, setBusy] = useState(false);

  // Seed fields whenever the editor opens (edit → existing values, create → defaults).
  useEffect(() => {
    if (!visible) return;
    if (campaign) {
      setTitle(campaign.title);
      setBrand(campaign.brand);
      setBudget(campaign.budget);
      setTags(campaign.tags.join(', '));
      setDeadline(campaign.deadline);
      setSymbol(campaign.symbol);
      setColor1(campaign.colors[0].replace(/^#/, ''));
      setColor2(campaign.colors[1].replace(/^#/, ''));
      setSpotsLeft(String(campaign.spotsLeft));
    } else {
      setTitle(''); setBrand(''); setBudget(''); setTags(''); setDeadline('');
      setSymbol('sparkles'); setColor1('FF4D6D'); setColor2('FF9A5A'); setSpotsLeft('1');
    }
  }, [visible, campaign]);

  const isEditing = campaign != null;
  const canSave = title.trim().length > 0 && !busy;

  function parsedTags(): string[] {
    return tags.split(',').map((s) => s.trim()).filter((s) => s.length > 0);
  }

  async function save() {
    if (!canSave) return;
    setBusy(true);
    try {
      await api.adminUpsertCampaign({
        id: campaign?.id ?? null,
        title: title.trim(),
        brand: brand.trim() || null,
        budget: budget.trim() || null,
        tags: parsedTags(),
        deadline: deadline.trim() || null,
        symbol: symbol.trim() || 'sparkles',
        color1,
        color2,
        spotsLeft: spotsLeft.trim() ? parseInt(spotsLeft, 10) || 0 : 0,
      });
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

  function FieldRow({ label, value, onChangeText, keyboardType }: {
    label: string; value: string; onChangeText: (v: string) => void;
    keyboardType?: 'default' | 'number-pad';
  }) {
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
            <FieldRow label={t('adminFieldTitle')} value={title} onChangeText={setTitle} />
            <FieldRow label={t('adminFieldBrand')} value={brand} onChangeText={setBrand} />
            <FieldRow label={t('adminFieldBudget')} value={budget} onChangeText={setBudget} />
            <FieldRow label={t('adminFieldTags')} value={tags} onChangeText={setTags} />
            <FieldRow label={t('adminFieldDeadline')} value={deadline} onChangeText={setDeadline} />
            <FieldRow label={t('adminFieldSymbol')} value={symbol} onChangeText={setSymbol} />
            <View style={{ flexDirection: 'row', gap: 12 }}>
              <View style={{ flex: 1 }}>
                <FieldRow label={t('adminFieldColor1')} value={color1} onChangeText={setColor1} />
              </View>
              <View style={{ flex: 1 }}>
                <FieldRow label={t('adminFieldColor2')} value={color2} onChangeText={setColor2} />
              </View>
            </View>
            <FieldRow label={t('adminFieldSpotsLeft')} value={spotsLeft} onChangeText={setSpotsLeft} keyboardType="number-pad" />

            <View style={styles.previewRow}>
              <LinearGradient
                colors={[hexColor(color1, '#FF4D6D'), hexColor(color2, '#FF9A5A')]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.previewIcon}
              >
                <Ionicons name={iconFor(symbol)} size={22} color="#fff" />
              </LinearGradient>
              <Text style={[styles.previewLabel, { color: c.inkSecondary }]}>{t('adminPreview')}</Text>
            </View>

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
    </Modal>
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
  previewRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 4, marginBottom: 8 },
  previewIcon: { width: 52, height: 52, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  previewLabel: { fontSize: 13, fontWeight: '500' },
  deleteBtn: { marginTop: 18, alignItems: 'center', paddingVertical: 14, borderRadius: radius.pill },
});
