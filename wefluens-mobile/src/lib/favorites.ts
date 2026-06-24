/**
 * Saved (收藏) messages, stored on-device. WeChat-style favorites: long-press a
 * message and stash it for later. Local-only — fast and offline.
 *
 * Media favorites (image / video / file / audio) download a PERMANENT local copy
 * into documentDirectory on save, so they still open even after the server-side
 * media is auto-expired/cleaned (and offline). `localUri` is that copy.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as FileSystem from 'expo-file-system/legacy';

import { signedMediaUrl } from './api';
import { supabase } from './supabase';

const FAV_KEY = 'wefluens.favorites';
const FAV_DIR = `${FileSystem.documentDirectory ?? ''}favorites/`;

export interface FavItem {
  id: string;
  text: string;
  kind: string;
  sender: string;
  source: string;
  at: number;
  /** Chat-media storage path (any media favorite). */
  imagePath?: string | null;
  /** Permanent on-device copy — opens even after the server media expires. */
  localUri?: string | null;
  /** File metadata (file favorites). */
  fileName?: string | null;
  fileMime?: string | null;
}

/** Local (AsyncStorage) copy — used as a media / offline cache and a fallback. */
async function getLocalFavorites(): Promise<FavItem[]> {
  try {
    const raw = await AsyncStorage.getItem(FAV_KEY);
    return raw ? (JSON.parse(raw) as FavItem[]) : [];
  } catch {
    return [];
  }
}

async function currentUid(): Promise<string | null> {
  try {
    const { data } = await supabase.auth.getSession();
    return data.session?.user.id ?? null;
  } catch {
    return null;
  }
}

/** Cloud-synced favorites (Supabase `favorites` table, like the Swift app), merged
 *  with the local copy for permanent media uris. Falls back to local when offline
 *  or signed out. */
export async function getFavorites(): Promise<FavItem[]> {
  const local = await getLocalFavorites();
  const uid = await currentUid();
  if (!uid) return local;
  try {
    const { data } = await supabase
      .from('favorites')
      .select('*')
      .eq('user_id', uid)
      .order('saved_at', { ascending: false });
    const rows = (data as any[]) ?? [];
    const localById = new Map(local.map((f) => [f.id, f]));
    return rows.map((r) => {
      const l = localById.get(r.message_id);
      return {
        id: r.message_id,
        text: r.text ?? '',
        kind: r.kind ?? 'text',
        sender: r.sender ?? '',
        source: r.source ?? 'dm',
        at: r.saved_at ? new Date(r.saved_at).getTime() : Date.now(),
        imagePath: l?.imagePath ?? null,
        localUri: l?.localUri ?? null,
        fileName: l?.fileName ?? null,
        fileMime: l?.fileMime ?? null,
      } as FavItem;
    });
  } catch {
    return local;
  }
}

async function writeFavorites(items: FavItem[]): Promise<void> {
  await AsyncStorage.setItem(FAV_KEY, JSON.stringify(items)).catch(() => {});
}

const MEDIA_KINDS = new Set(['image', 'video', 'file', 'audio']);

/** Downloads a favorite's media into documentDirectory (permanent). Returns the
 *  local uri, or null if it couldn't be fetched (favorite still saves). */
async function persistMedia(item: FavItem): Promise<string | null> {
  if (!item.imagePath || !FileSystem.documentDirectory) return null;
  try {
    await FileSystem.makeDirectoryAsync(FAV_DIR, { intermediates: true }).catch(() => {});
    const fromName = item.fileName?.split('.').pop();
    const fromPath = item.imagePath.split('.').pop();
    const ext = (fromName || fromPath || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin';
    const dest = `${FAV_DIR}${item.id}.${ext}`;
    const info = await FileSystem.getInfoAsync(dest);
    if (info.exists && (info.size ?? 0) > 0) return dest;
    const url = await signedMediaUrl(item.imagePath);
    const { uri } = await FileSystem.downloadAsync(url, dest);
    return uri;
  } catch {
    return null;
  }
}

/** Prepend a favorite; dedupe by id. Media favorites get a permanent local copy. */
export async function addFavorite(item: FavItem): Promise<void> {
  let toSave = item;
  if (item.imagePath && MEDIA_KINDS.has(item.kind)) {
    const localUri = await persistMedia(item);
    toSave = { ...item, localUri };
  }
  // Local copy (media / offline cache).
  const items = await getLocalFavorites();
  await writeFavorites([toSave, ...items.filter((f) => f.id !== toSave.id)]);
  // Cloud sync (cross-device) — mirrors the Swift favorites table; best-effort.
  const uid = await currentUid();
  if (uid) {
    void supabase
      .from('favorites')
      .upsert(
        { user_id: uid, message_id: item.id, text: item.text, kind: item.kind, sender: item.sender, source: item.source },
        { onConflict: 'user_id,message_id' },
      )
      .then(() => {}, () => {});
  }
}

export async function removeFavorite(id: string): Promise<void> {
  const items = await getLocalFavorites();
  const target = items.find((f) => f.id === id);
  if (target?.localUri) {
    FileSystem.deleteAsync(target.localUri, { idempotent: true }).catch(() => {});
  }
  await writeFavorites(items.filter((f) => f.id !== id));
  const uid = await currentUid();
  if (uid) {
    void supabase.from('favorites').delete().eq('user_id', uid).eq('message_id', id).then(() => {}, () => {});
  }
}
