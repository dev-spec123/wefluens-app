import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { LinearGradient } from 'expo-linear-gradient';
import * as Location from 'expo-location';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Card, NavBar } from '@/components/ui';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, useTheme } from '@/lib/theme';

// Handles are public identifiers: 3–20 of [a–z 0–9 _].
const HANDLE_RE = /^[a-z0-9_]{3,20}$/;

// Shorten long country names so "City, Country" stays compact.
const COUNTRY_SHORT: Record<string, string> = {
  'United States': 'US',
  'United States of America': 'US',
  'United Kingdom': 'UK',
  'United Arab Emirates': 'UAE',
  'Russian Federation': 'Russia',
  'Republic of Korea': 'South Korea',
  "Democratic People's Republic of Korea": 'North Korea',
  'Democratic Republic of the Congo': 'DR Congo',
  'Czech Republic': 'Czechia',
  'Dominican Republic': 'Dominican Rep.',
  'Bolivarian Republic of Venezuela': 'Venezuela',
  'Hong Kong': 'Hong Kong',
};

function shortCountry(name: string, code?: string): string {
  if (!name) return '';
  if (COUNTRY_SHORT[name]) return COUNTRY_SHORT[name];
  // Anything still very long falls back to its 2-letter ISO code.
  if (name.length > 16 && code) return code.toUpperCase();
  return name;
}

