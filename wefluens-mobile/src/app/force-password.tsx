/**
 * Forced password change — shown full-screen when mustChangePassword is set.
 * Dusk gradient hero surface, two secure fields, validation (>=8 + match), then
 * changePassword() which clears the flag and lets the root gate redirect to tabs.
 * Ported from the Swift ForcePasswordChangeView (forced = true variant).
 */
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useRef, useState } from 'react';
import {
  Animated, Easing, Keyboard, KeyboardAvoidingView, Platform, Pressable,
  StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { GradientButton } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/lib/i18n';
import { gradients, palette, radius } from '@/lib/theme';

/** Initial password seeded for invited users; the new one must differ. */
const INITIAL_PASSWORD = '11111111';

export default function ForcePassword() {
  const { t } = useI18n();
  const { changePassword, signOut } = useAuth();

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Decorative glow floats further up while the keyboard is shown (mirrors the
  // Swift keyboardWillShow/Hide animation on the sunset circle).
  const glow = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const showEvt = Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow';
    const hideEvt = Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide';
    const animate = (to: number) => Animated.timing(glow, {
      toValue: to, duration: 400, easing: Easing.out(Easing.ease), useNativeDriver: true,
    }).start();
    const showSub = Keyboard.addListener(showEvt, () => animate(1));
    const hideSub = Keyboard.addListener(hideEvt, () => animate(0));
    return () => { showSub.remove(); hideSub.remove(); };
  }, [glow]);
  const glowTranslate = glow.interpolate({ inputRange: [0, 1], outputRange: [-120, -220] });

  const canSubmit = newPassword.length >= 8 && confirmPassword.length >= 8;

  async function save() {
    setError(null);
    if (newPassword.length < 8) {
      setError(t('forcePwTooShort'));
      return;
    }
    if (newPassword === INITIAL_PASSWORD) {
      setError(t('forcePwSameAsInitial'));
      return;
    }
    if (newPassword !== confirmPassword) {
      setError(t('authPasswordMismatch'));
      return;
    }
    setSaving(true);
    try {
      // Clears must_change_password → the root gate swaps in the main tabs.
      await changePassword(newPassword);
    } catch (e) {
      setError(e instanceof Error ? e.message : t('authErrGeneric'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <View style={{ flex: 1 }}>
      <LinearGradient
        colors={gradients.dusk}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={StyleSheet.absoluteFill}
      />
      <Animated.View
        pointerEvents="none"
        style={[styles.glow, { transform: [{ translateY: glowTranslate }] }]}
      />
      <SafeAreaView style={{ flex: 1 }} edges={['top', 'bottom']}>
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <View style={styles.container}>
            <View style={{ flex: 1 }} />

            <View style={styles.iconWrap}>
              <Ionicons name="lock-closed" size={34} color="#fff" />
            </View>

            <Text style={styles.title}>{t('forcePwTitle')}</Text>
            <Text style={styles.subtitle}>{t('forcePwSubtitle')}</Text>

            <View style={{ flex: 1 }} />

            <View style={styles.form}>
              <View style={styles.field}>
                <Ionicons name="lock-closed" size={16} color="rgba(255,255,255,0.5)" style={{ marginRight: 10 }} />
                <TextInput
                  value={newPassword}
                  onChangeText={setNewPassword}
                  placeholder={t('forcePwNew')}
                  placeholderTextColor="rgba(255,255,255,0.4)"
                  secureTextEntry
                  autoCapitalize="none"
                  autoCorrect={false}
                  textContentType="newPassword"
                  style={styles.input}
                />
              </View>

              <View style={styles.field}>
                <Ionicons name="lock-closed-outline" size={16} color="rgba(255,255,255,0.5)" style={{ marginRight: 10 }} />
                <TextInput
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  placeholder={t('forcePwConfirm')}
                  placeholderTextColor="rgba(255,255,255,0.4)"
                  secureTextEntry
                  autoCapitalize="none"
                  autoCorrect={false}
                  textContentType="newPassword"
                  style={styles.input}
                />
              </View>

              {error ? <Text style={styles.error}>{error}</Text> : null}

              <GradientButton
                title={t('forcePwSave')}
                onPress={save}
                loading={saving}
                disabled={!canSubmit}
                style={{ marginTop: 4 }}
              />

              <Pressable onPress={() => signOut()} style={styles.signOut} hitSlop={8}>
                <Text style={styles.signOutText}>{t('profileSignOut')}</Text>
              </Pressable>
            </View>
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  glow: {
    position: 'absolute', alignSelf: 'center', top: '50%',
    width: 260, height: 260, borderRadius: 130,
    backgroundColor: 'rgba(255,107,107,0.25)',
  },
  container: { flex: 1, paddingHorizontal: 32 },
  iconWrap: {
    width: 92, height: 92, borderRadius: 46, alignSelf: 'center',
    backgroundColor: 'rgba(255,255,255,0.15)', alignItems: 'center', justifyContent: 'center',
    shadowColor: palette.coral, shadowOpacity: 0.4, shadowRadius: 24, shadowOffset: { width: 0, height: 8 },
  },
  title: {
    color: '#fff', fontSize: 26, fontWeight: '700', textAlign: 'center', marginTop: 22,
  },
  subtitle: {
    color: 'rgba(255,255,255,0.7)', fontSize: 14, fontWeight: '500', textAlign: 'center',
    marginTop: 8, paddingHorizontal: 4,
  },
  form: { paddingBottom: 24, gap: 12 },
  field: {
    flexDirection: 'row', alignItems: 'center', borderRadius: radius.md,
    backgroundColor: 'rgba(255,255,255,0.12)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.18)',
    paddingHorizontal: 16, paddingVertical: 14,
  },
  input: { flex: 1, fontSize: 16, color: '#fff' },
  error: { color: '#fff', fontSize: 13, fontWeight: '500', paddingHorizontal: 4 },
  signOut: { alignSelf: 'center', marginTop: 8, paddingVertical: 6 },
  signOutText: { color: 'rgba(255,255,255,0.6)', fontSize: 14 },
});
