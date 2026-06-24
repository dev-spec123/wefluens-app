import { useRouter } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { submitSupportTicket } from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

export default function Support() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);

  const canSend = subject.trim().length > 0 && body.trim().length > 0 && !busy;

  async function send() {
    if (!canSend) return;
    setBusy(true);
    try {
      await submitSupportTicket(subject.trim(), body.trim());
      Alert.alert(t('supportSentTitle'), t('supportSentBody'));
      router.back();
    } catch {
      Alert.alert(t('supportErrorTitle'), t('supportErrorBody'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('supportTitle')} onBack={() => router.back()} />
      <ScrollView contentContainerStyle={{ padding: 18 }} keyboardShouldPersistTaps="handled">
        <Text style={[styles.intro, { color: c.inkSecondary }]}>{t('supportIntro')}</Text>

        <Text style={[styles.label, { color: c.inkSecondary }]}>{t('supportSubject')}</Text>
        <TextInput
          value={subject}
          onChangeText={setSubject}
          placeholder={t('supportSubjectPlaceholder')}
          placeholderTextColor={c.inkTertiary}
          style={[styles.input, { backgroundColor: c.card, color: c.ink, borderColor: c.hairline }]}
          maxLength={200}
        />

        <Text style={[styles.label, { color: c.inkSecondary, marginTop: 16 }]}>{t('supportMessage')}</Text>
        <TextInput
          value={body}
          onChangeText={setBody}
          placeholder={t('supportMessagePlaceholder')}
          placeholderTextColor={c.inkTertiary}
          style={[styles.input, styles.textarea, { backgroundColor: c.card, color: c.ink, borderColor: c.hairline }]}
          multiline
          maxLength={5000}
        />

        <Pressable onPress={send} disabled={!canSend} style={[styles.btn, { backgroundColor: c.coral, opacity: canSend ? 1 : 0.5 }]}>
          {busy ? <ActivityIndicator color="#fff" /> : <Text style={styles.btnText}>{t('supportSend')}</Text>}
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  intro: { fontSize: 14, lineHeight: 20, marginBottom: 18 },
  label: { fontSize: 13, fontWeight: '600', marginBottom: 6 },
  input: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 14, paddingVertical: 12, fontSize: 16 },
  textarea: { minHeight: 140, textAlignVertical: 'top' },
  btn: { marginTop: 24, borderRadius: radius.md, paddingVertical: 15, alignItems: 'center' },
  btnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
});