export default function EditProfile() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId, profile, refreshProfile } = useAuth();

  // --- editable fields ---
  const [name, setName] = useState('');
  const [handle, setHandle] = useState('');
  const [bio, setBio] = useState('');
  const [location, setLocation] = useState('');

  // --- original snapshot (for change tracking) ---
  const [originalName, setOriginalName] = useState('');
  const [originalHandle, setOriginalHandle] = useState('');
  const [originalBio, setOriginalBio] = useState('');
  const [originalLocation, setOriginalLocation] = useState('');

  // --- avatar ---
  const [localAvatarUri, setLocalAvatarUri] = useState<string | null>(null);
  const [photoChanged, setPhotoChanged] = useState(false);

  // --- save / locate state ---
  const [saving, setSaving] = useState(false);
  const [locating, setLocating] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  // Prefill from the loaded cloud profile.
  useEffect(() => {
    if (!profile) return;
    setName(profile.name);
    setHandle(profile.handle);
    setBio(profile.bio);
    setLocation(profile.location);
    setOriginalName(profile.name);
    setOriginalHandle(profile.handle);
    setOriginalBio(profile.bio);
    setOriginalLocation(profile.location);
  }, [profile]);

  const hasChanges =
    name !== originalName || handle !== originalHandle || bio !== originalBio
    || location !== originalLocation || photoChanged;

  const previewName = name.trim().length ? name : profile?.name ?? '';
  const previewUrl = localAvatarUri ?? profile?.avatarUrl ?? null;

  async function pickPhoto() {
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });
    if (result.canceled || !result.assets.length) return;
    setLocalAvatarUri(result.assets[0].uri);
    setPhotoChanged(true);
  }

  // Fill the location from device GPS as a standardized ENGLISH "City, Country"
  // (so it reads the same for everyone, regardless of the phone's language).
  // Reverse-geocoded via BigDataCloud's free, key-less, English endpoint — the
  // device's own reverseGeocodeAsync returns names in the phone's locale, which
  // a reader in another language can't understand.
  async function locate() {
    if (locating) return;
    setLocating(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        notify(t('editProfileLocateDenied'));
        return;
      }
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      const { latitude, longitude } = pos.coords;
      const res = await fetch(
        `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${latitude}&longitude=${longitude}&localityLanguage=en`,
      );
      const j = await res.json();
      const city = j.city || j.locality || j.principalSubdivision || '';
      const country = shortCountry(j.countryName || '', j.countryCode);
      const formatted = [city, country].filter(Boolean).join(', ');
      if (formatted) setLocation(formatted);
      else notify(t('editProfileLocateError'));
    } catch {
      notify(t('editProfileLocateError'));
    } finally {
      setLocating(false);
    }
  }

  async function save() {
    if (!userId || saving) return;
    const h = handle.trim().toLowerCase();
    const handleChanged = h !== originalHandle;

    // Validate the handle format before touching the network.
    if (handleChanged && !HANDLE_RE.test(h)) {
      Alert.alert(t('editProfileTitle'), t('editProfileHandleInvalid'));
      return;
    }

    setSaving(true);
    try {
      // Reject a taken handle up front for a clean message (the DB also guards).
      if (handleChanged && !(await api.isHandleAvailable(h, userId))) {
        Alert.alert(t('editProfileTitle'), t('editProfileHandleTaken'));
        return;
      }

      let avatarUrl: string | null | undefined = profile?.avatarUrl ?? null;
      if (photoChanged && localAvatarUri) {
        avatarUrl = await api.uploadAvatar(userId, localAvatarUri);
      }

      await api.updateProfile(userId, {
        name: name.trim(),
        bio: bio.trim(),
        location: location.trim(),
        handle: handleChanged ? h : undefined,
        avatarUrl,
      });
      await refreshProfile();

      setOriginalName(name);
      setOriginalHandle(h);
      setOriginalBio(bio);
      setOriginalLocation(location);
      setPhotoChanged(false);

      setShowSuccess(true);
      setTimeout(() => {
        setShowSuccess(false);
        router.back();
      }, 1200);
    } catch (e: any) {
      const msg = e?.message === 'HANDLE_TAKEN' ? t('editProfileHandleTaken') : (e?.message ?? t('authErrGeneric'));
      Alert.alert(t('editProfileTitle'), msg);
    } finally {
      setSaving(false);
    }
  }

  const saveDisabled = !hasChanges || saving;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar
        title={t('editProfileTitle')}
        right={
          <Pressable onPress={() => router.back()}>
            <Text style={{ color: c.inkSecondary, fontWeight: '600' }}>{t('authCancel')}</Text>
          </Pressable>
        }
      />

      <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 8, paddingBottom: 30 }}>
        {/* Avatar */}
        <View style={styles.avatarSection}>
          <View>
            {previewUrl ? (
              <Image source={{ uri: previewUrl }} style={styles.avatarImage} contentFit="cover" />
            ) : (
              <Avatar colors={gradients.sunset} name={previewName || '?'} size={100} online />
            )}
            <Pressable onPress={pickPhoto} style={styles.cameraBadgeWrap}>
              <LinearGradient
                colors={gradients.sunset}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={[styles.cameraBadge, { borderColor: c.paper }]}
              >
                <Ionicons name="camera" size={16} color="#fff" />
              </LinearGradient>
            </Pressable>
          </View>
          <Pressable onPress={pickPhoto}>
            <Text style={{ color: c.coral, fontSize: 13, fontWeight: '500', marginTop: 14 }}>
              {t('editProfileChangePhoto')}
            </Text>
          </Pressable>
        </View>

        {/* Form */}
        <Card style={{ paddingVertical: 8 }}>
          <FormField icon="person" title={t('editProfileName')} value={name} onChangeText={setName} />
          <Divider />
          <FormField
            icon="at"
            title="Handle"
            value={handle}
            onChangeText={(v) => setHandle(v.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
            autoCapitalize="none"
            maxLength={20}
            hint={t('editProfileHandleHint')}
          />
          <Divider />
          <FormField icon="text" title={t('editProfileBio')} value={bio} onChangeText={setBio} multiline />
          <Divider />
          <FormField
            icon="location"
            title={t('editProfileLocation')}
            value={location}
            editable={false}
            hint={t('editProfileLocate')}
            trailing={
              <Pressable onPress={locate} disabled={locating} hitSlop={8} style={styles.locateBtn}>
                {locating ? (
                  <ActivityIndicator color={c.coral} size="small" />
                ) : (
                  <Ionicons name="locate" size={18} color={c.coral} />
                )}
              </Pressable>
            }
          />
          {locating ? (
            <Text style={[styles.locatingNote, { color: c.inkTertiary }]}>{t('editProfileLocating')}</Text>
          ) : null}
        </Card>

        {/* Save */}
        <Pressable onPress={save} disabled={saveDisabled} style={{ marginTop: 22 }}>
          <LinearGradient
            colors={saveDisabled ? [c.inkTertiary, c.inkTertiary] : gradients.sunset}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.saveBtn}
          >
            {saving ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.saveBtnText}>{t('editProfileSave')}</Text>
            )}
          </LinearGradient>
        </Pressable>
      </ScrollView>

      {/* Success toast */}
      {showSuccess && (
        <View style={styles.toastWrap} pointerEvents="none">
          <View style={styles.toast}>
            <Ionicons name="checkmark-circle" size={18} color="#fff" />
            <Text style={styles.toastText}>{t('editProfileSaved')}</Text>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
}

function FormField({
  icon, title, value, onChangeText, editable = true, multiline = false,
  autoCapitalize, maxLength, hint, trailing,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  value: string;
  onChangeText?: (v: string) => void;
  editable?: boolean;
  multiline?: boolean;
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters';
  maxLength?: number;
  hint?: string;
  trailing?: React.ReactNode;
}) {
  const c = useTheme();
  return (
    <View style={styles.fieldRow}>
      <Ionicons name={icon} size={16} color={c.coral} style={{ width: 22, marginTop: 4 }} />
      <View style={{ flex: 1 }}>
        <Text style={[styles.fieldLabel, { color: c.inkTertiary }]}>{title.toUpperCase()}</Text>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <TextInput
            value={value}
            onChangeText={onChangeText}
            editable={editable}
            multiline={multiline}
            autoCapitalize={autoCapitalize}
            autoCorrect={autoCapitalize === 'none' ? false : undefined}
            maxLength={maxLength}
            placeholder={title}
            placeholderTextColor={c.inkTertiary}
            style={[
              styles.fieldInput,
              { color: editable ? c.ink : c.inkSecondary, flex: 1 },
              multiline && { minHeight: 44, textAlignVertical: 'top' },
            ]}
          />
          {trailing}
        </View>
        {hint ? <Text style={[styles.fieldHint, { color: c.inkTertiary }]}>{hint}</Text> : null}
      </View>
    </View>
  );
}

function Divider() {
  const c = useTheme();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: 52 }} />;
}

