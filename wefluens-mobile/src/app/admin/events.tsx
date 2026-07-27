/**
 * Admin event management — create/edit/delete events and PUBLISH them to the
 * Discover page, without an app update. Mirrors the Swift ManageEventsView.
 * The one concept beyond admin/campaigns.tsx: an event starts as a DRAFT and
 * only appears on Discover once published, so drafts get their own section and
 * saving an edit never changes the publish state (that's its own RPC).
 * Writes go through is_admin-gated RPCs.
 */
import { Ionicons } from '@expo/vector-icons';
import DateTimePicker, { type DateTimePickerEvent } from '@react-native-community/datetimepicker';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { type Href, useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Modal, Platform, Pressable, RefreshControl,
  ScrollView, StyleSheet, Switch, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, GradientButton, NavBar } from '@/components/ui';
import * as api from '@/lib/api';
import type { AdminBrand } from '@/lib/api';
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
    'gift.fill': 'gift', gift: 'gift', 'flame.fill': 'flame', flame: 'flame',
  };
  return map[symbol] ?? 'calendar';
}

/** Short display form for a row subtitle. */
function shortDate(raw: string | null, fallback: string): string {
  if (!raw) return fallback;
  const d = new Date(raw);
  if (isNaN(d.getTime())) return fallback;
  return d.toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

export default function ManageEvents() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [editing, setEditing] = useState<Event | null>(null);
  const [creating, setCreating] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setEvents(await api.loadEventsForAdmin());
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

  const drafts = events.filter((e) => !e.published);
  const published = events.filter((e) => e.published);

  async function togglePublished(event: Event) {
    if (busyId) return;
    setBusyId(event.id);
    try {
      await api.adminSetEventPublished(event.id, !event.published);
      await load();
    } catch {
      notify(t('adminPublishError'));
    } finally {
      setBusyId(null);
    }
  }

  /** "<date> · <location>" — whichever parts the event has. */
  function subtitle(event: Event): string {
    const parts = [shortDate(event.startsAt, t('adminNoDate'))];
    if (event.location) parts.push(event.location);
    return parts.join(' · ');
  }

  /** "<n> signed up", or "<n>/<capacity>" when capped — the fill level is what
   *  an admin actually wants at a glance. */
  function signupLabel(event: Event): string {
    if (event.capacity != null) return `${event.signupCount}/${event.capacity} ${t('adminSignedUpCount')}`;
    return `${event.signupCount} ${t('adminSignedUpCount')}`;
  }

  // Two lines: identity + edit on top, the actions (roster / publish) below —
  // three controls plus a title don't fit on one line at phone width.
  function renderRow(event: Event) {
    return (
      <View key={event.id} style={styles.rowWrap}>
        <Pressable
          onPress={() => setEditing(event)}
          style={({ pressed }) => [styles.row, pressed && { backgroundColor: c.cardSubtle }]}
        >
          {event.iconUrl ? (
            <Image source={{ uri: event.iconUrl }} style={styles.rowIcon} contentFit="cover" />
          ) : (
            <LinearGradient colors={event.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.rowIcon}>
              <Ionicons name={iconFor(event.symbol)} size={16} color="#fff" />
            </LinearGradient>
          )}
          <View style={{ flex: 1 }}>
            <Text style={[styles.rowTitle, { color: c.ink }]} numberOfLines={1}>{event.title}</Text>
            <Text style={[styles.rowSub, { color: c.inkSecondary }]} numberOfLines={1}>{subtitle(event)}</Text>
          </View>
          <Ionicons name="pencil" size={17} color={c.inkSecondary} />
        </Pressable>

        <View style={styles.rowActions}>
          {/* Roster — who signed up, not just how many. */}
          <Pressable
            onPress={() => router.push(`/admin/event-signups/${event.id}` as Href)}
            hitSlop={6}
            style={[styles.signupsBtn, { backgroundColor: c.coral + '1A' }]}
          >
            <Ionicons name="people" size={12} color={c.coral} />
            <Text style={{ color: c.coral, fontSize: 12, fontWeight: '600' }}>{signupLabel(event)}</Text>
            <Ionicons name="chevron-forward" size={11} color={c.coral} />
          </Pressable>

          {/* Publish / unpublish — the whole point of the draft gate, one tap away. */}
          <Pressable
            onPress={() => togglePublished(event)}
            disabled={busyId === event.id}
            hitSlop={6}
            style={[
              styles.publishBtn,
              event.published
                ? { backgroundColor: c.inkTertiary + '26' }
                : { backgroundColor: c.coral },
              busyId === event.id && { opacity: 0.6 },
            ]}
          >
            <Text style={{ color: event.published ? c.inkSecondary : '#fff', fontSize: 12, fontWeight: '700' }}>
              {event.published ? t('adminUnpublish') : t('adminPublish')}
            </Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('adminManageEvents')} onBack={() => router.back()} />
      {loading ? (
        <View style={styles.centered}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.content}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.coral} />}
        >
          <GradientButton title={`+ ${t('adminNewEvent')}`} onPress={() => setCreating(true)} style={{ marginBottom: 4 }} />

          {events.length === 0 ? (
            <View style={styles.empty}>
              <Ionicons name="calendar" size={40} color={c.inkTertiary} />
              <Text style={[styles.emptyText, { color: c.inkSecondary }]}>{t('adminNoEvents')}</Text>
            </View>
          ) : (
            <>
              {drafts.length > 0 ? (
                <View>
                  <Text style={[styles.sectionTitle, { color: c.inkTertiary }]}>
                    {t('adminEventsDrafts').toUpperCase()}
                  </Text>
                  <Card style={styles.listCard}>{drafts.map(renderRow)}</Card>
                </View>
              ) : null}
              {published.length > 0 ? (
                <View>
                  <Text style={[styles.sectionTitle, { color: c.inkTertiary }]}>
                    {t('adminEventsPublished').toUpperCase()}
                  </Text>
                  <Card style={styles.listCard}>{published.map(renderRow)}</Card>
                </View>
              ) : null}
            </>
          )}
        </ScrollView>
      )}

      <EventEditor
        visible={creating || editing != null}
        event={editing}
        onClose={() => { setCreating(false); setEditing(null); }}
        onDone={async () => { setCreating(false); setEditing(null); await load(); }}
      />
    </SafeAreaView>
  );
}

