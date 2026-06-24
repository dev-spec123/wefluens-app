import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuth } from '@/context/AuthContext';
import { getSavedCredentials, saveCredentials } from '@/lib/credentials';
import { useI18n } from '@/lib/i18n';
import { gradients, radius } from '@/lib/theme';

const MIN_PW = 8;

export default function SignIn() {
  const { t } = useI18n();
  const { signIn, signUp, sendPasswordReset } = useAuth();
  const router = useRouter();

  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [checkEmail, setCheckEmail] = useState(false);

  // Pre-fill the remembered email + password (saved on a previous sign-in).
  useEffect(() => {
    let active = true;
    getSavedCredentials().then((c) => {
      if (active && c) { setEmail(c.email); setPassword(c.password); }
    });
    return () => { active = false; };
  }, []);

  const validEmail = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v.trim());
  const canSubmit = isSignUp
    ? !!email && password.length >= MIN_PW && confirm === password && agreed
    : !!email && !!password;

  async function submit() {
    setError(null);
    if (!validEmail(email)) { setError(t('authErrInvalidEmail')); return; }
    if (isSignUp) {
      if (password.length < MIN_PW) { setError(t('authErrPasswordShort')); return; }
      if (confirm !== password) { setError(t('authPasswordMismatch')); return; }
      if (!agreed) return;
    } else if (!password) { setError(t('authErrPasswordRequired')); return; }

    setBusy(true);
    try {
      if (isSignUp) {
        const { needsConfirmation } = await signUp(email, password, agreed);
        if (needsConfirmation) setCheckEmail(true);
      } else {
        await signIn(email, password);
        await saveCredentials(email.trim(), password);
      }
    } catch (e: any) {
      setError(e?.message ?? t('authErrGeneric'));
    } finally {
      setBusy(false);
    }
  }

  async function forgot() {
    if (!validEmail(email)) { setError(t('authErrInvalidEmail')); return; }
    try {
      await sendPasswordReset(email);
      setError(null);
      alert(t('authResetSentMessage'));
    } catch (e: any) {
      setError(e?.message ?? t('authErrGeneric'));
    }
  }

  return (
    <LinearGradient colors={gradients.dusk} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ flex: 1 }}>
      <SafeAreaView style={{ flex: 1 }}>
        <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
          <ScrollView
            contentContainerStyle={styles.scroll}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="interactive"
            showsVerticalScrollIndicator={false}
          >
            <View style={styles.logo}>
              <Ionicons name="sparkles" size={40} color="#fff" />
            </View>
            <Text style={styles.title}>Wefluens Connect</Text>

            {checkEmail ? (
              <View style={{ alignItems: 'center', marginTop: 24 }}>
                <Text style={styles.tagline}>{t('authCheckEmailTitle')}</Text>
                <Text style={[styles.tagline, { marginTop: 8 }]}>{t('authCheckEmailMessage')}</Text>
                <Text style={[styles.title, { fontSize: 16, marginTop: 6 }]}>{email}</Text>
                <Pressable style={[styles.submit, { marginTop: 28 }]} onPress={() => { setCheckEmail(false); setIsSignUp(false); setPassword(''); setConfirm(''); }}>
                  <Text style={styles.submitText}>{t('authBackToSignIn')}</Text>
                </Pressable>
              </View>
            ) : (
              <>
                <Text style={styles.tagline}>{t('authTagline')}</Text>

                <View style={{ marginTop: 28, gap: 12 }}>
                  <DarkField icon="mail" placeholder={t('authEmailPlaceholder')} value={email} onChangeText={(v) => { setEmail(v); setError(null); }} keyboardType="email-address" autoCapitalize="none" autoCorrect={false} />
                  <DarkField icon="lock-closed" placeholder={t('authPasswordPlaceholder')} value={password} onChangeText={(v) => { setPassword(v); setError(null); }} secureTextEntry />
                  {isSignUp && (
                    <DarkField icon="lock-closed" placeholder={t('authConfirmPasswordPlaceholder')} value={confirm} onChangeText={setConfirm} secureTextEntry />
                  )}

                  {error && (
                    <View style={styles.errorBox}>
                      <Ionicons name="warning" size={14} color="#fff" />
                      <Text style={styles.errorText}>{error}</Text>
                    </View>
                  )}

                  {isSignUp && (
                    <View style={styles.agreeRow}>
                      <Pressable onPress={() => setAgreed((a) => !a)} hitSlop={8}>
                        <Ionicons name={agreed ? 'checkbox' : 'square-outline'} size={22} color="#fff" />
                      </Pressable>
                      <View style={{ flex: 1 }}>
                        <Text style={styles.agreeText}>{t('authAgreePrefix')}</Text>
                        <View style={{ flexDirection: 'row', gap: 6, marginTop: 2 }}>
                          <Pressable onPress={() => router.push({ pathname: '/legal', params: { doc: 'terms' } })}>
                            <Text style={styles.link}>{t('legalTerms')}</Text>
                          </Pressable>
                          <Text style={{ color: 'rgba(255,255,255,0.5)' }}>·</Text>
                          <Pressable onPress={() => router.push({ pathname: '/legal', params: { doc: 'guidelines' } })}>
                            <Text style={styles.link}>{t('legalGuidelines')}</Text>
                          </Pressable>
                        </View>
                      </View>
                    </View>
                  )}

                  <Pressable style={[styles.submit, !canSubmit && { opacity: 0.5 }]} onPress={submit} disabled={!canSubmit || busy}>
                    {busy ? <ActivityIndicator color="#000" /> : <Text style={styles.submitText}>{t(isSignUp ? 'authSignUpButton' : 'authSignInButton')}</Text>}
                  </Pressable>

                  {!isSignUp && (
                    <Pressable onPress={forgot} style={{ alignSelf: 'center', marginTop: 4 }}>
                      <Text style={styles.muted}>{t('authForgotPassword')}</Text>
                    </Pressable>
                  )}

                  <Pressable onPress={() => { setIsSignUp((s) => !s); setConfirm(''); setAgreed(false); setError(null); }} style={{ alignSelf: 'center', marginTop: 14 }}>
                    <Text style={styles.toggle}>{t(isSignUp ? 'authHaveAccount' : 'authNoAccount')}</Text>
                  </Pressable>
                </View>
              </>
            )}
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