const AVATAR = 100;

const styles = StyleSheet.create({
  avatarSection: { alignItems: 'center', paddingVertical: 20 },
  avatarImage: { width: AVATAR, height: AVATAR, borderRadius: AVATAR / 2 },
  cameraBadgeWrap: { position: 'absolute', right: -2, bottom: -2 },
  cameraBadge: {
    width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center', borderWidth: 3,
  },
  fieldRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 14, paddingHorizontal: 16, paddingVertical: 13 },
  fieldLabel: { fontSize: 11, fontWeight: '700', letterSpacing: 0.8, marginBottom: 2 },
  fieldInput: { fontSize: 16, fontWeight: '500', padding: 0 },
  fieldHint: { fontSize: 11.5, marginTop: 4 },
  locateBtn: { paddingLeft: 10, paddingVertical: 2 },
  locatingNote: { fontSize: 12, paddingHorizontal: 52, paddingBottom: 8 },
  saveBtn: {
    borderRadius: radius.md, paddingVertical: 16, alignItems: 'center', justifyContent: 'center',
  },
  saveBtnText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  toastWrap: { position: 'absolute', top: 70, left: 0, right: 0, alignItems: 'center' },
  toast: {
    flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: '#2AD17E',
    paddingHorizontal: 20, paddingVertical: 14, borderRadius: radius.pill,
  },
  toastText: { color: '#fff', fontSize: 15, fontWeight: '600' },
});
