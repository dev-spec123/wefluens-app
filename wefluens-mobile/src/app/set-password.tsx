/**
 * Set a new password during recovery — shown full-screen when
 * passwordRecoveryActive is true. Dusk gradient hero surface, two secure
 * fields (validated >= 8 chars + must match), then finishRecovery() which
 * signs the user out so they log back in fresh (the auth gate redirects).
 * No back button — the flow is intentionally non-dismissible.
 */
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useState } from 'react';
import {
  ActivityIndicator, KeyboardAvoidingView, Platform, Pressable, ScrollView,
  StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/lib/i18n';
import { gradients, palette, radius } from '@/lib/theme';

const MIN_LENGTH = 8;

export default function SetPassword() {
  const { t } = useI18n();
  const { finishRecovery } = useAuth();

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
      // Signs the user out on success; the auth gate handles redirect.
      await finishRecovery(newPassword);
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
      <SafeAreaView style={{ flex: 1 }}>
        <KeyboardAvoidingView
          style={{ flex: 1 }}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <ScrollView
            contentContainerStyle={styles.scroll}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.iconCircle}>
              <Ionicons name="lock-closed" size={34} color="#fff" />
            </View>

            <Text style={styles.title}>{t('forcePwTitle')}</Text>
            <Text style={styles.subtitle}>{t('forcePwSubtitle')}</Text>

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
  scroll: {
    flexGrow: 1,
    justifyContent: 'center',
    alignItems: 'center',
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
  saveBtnText: {
    color: '#000',
    fontSize: 17,
    fontWeight: '600',
  },
});
