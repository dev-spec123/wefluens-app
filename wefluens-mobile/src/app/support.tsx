/**
 * Contact Support — in-app ticket form. Records a ticket and emails the support
 * inbox via the submit-support-ticket edge function. Mirrors the native Swift
 * SupportContactView: inline animated success state (green checkmark + message),
 * inline red error text, uppercase tracked field labels, and a sunset-gradient
 * pill send button with a coral glow.
 *
 * Beyond subject + message it collects a TYPE (Bug / Idea / Other) and up to 6
 * image attachments (each ≤5MB). Images are compressed + base64-encoded inside
 * the api layer before being sent to the edge function.
 */
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, Vibration, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { submitSupportTicket, type SupportTicketType } from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, useTheme } from '@/lib/theme';

const MAX_IMAGES = 6;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5MB

type PickedImage = { uri: string; mime: string | null };

const TYPES: { key: SupportTicketType; labelKey: string }[] = [
  { key: 'bug', labelKey: 'supportTypeBug' },
  { key: 'idea', labelKey: 'supportTypeIdea' },
  { key: 'other', labelKey: 'supportTypeOther' },
];

export default function Support() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState<SupportTicketType>('other');
  const [images, setImages] = useState<PickedImage[]>([]);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSend = subject.trim().length > 0 && body.trim().length > 0 && !busy;

  async function pickImages() {
    setError(null);
    const remaining = MAX_IMAGES - images.length;
    if (remaining <= 0) {
      setError(t('supportMaxImages'));
      return;
    }
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: remaining,
      quality: 0.85,
    });
    if (result.canceled || !result.assets.length) return;

    const next: PickedImage[] = [];
    let tooLarge = false;
    for (const a of result.assets) {
      if (images.length + next.length >= MAX_IMAGES) break;
      // fileSize is the pre-compression size; over-limit picks are rejected up
      // front (the api layer compresses + enforces the cap again as a backstop).
      if (typeof a.fileSize === 'number' && a.fileSize > MAX_IMAGE_BYTES) {
        tooLarge = true;
        continue;
      }
      next.push({ uri: a.uri, mime: a.mimeType ?? null });
    }
    if (tooLarge) setError(t('supportImageTooLarge'));
    if (next.length) setImages((prev) => [...prev, ...next].slice(0, MAX_IMAGES));
  }

  function removeImage(uri: string) {
    setImages((prev) => prev.filter((im) => im.uri !== uri));
    setError(null);
  }

  async function send() {
    if (!canSend) {
      setError(t('supportEmptyMsg'));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await submitSupportTicket({
        subject: subject.trim(),
        body: body.trim(),
        type,
        images: images.map((im) => ({ uri: im.uri, mime: im.mime })),
      });
      // Tactile success confirmation, mirroring the Swift success haptic.
      // expo-haptics isn't a dependency; RN's built-in Vibration needs no native add.
      if (Platform.OS !== 'web') Vibration.vibrate(10);
      setSent(true);
    } catch {
      setError(t('supportErrorBody'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar
        title={t('supportTitle')}
        onBack={() => router.back()}
        right={
          <Pressable onPress={() => router.back()} hitSlop={8}>
            <Text style={{ color: c.coral, fontSize: 16, fontWeight: '600' }}>{t('settingsDone')}</Text>
          </Pressable>
        }
      />
      {sent ? (
        <Animated.View entering={FadeIn.duration(280)} style={styles.sentWrap}>
          <Ionicons name="checkmark-circle" size={52} color="#2AD17E" />
          <Text style={[styles.sentMsg, { color: c.inkSecondary }]}>{t('supportSentBody')}</Text>
        </Animated.View>
      ) : (
        <ScrollView contentContainerStyle={{ padding: 18 }} keyboardShouldPersistTaps="handled">
          <Text style={[styles.intro, { color: c.inkSecondary }]}>{t('supportIntro')}</Text>

          {/* Type selector — 3 segmented chips */}
          <Text style={[styles.label, { color: c.inkTertiary }]}>{t('supportType').toUpperCase()}</Text>
          <View style={styles.typeRow}>
            {TYPES.map((opt) => {
              const active = type === opt.key;
              return (
                <Pressable
                  key={opt.key}
                  onPress={() => setType(opt.key)}
                  style={[
                    styles.typeChip,
                    { borderColor: active ? c.coral : c.hairline, backgroundColor: active ? `${c.coral}1A` : c.card },
                  ]}
                >
                  <Text style={[styles.typeChipText, { color: active ? c.coral : c.inkSecondary }]}>
                    {t(opt.labelKey)}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          <Text style={[styles.label, { color: c.inkTertiary, marginTop: 16 }]}>{t('supportSubject').toUpperCase()}</Text>
          <TextInput
            value={subject}
            onChangeText={setSubject}
            placeholder={t('supportSubjectPlaceholder')}
            placeholderTextColor={c.inkTertiary}
            style={[styles.input, { backgroundColor: c.card, color: c.ink, borderColor: c.hairline }]}
            maxLength={200}
          />

          <Text style={[styles.label, { color: c.inkTertiary, marginTop: 16 }]}>{t('supportMessage').toUpperCase()}</Text>
          <TextInput
            value={body}
            onChangeText={setBody}
            placeholder={t('supportMessagePlaceholder')}
            placeholderTextColor={c.inkTertiary}
            style={[styles.input, styles.textarea, { backgroundColor: c.card, color: c.ink, borderColor: c.hairline }]}
            multiline
            maxLength={5000}
          />

          {/* Attachments */}
          <Text style={[styles.label, { color: c.inkTertiary, marginTop: 16 }]}>{t('supportAttachments').toUpperCase()}</Text>
          <View style={styles.thumbsRow}>
            {images.map((im) => (
              <View key={im.uri} style={styles.thumbWrap}>
                <Image source={{ uri: im.uri }} style={styles.thumb} contentFit="cover" />
                <Pressable
                  onPress={() => removeImage(im.uri)}
                  hitSlop={8}
                  style={styles.thumbRemove}
                  accessibilityLabel={t('supportRemoveImage')}
                >
                  <Ionicons name="close" size={14} color="#fff" />
                </Pressable>
              </View>
            ))}
            {images.length < MAX_IMAGES ? (
              <Pressable onPress={pickImages} style={[styles.addTile, { borderColor: c.hairline, backgroundColor: c.card }]}>
                <Ionicons name="add" size={26} color={c.coral} />
              </Pressable>
            ) : null}
          </View>
          <Text style={[styles.attachHint, { color: c.inkTertiary }]}>{t('supportMaxImages')}</Text>

          {error ? <Text style={[styles.error, { color: c.danger }]}>{error}</Text> : null}

          <Pressable onPress={send} disabled={!canSend} style={{ marginTop: 24 }}>
            <View style={[styles.btnShadow, { shadowColor: c.coral, opacity: canSend ? 1 : 0.55 }]}>
              <LinearGradient
                colors={gradients.sunset}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.btn}
              >
                {busy ? <ActivityIndicator color="#fff" /> : <Text style={styles.btnText}>{t('supportSend')}</Text>}
              </LinearGradient>
            </View>
          </Pressable>
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  intro: { fontSize: 14, lineHeight: 20, marginBottom: 18 },
  label: { fontSize: 12, fontWeight: '700', letterSpacing: 1, marginBottom: 8 },
  input: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  textarea: { minHeight: 160, textAlignVertical: 'top' },
  typeRow: { flexDirection: 'row', gap: 10 },
  typeChip: { flex: 1, borderWidth: 1, borderRadius: radius.pill, paddingVertical: 10, alignItems: 'center', justifyContent: 'center' },
  typeChipText: { fontSize: 14, fontWeight: '600' },
  thumbsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  thumbWrap: { width: 76, height: 76 },
  thumb: { width: 76, height: 76, borderRadius: radius.md },
  thumbRemove: {
    position: 'absolute', top: -6, right: -6, width: 22, height: 22, borderRadius: 11,
    backgroundColor: 'rgba(0,0,0,0.65)', alignItems: 'center', justifyContent: 'center',
  },
  addTile: { width: 76, height: 76, borderRadius: radius.md, borderWidth: 1, borderStyle: 'dashed', alignItems: 'center', justifyContent: 'center' },
  attachHint: { fontSize: 11.5, marginTop: 8 },
  error: { fontSize: 13, fontWeight: '500', marginTop: 14 },
  btnShadow: { borderRadius: radius.pill, shadowOpacity: 0.3, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 4 },
  btn: { borderRadius: radius.pill, paddingVertical: 15, alignItems: 'center', justifyContent: 'center' },
  btnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  sentWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32, gap: 18 },
  sentMsg: { fontSize: 16, fontWeight: '500', textAlign: 'center', lineHeight: 22 },
});
