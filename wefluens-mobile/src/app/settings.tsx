import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, Divider, NavBar } from '@/components/ui';
import { useI18n } from '@/lib/i18n';
import { useTheme, useThemeMode, type ThemeMode } from '@/lib/theme';

const APPEARANCE: { value: ThemeMode; icon: keyof typeof Ionicons.glyphMap; labelKey: string }[] = [
  { value: 'system', icon: 'phone-portrait', labelKey: 'themeSystem' },
  { value: 'light', icon: 'sunny', labelKey: 'themeLight' },
  { value: 'dark', icon: 'moon', labelKey: 'themeDark' },
];

export default function Settings() {
  const c = useTheme();
  const { t, lang, setLang, LANGUAGES } = useI18n();
  const { mode, setMode } = useThemeMode();
  const router = useRouter();

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('settingsTitle')} onBack={() => router.back()} />

      <ScrollView contentContainerStyle={{ padding: 18, paddingBottom: 40 }}>
        {/* ─────────── Language ─────────── */}
        <Text style={sectionHeader(c.inkTertiary)}>{t('settingsLanguage').toUpperCase()}</Text>
        <Card style={{ paddingVertical: 4, marginTop: 10 }}>
          {LANGUAGES.map((l, i) => {
            const active = lang === l.code;
            return (
              <View key={l.code}>
                <Pressable
                  onPress={() => setLang(l.code)}
                  style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 13, gap: 14 }}
                >
                  <Text style={{ fontSize: 24, width: 36, textAlign: 'center' }}>{l.flag}</Text>
                  <Text style={{ flex: 1, color: c.ink, fontSize: 16, fontWeight: '500' }}>{l.native}</Text>
                  {active && <Ionicons name="checkmark-circle" size={20} color={c.coral} />}
                </Pressable>
                {i < LANGUAGES.length - 1 && <Divider inset={60} />}
              </View>
            );
          })}
        </Card>
        <Text style={sectionFooter(c.inkSecondary)}>{t('settingsLanguageFooter')}</Text>

        {/* ─────────── Appearance ─────────── */}
        <Text style={[sectionHeader(c.inkTertiary), { marginTop: 24 }]}>
          {t('settingsAppearance').toUpperCase()}
        </Text>
        <Card style={{ paddingVertical: 4, marginTop: 10 }}>
          {APPEARANCE.map((opt, i) => {
            const active = mode === opt.value;
            return (
              <View key={opt.value}>
                <Pressable
                  onPress={() => setMode(opt.value)}
                  style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 13, gap: 14 }}
                >
                  <Ionicons name={opt.icon} size={20} color={c.coral} style={{ width: 36, textAlign: 'center' }} />
                  <Text style={{ flex: 1, color: c.ink, fontSize: 16, fontWeight: '500' }}>{t(opt.labelKey)}</Text>
                  {active && <Ionicons name="checkmark-circle" size={20} color={c.coral} />}
                </Pressable>
                {i < APPEARANCE.length - 1 && <Divider inset={60} />}
              </View>
            );
          })}
        </Card>
        <Text style={sectionFooter(c.inkSecondary)}>{t('settingsAppearanceFooter')}</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function sectionHeader(color: string) {
  return { color, fontSize: 12, fontWeight: '700' as const, letterSpacing: 1, paddingLeft: 4 };
}

function sectionFooter(color: string) {
  return { color, fontSize: 13, marginTop: 10, paddingHorizontal: 4 };
}