function DarkField({ icon, ...props }: React.ComponentProps<typeof TextInput> & { icon: keyof typeof Ionicons.glyphMap }) {
  return (
    <View style={styles.field}>
      <Ionicons name={icon} size={16} color="rgba(255,255,255,0.5)" style={{ marginRight: 10 }} />
      <TextInput placeholderTextColor="rgba(255,255,255,0.4)" style={styles.input} {...props} />
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 1, justifyContent: 'center', paddingHorizontal: 32, paddingVertical: 40 },
  logo: { width: 100, height: 100, borderRadius: 50, backgroundColor: 'rgba(255,255,255,0.15)', alignItems: 'center', justifyContent: 'center', alignSelf: 'center' },
  title: { color: '#fff', fontSize: 30, fontWeight: '700', textAlign: 'center', marginTop: 20 },
  tagline: { color: 'rgba(255,255,255,0.75)', fontSize: 14, fontWeight: '500', textAlign: 'center', marginTop: 6 },
  field: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.12)', borderRadius: radius.md, borderWidth: 1, borderColor: 'rgba(255,255,255,0.18)', paddingHorizontal: 16, paddingVertical: 14 },
  input: { flex: 1, fontSize: 16, color: '#fff' },
  errorBox: { flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: 'rgba(255,77,109,0.9)', borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12 },
  errorText: { color: '#fff', fontSize: 13, fontWeight: '500', flex: 1 },
  agreeRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 4 },
  agreeText: { color: 'rgba(255,255,255,0.8)', fontSize: 13 },
  link: { color: '#fff', fontSize: 13, fontWeight: '600', textDecorationLine: 'underline' },
  submit: { backgroundColor: '#fff', borderRadius: radius.md, paddingVertical: 15, alignItems: 'center' },
  submitText: { color: '#000', fontSize: 17, fontWeight: '600' },
  muted: { color: 'rgba(255,255,255,0.7)', fontSize: 14, fontWeight: '500' },
  toggle: { color: 'rgba(255,255,255,0.85)', fontSize: 14, fontWeight: '500' },
});
