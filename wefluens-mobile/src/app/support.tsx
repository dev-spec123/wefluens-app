/**
 * Contact Support — in-app ticket form. Records a ticket and emails the support
 * inbox via the submit-support-ticket edge function. Mirrors the native Swift
 * SupportContactView: inline animated success state (green checkmark + message),
 * inline red error text, uppercase tracked field labels, and a sunset-gradient
 * pill send button with a coral glow.
 */
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, Vibration, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { submitSupportTicket } from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, useTheme } from '@/lib/theme';

export default function Support() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSend = subject.trim().length > 0 && body.trim().length > 0 && !busy;

  async function send() {
    if (!canSend) {
      setError(t('supportEmptyMsg'));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await submitSupportTicket(subject.trim(), body.trim());
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

          <Text style={[styles.label, { color: c.inkTertiary }]}>{t('supportSubject').toUpperCase()}</Text>
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
  error: { fontSize: 13, fontWeight: '500', marginTop: 14 },
  btnShadow: { borderRadius: radius.pill, shadowOpacity: 0.3, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 4 },
  btn: { borderRadius: radius.pill, paddingVertical: 15, alignItems: 'center', justifyContent: 'center' },
  btnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  sentWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32, gap: 18 },
  sentMsg: { fontSize: 16, fontWeight: '500', textAlign: 'center', lineHeight: 22 },
});
