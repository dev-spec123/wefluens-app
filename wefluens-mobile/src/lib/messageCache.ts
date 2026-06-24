/**
 * On-device cache of a conversation's messages, so opening a chat shows the last
 * view instantly (and works offline) before the live data refreshes.
 *
 * Two layers:
 *  - an in-memory Map (SYNCHRONOUS) → re-opening a chat in the same session is
 *    instant, no spinner (read it in a useState initializer).
 *  - AsyncStorage (async) → survives app relaunches; warms the in-memory layer
 *    on first read after a cold start.
 * Capped to the most recent messages per conversation to keep storage bounded.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const PREFIX = 'wefluens.msgcache.';
const MAX_CACHED = 200;

// Synchronous in-memory mirror of the disk cache (per app session).
const mem = new Map<string, unknown[]>();

/** Synchronous read — returns the cached messages immediately if they're in
 *  memory (use in a useState initializer for an instant, spinner-free open). */
export function getMemCachedMessages<T>(key: string): T[] | null {
  return (mem.get(key) as T[] | undefined) ?? null;
}

export async function getCachedMessages<T>(key: string): Promise<T[] | null> {
  const inMem = mem.get(key);
  if (inMem) return inMem as T[];
  try {
    const raw = await AsyncStorage.getItem(PREFIX + key);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as T[];
    mem.set(key, parsed); // warm the in-memory layer for instant re-entry
    return parsed;
  } catch {
    return null;
  }
}

export async function setCachedMessages<T>(key: string, messages: T[]): Promise<void> {
  const trimmed = messages.length > MAX_CACHED ? messages.slice(-MAX_CACHED) : messages;
  mem.set(key, trimmed);
  try {
    await AsyncStorage.setItem(PREFIX + key, JSON.stringify(trimmed));
  } catch {
    // best effort — ignore (e.g. storage full)
  }
}

/** Drop every cached conversation (called on sign-out, so a different account on
 *  the same device can't see the previous user's chats). */
export async function clearMessageCache(): Promise<void> {
  mem.clear();
  try {
    const keys = await AsyncStorage.getAllKeys();
    const ours = keys.filter((k) => k.startsWith(PREFIX));
    if (ours.length) await AsyncStorage.multiRemove(ours);
  } catch {
    // ignore
  }
}
