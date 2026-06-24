/**
 * Per-group pinned message (群公告 style banner), stored on-device.
 * One pinned message per group; tapping "Pin" replaces any existing one.
 * Local-only for now — fast and offline; cross-device sync can come later.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const PINNED_KEY = 'wefluens.pinnedMessages';

export interface PinnedMessage {
  id: string;
  text: string;
  by: string;
}

async function readMap(): Promise<Record<string, PinnedMessage>> {
  try {
    const raw = await AsyncStorage.getItem(PINNED_KEY);
    return raw ? (JSON.parse(raw) as Record<string, PinnedMessage>) : {};
  } catch {
    return {};
  }
}

async function writeMap(map: Record<string, PinnedMessage>): Promise<void> {
  await AsyncStorage.setItem(PINNED_KEY, JSON.stringify(map)).catch(() => {});
}

export async function getPinned(groupId: string): Promise<PinnedMessage | null> {
  const map = await readMap();
  return map[groupId] ?? null;
}

export async function setPinned(groupId: string, msg: PinnedMessage | null): Promise<void> {
  const map = await readMap();
  if (msg) map[groupId] = msg;
  else delete map[groupId];
  await writeMap(map);
}
