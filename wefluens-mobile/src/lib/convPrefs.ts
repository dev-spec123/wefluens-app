/**
 * Per-conversation local preferences (mute / pin), stored on-device.
 * WeChat-style: mute (免打扰) hides the unread badge; pin (置顶) sorts to top.
 * Local-only for now — fast and offline; cross-device sync can come later.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const MUTE_KEY = 'wefluens.muted';
const PIN_KEY = 'wefluens.pinned';

async function readSet(key: string): Promise<Set<string>> {
  try {
    const raw = await AsyncStorage.getItem(key);
    return new Set<string>(raw ? (JSON.parse(raw) as string[]) : []);
  } catch {
    return new Set();
  }
}

async function writeSet(key: string, set: Set<string>): Promise<void> {
  await AsyncStorage.setItem(key, JSON.stringify(Array.from(set))).catch(() => {});
}

export const getMutedSet = () => readSet(MUTE_KEY);
export const getPinnedSet = () => readSet(PIN_KEY);

export async function setMuted(id: string, on: boolean): Promise<void> {
  const s = await readSet(MUTE_KEY);
  if (on) s.add(id); else s.delete(id);
  await writeSet(MUTE_KEY, s);
}

export async function setPinned(id: string, on: boolean): Promise<void> {
  const s = await readSet(PIN_KEY);
  if (on) s.add(id); else s.delete(id);
  await writeSet(PIN_KEY, s);
}