// ─────────────────────────── Event editor (create / edit) ───────────────────────────

function EventEditor({
  visible, event, onClose, onDone,
}: {
  visible: boolean; event: Event | null; onClose: () => void; onDone: () => Promise<void>;
}) {
  const c = useTheme();
  const { t } = useI18n();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [tags, setTags] = useState('');
  // Lazy initializers: these are placeholders until the seed effect fills them
  // from the event being edited, so they shouldn't re-evaluate on every render.
  const [startsAt, setStartsAt] = useState<Date>(() => new Date());
  const [endsAt, setEndsAt] = useState<Date>(() => new Date(Date.now() + 2 * 3600 * 1000));
  // Capacity is optional: off = uncapped (the app hides the spots figure).
  const [hasCapacity, setHasCapacity] = useState(true);
  const [capacity, setCapacity] = useState('20');
  const [brandId, setBrandId] = useState<string | null>(null);
  const [brandName, setBrandName] = useState('');
  const [iconUrl, setIconUrl] = useState<string | null>(null);
  const [localIconUri, setLocalIconUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [brands, setBrands] = useState<AdminBrand[]>([]);
  const [showBrandPicker, setShowBrandPicker] = useState(false);

  const fallbackColors: [string, string] = event?.colors ?? ['#FF4D6D', '#FF9A5A'];
  const fallbackSymbol = event?.symbol ?? 'calendar';

  // Seed fields whenever the editor opens (edit → existing values, create → defaults).
  useEffect(() => {
    if (!visible) return;
    if (event) {
      setTitle(event.title);
      setDescription(event.description);
      setLocation(event.location);
      setTags(event.tags.join(', '));
      setStartsAt(event.startsAt ? new Date(event.startsAt) : new Date());
      setEndsAt(event.endsAt ? new Date(event.endsAt) : new Date(Date.now() + 2 * 3600 * 1000));
      setHasCapacity(event.capacity != null);
      setCapacity(event.capacity != null ? String(event.capacity) : '20');
      setBrandId(event.brandId);
      setBrandName(event.brand);
      setIconUrl(event.iconUrl ?? null);
    } else {
      setTitle(''); setDescription(''); setLocation(''); setTags('');
      setStartsAt(new Date()); setEndsAt(new Date(Date.now() + 2 * 3600 * 1000));
      setHasCapacity(true); setCapacity('20');
      setBrandId(null); setBrandName(''); setIconUrl(null);
    }
    setLocalIconUri(null);
    setShowBrandPicker(false);
    api.loadBrandsForAdmin().then(setBrands).catch(() => setBrands([]));
  }, [visible, event]);

  const isEditing = event != null;
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

  /** The upsert payload, shared by the initial save and the post-upload rewrite. */
  function payload(id: string | null, icon: string | null) {
    return {
      id,
      title: title.trim(),
      description: description.trim() || null,
      location: location.trim() || null,
      startsAt: startsAt.toISOString(),
      endsAt: endsAt.toISOString(),
      capacity: hasCapacity ? (parseInt(capacity, 10) || 0) : null,
      tags: parsedTags(),
      brand: brandName.trim() || null,
      brandId,
      iconUrl: icon,
    };
  }

  async function save() {
    if (!canSave) return;
    setBusy(true);
    try {
      const id = await api.adminUpsertEvent(payload(event?.id ?? null, iconUrl));
      if (localIconUri) {
        const url = await api.uploadDiscoverIcon('events', id, localIconUri);
        await api.adminUpsertEvent(payload(id, url));
      }
      await onDone();
    } catch {
      notify(t('adminSaveError'));
    } finally {
      setBusy(false);
    }
  }

  async function del() {
    if (!event || busy) return;
    const ok = await confirmAsync(t('adminDeleteEvent'), t('adminDeleteEventConfirm'), {
      confirmLabel: t('adminDeleteEvent'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setBusy(true);
    try {
      await api.adminDeleteEvent(event.id);
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
          title={isEditing ? t('adminEditEvent') : t('adminNewEvent')}
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

            <FieldRow label={t('adminFieldLocation')} value={location} onChangeText={setLocation} />
            <FieldRow label={t('adminFieldTags')} value={tags} onChangeText={setTags} />

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

            <DateTimeField label={t('adminFieldStartsAt')} value={startsAt} onChange={setStartsAt} />
            <DateTimeField label={t('adminFieldEndsAt')} value={endsAt} onChange={setEndsAt} />

            {/* Capacity: a switch for capped/uncapped plus the number when capped. */}
            <View style={{ marginBottom: 14 }}>
              <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{t('adminFieldCapacity').toUpperCase()}</Text>
              <View style={[styles.capacityBox, { backgroundColor: c.card, borderColor: c.hairline }]}>
                <View style={styles.capacityRow}>
                  <Text style={{ color: c.ink, fontSize: 15, flex: 1 }}>{t('adminLimitParticipants')}</Text>
                  <Switch
                    value={hasCapacity}
                    onValueChange={setHasCapacity}
                    trackColor={{ true: c.coral }}
                  />
                </View>
                {hasCapacity ? (
                  <>
                    <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline }} />
                    <TextInput
                      value={capacity}
                      onChangeText={setCapacity}
                      keyboardType="number-pad"
                      style={{ color: c.ink, fontSize: 16, paddingHorizontal: 14, paddingVertical: 12 }}
                    />
                  </>
                ) : null}
              </View>
            </View>

            {/* Publish state is read-only here — saving an edit must never flip it. */}
            {isEditing ? (
              <View style={[styles.publishNote, { backgroundColor: c.card, borderColor: c.hairline }]}>
                <Ionicons
                  name={event?.published ? 'checkmark-circle' : 'create-outline'}
                  size={16}
                  color={event?.published ? c.coral : c.inkTertiary}
                />
                <Text style={{ color: c.inkSecondary, fontSize: 13, flex: 1 }}>
                  {event?.published ? t('adminEventIsPublished') : t('adminEventIsDraft')}
                </Text>
              </View>
            ) : (
              <Text style={{ color: c.inkSecondary, fontSize: 12.5, lineHeight: 18 }}>
                {t('adminEventDraftHint')}
              </Text>
            )}

            {isEditing ? (
              <Pressable
                onPress={del}
                disabled={busy}
                style={[styles.deleteBtn, { backgroundColor: c.danger + '1A' }]}
              >
                <Text style={{ color: c.danger, fontSize: 15, fontWeight: '700' }}>{t('adminDeleteEvent')}</Text>
              </Pressable>
            ) : null}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>

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

/** A date+time field. iOS gets one inline datetime picker; Android has no
 *  datetime mode, so it chains its native date picker into the time picker. */
function DateTimeField({
  label, value, onChange,
}: { label: string; value: Date; onChange: (d: Date) => void }) {
  const c = useTheme();
  const { t } = useI18n();
  const [show, setShow] = useState(false);
  const [androidMode, setAndroidMode] = useState<'date' | 'time'>('date');

  function onPickerChange(e: DateTimePickerEvent, picked?: Date) {
    if (Platform.OS !== 'android') {
      if (e.type === 'set' && picked) onChange(picked);
      return;
    }
    // Android fires once per step and auto-dismisses.
    if (e.type !== 'set' || !picked) { setShow(false); setAndroidMode('date'); return; }
    if (androidMode === 'date') {
      // Keep the existing clock time, then ask for the new time.
      const merged = new Date(picked);
      merged.setHours(value.getHours(), value.getMinutes(), 0, 0);
      onChange(merged);
      setAndroidMode('time');
      return;
    }
    const merged = new Date(value);
    merged.setHours(picked.getHours(), picked.getMinutes(), 0, 0);
    onChange(merged);
    setShow(false);
    setAndroidMode('date');
  }

  return (
    <View style={{ marginBottom: 14 }}>
      <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{label.toUpperCase()}</Text>
      <Pressable
        onPress={() => { setAndroidMode('date'); setShow(true); }}
        style={[styles.input, styles.pickerInput, { backgroundColor: c.card, borderColor: c.hairline }]}
      >
        <Text style={{ color: c.ink, fontSize: 16, flex: 1 }}>
          {value.toLocaleString(undefined, {
            month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit',
          })}
        </Text>
        <Ionicons name="calendar-outline" size={18} color={c.inkTertiary} />
      </Pressable>

      {show && Platform.OS === 'ios' ? (
        <View style={{ marginTop: 8 }}>
          <DateTimePicker value={value} mode="datetime" display="spinner" onChange={onPickerChange} />
          <Pressable onPress={() => setShow(false)} style={{ alignSelf: 'flex-end', paddingVertical: 6 }}>
            <Text style={{ color: c.coral, fontSize: 15, fontWeight: '700' }}>{t('adminPickDate')}</Text>
          </Pressable>
        </View>
      ) : null}

      {show && Platform.OS === 'android' ? (
        <DateTimePicker value={value} mode={androidMode} display="default" onChange={onPickerChange} />
      ) : null}
    </View>
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
  rowWrap: { paddingBottom: 6 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 12, paddingVertical: 10 },
  rowActions: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8, paddingLeft: 62, paddingRight: 12, paddingBottom: 6 },
  signupsBtn: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingHorizontal: 10, paddingVertical: 6, borderRadius: radius.pill },
  rowIcon: { width: 40, height: 40, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  rowTitle: { fontSize: 15, fontWeight: '600' },
  rowSub: { fontSize: 12, marginTop: 2 },
  publishBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: radius.pill },

  editorContent: { padding: 18, paddingBottom: 40 },
  fieldLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 1, marginBottom: 6 },
  input: { borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  multiline: { minHeight: 88, paddingTop: 12, textAlignVertical: 'top' },
  pickerInput: { flexDirection: 'row', alignItems: 'center' },
  capacityBox: { borderWidth: 1, borderRadius: radius.sm, overflow: 'hidden' },
  capacityRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 8, gap: 10 },
  publishNote: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 14, paddingVertical: 11,
  },
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
