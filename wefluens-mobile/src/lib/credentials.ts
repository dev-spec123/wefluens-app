/**
 * Remembered sign-in credentials, stored on-device so the login form stays
 * pre-filled across app updates / re-installs. Saved on a successful sign-in.
 * (Local AsyncStorage only — same app sandbox.)
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'wefluens.savedCredentials';

export interface SavedCredentials {
  email: string;
  password: string;
}

export async function getSavedCredentials(): Promise<SavedCredentials | null> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as SavedCredentials) : null;
  } catch {
    return null;
  }
}

export async function saveCredentials(email: string, password: string): Promise<void> {
  await AsyncStorage.setItem(KEY, JSON.stringify({ email, password })).catch(() => {});
}

export async function clearSavedCredentials(): Promise<void> {
  await AsyncStorage.removeItem(KEY).catch(() => {});
}
