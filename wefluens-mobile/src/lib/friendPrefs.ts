/**
 * Per-friend local remarks (备注), stored on-device. WeChat-style: a remark
 * overrides the displayed name for a contact without changing their profile.
 * Local-only for now — fast and offline; cross-device sync can come later.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const REMARK_KEY = 'wefluens.remarks';

/** Read the full id → remark map. */
export async function getRemarks(): Promise<Record<string, string>> {
  try {
    const raw = await AsyncStorage.getItem(REMARK_KEY);
    return raw ? (JSON.parse(raw) as Record<string, string>) : {};
  } catch {
    return {};
  }
}

/** Set (or clear, when empty) the remark for a contact id. */
export async function setRemark(id: string, remark: string): Promise<void> {
  const map = await getRemarks();
  const trimmed = remark.trim();
  if (trimmed) map[id] = trimmed;
  else delete map[id];
  await AsyncStorage.setItem(REMARK_KEY, JSON.stringify(map)).catch(() => {});
}
