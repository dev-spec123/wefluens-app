/**
 * Set a new password during recovery — shown full-screen when
 * passwordRecoveryActive is true. Dusk gradient hero surface, two secure
 * fields (validated >= 8 chars + must match). On success it shows a dedicated
 * confirmation screen (checkmark + setPwSuccess copy + "Back to sign in"),
 * mirroring the Swift SetNewPasswordView. Dismissing signs the user out so the
 * auth gate redirects them back to sign-in. No back button — non-dismissible.
 */
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator, Animated, Easing, Keyboard, KeyboardAvoidingView, Platform,
  Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/lib/i18n';
import { gradients, palette, radius } from '@/lib/theme';

const MIN_LENGTH = 8;

export default function SetPassword() {
  const { t } = useI18n();
  const { updateRecoveredPassword, dismissRecovery } = useAuth();

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [didSucceed, setDidSucceed] = useState(false);

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

  const canSubmit = newPassword.length > 0 && confirmPassword.length > 0;

  async function save() {
    setError(null);
    if (newPassword.length < MIN_LENGTH) {
      setError(t('forcePwTooShort'));
      return;
    }
    if (newPassword !== confirmPassword) {
      setError(t('authPasswordMismatch'));
      return;
    }
    setSaving(true);
    try {
      // Updates the password but keeps the session so we can show the success
      // screen; the user is signed out only when they tap "Back to sign in".
      await updateRecoveredPassword(newPassword);
      setDidSucceed(true);
    } catch (e: any) {
      setError(e?.message ?? t('authErrGeneric'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <LinearGradient
      colors={gradients.dusk}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={{ flex: 1 }}
    >
      <Animated.View
        pointerEvents="none"
        style={[styles.glow, { transform: [{ translateY: glowTranslate }] }]}
      />
      <SafeAreaView style={{ flex: 1 }}>
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          {didSucceed ? (
            <View style={styles.successWrap}>
              <View style={styles.iconCircle}>
                <Ionicons name="checkmark" size={36} color="#fff" />
              </View>
              <Text style={styles.successText}>{t('setPwSuccess')}</Text>
              <View style={{ flex: 1 }} />
              <Pressable
                onPress={() => dismissRecovery()}
                style={[styles.saveBtn, styles.successBtn]}
              >
                <Text style={styles.saveBtnText}>{t('authBackToSignIn')}</Text>
              </Pressable>
            </View>
          ) : (
            <ScrollView
              contentContainerStyle={styles.scroll}
              keyboardShouldPersistTaps="handled"
            >
              <View style={styles.iconCircle}>
                <Ionicons name="lock-closed" size={34} color="#fff" />
              </View>

              <Text style={styles.title}>{t('forcePwTitle')}</Text>
              <Text style={styles.subtitle}>{t('forcePwSubtitleOptional')}</Text>

              <View style={styles.form}>
                <SecureField
                  icon="lock-closed"
                  placeholder={t('forcePwNew')}
                  value={newPassword}
                  onChangeText={setNewPassword}
                />
                <SecureField
                  icon="shield-checkmark"
                  placeholder={t('forcePwConfirm')}
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                />

                {error ? <Text style={styles.error}>{error}</Text> : null}

                <Pressable
                  onPress={save}
                  disabled={!canSubmit || saving}
                  style={[styles.saveBtn, { opacity: canSubmit && !saving ? 1 : 0.5 }]}
                >
                  {saving ? (
                    <ActivityIndicator color="#000" />
                  ) : (
                    <Text style={styles.saveBtnText}>{t('forcePwSave')}</Text>
                  )}
                </Pressable>
              </View>
            </ScrollView>
          )}
        </KeyboardAvoidingView>
      </SafeAreaView>
    </LinearGradient>
  );
}

function SecureField({
  icon, placeholder, value, onChangeText,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  placeholder: string;
  value: string;
  onChangeText: (v: string) => void;
}) {
  return (
    <View style={styles.field}>
      <Ionicons name={icon} size={16} color="rgba(255,255,255,0.5)" style={{ marginRight: 10 }} />
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor="rgba(255,255,255,0.4)"
        secureTextEntry
        autoCapitalize="none"
        autoCorrect={false}
        textContentType="newPassword"
        style={styles.input}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  glow: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    width: 260,
    height: 260,
    borderRadius: 130,
    backgroundColor: 'rgba(255,107,107,0.25)',
  },
  scroll: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingVertical: 40,
  },
  successWrap: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    paddingVertical: 40,
  },
  iconCircle: {
    width: 92,
    height: 92,
    borderRadius: 46,
    backgroundColor: 'rgba(255,255,255,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: palette.coral,
    shadowOpacity: 0.4,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 8 },
  },
  title: {
    color: '#fff',
    fontSize: 26,
    fontWeight: '700',
    textAlign: 'center',
    marginTop: 22,
  },
  subtitle: {
    color: 'rgba(255,255,255,0.7)',
    fontSize: 14,
    fontWeight: '500',
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 4,
  },
  successText: {
    color: '#fff',
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
    marginTop: 22,
    paddingHorizontal: 36,
  },
  form: {
    alignSelf: 'stretch',
    marginTop: 36,
    gap: 12,
  },
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)',
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  input: {
    flex: 1,
    fontSize: 16,
    color: '#fff',
  },
  error: {
    color: palette.coral,
    fontSize: 13,
    fontWeight: '500',
    paddingHorizontal: 4,
  },
  saveBtn: {
    backgroundColor: '#fff',
    borderRadius: radius.md,
    paddingVertical: 15,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  successBtn: {
    alignSelf: 'stretch',
  },
  saveBtnText: {
    color: '#000',
    fontSize: 17,
    fontWeight: '600',
  },
});
