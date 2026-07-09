/**
 * Data layer — every Supabase call the app makes, mirroring the Swift
 * AppDataService. Same backend: same tables, RPCs, edge functions, and buckets.
 */
import { Platform } from 'react-native';
import * as ImageManipulator from 'expo-image-manipulator';
import * as FileSystem from 'expo-file-system/legacy';

import { supabase } from './supabase';
import { getCurrentLang } from './i18n';
import { avatarGradient } from './theme';
import { clockTime, parseColors, relativeTime } from './format';
import { messageMentionsMe } from './mentions';

/** Downscale + recompress a picked image before upload to save storage/bandwidth.
 *  GIFs are returned untouched so their animation survives. Falls back to the
 *  original on any failure. */
async function maybeCompressImage(uri: string, mime?: string | null, width = 0): Promise<{ uri: string; mime: string }> {
  const m = (mime ?? '').toLowerCase();
  if (m.includes('gif')) return { uri, mime: 'image/gif' };
  try {
    const actions = width > 1280 ? [{ resize: { width: 1280 } }] : [];
    const r = await ImageManipulator.manipulateAsync(uri, actions, {
      compress: 0.7,
      format: ImageManipulator.SaveFormat.JPEG,
    });
    return { uri: r.uri, mime: 'image/jpeg' };
  } catch {
    return { uri, mime: m || 'image/jpeg' };
  }
}

/** Compress a picked video before upload (big storage/bandwidth win). Native
 *  only — the module is required lazily so it never loads on web. Falls back to
 *  the original on failure. */
async function maybeCompressVideo(uri: string): Promise<string> {
  if (Platform.OS === 'web') return uri;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { Video } = require('react-native-compressor');
    return await Video.compress(uri, { compressionMethod: 'auto' });
  } catch {
    return uri;
  }
}
import type {
  AdminUser, Brand, Campaign, ChatMessage, Contact, Conversation, FriendRequest,
  GroupMember, GroupMessage, ProfileRow, ReportReason, SearchUserResult, UserProfile,
} from './types';

// ─────────────────────────── Profile ───────────────────────────

function mapProfile(row: ProfileRow, fallbackName?: string): UserProfile {
  return {
    id: row.id,
    name: row.name ?? fallbackName ?? 'User',
    handle: row.handle ?? '',
    role: row.role ?? '',
    bio: row.bio ?? '',
    location: row.location ?? '',
    followers: row.followers ?? '0',
    engagement: row.engagement ?? '0%',
    deals: row.deals ?? '0',
    isAdmin: row.is_admin ?? false,
    avatarUrl: row.avatar_url,
    notificationsEnabled: row.notifications_enabled ?? true,
    activityStatus: row.activity_status ?? true,
    // Discoverable (Add Friend's browse list) is opt-OUT: on unless hidden.
    dataSharing: row.data_sharing ?? true,
  };
}

/** Persists the Activity Status preference (online-dot visibility). */
export async function setActivityStatus(userId: string, on: boolean): Promise<void> {
  const { error } = await supabase.from('profiles').update({ activity_status: on }).eq('id', userId);
  if (error) throw error;
}

/** Persists the Discoverable (data sharing) preference — show in the Top Talent directory. */
export async function setDataSharing(userId: string, on: boolean): Promise<void> {
  const { error } = await supabase.from('profiles').update({ data_sharing: on }).eq('id', userId);
  if (error) throw error;
}

/** Persists the push-notifications preference. */
export async function setNotificationsEnabled(userId: string, on: boolean): Promise<void> {
  const { error } = await supabase.from('profiles').update({ notifications_enabled: on }).eq('id', userId);
  if (error) throw error;
}

/** A picked support attachment: a local image URI plus its (optional) source MIME. */
export type SupportImageInput = string | { uri: string; mime?: string | null };

export type SupportTicketType = 'bug' | 'idea' | 'other';

const MAX_SUPPORT_IMAGES = 6;
const MAX_SUPPORT_IMAGE_BYTES = 5 * 1024 * 1024; // 5MB per image (decoded size)

/** Decoded byte length of a base64 string (ignoring whitespace), without
 *  allocating the bytes. Used to enforce the per-image 5MB cap. */
function base64ByteLength(b64: string): number {
  const clean = b64.replace(/[^A-Za-z0-9+/=]/g, '');
  const padding = clean.endsWith('==') ? 2 : clean.endsWith('=') ? 1 : 0;
  return Math.floor((clean.length * 3) / 4) - padding;
}

/** Submits an in-app support ticket (records it server-side + emails support).
 *  Images are compressed (~1600px) then base64-encoded inline. Caps at 6 images
 *  and skips any that still exceed 5MB after compression. */
export async function submitSupportTicket(args: {
  subject: string;
  body: string;
  type: SupportTicketType;
  images?: SupportImageInput[];
}): Promise<void> {
  const { subject, body, type } = args;
  const inputs = (args.images ?? []).slice(0, MAX_SUPPORT_IMAGES);

  const images: Array<{ dataBase64: string; mime: string }> = [];
  for (const input of inputs) {
    const uri = typeof input === 'string' ? input : input.uri;
    const srcMime = typeof input === 'string' ? null : input.mime ?? null;
    try {
      // Compress first to keep the inline payload small. Pass a large width so the
      // helper always resizes down to its ~1600px target before re-encoding.
      const compressed = await maybeCompressImage(uri, srcMime, 1600);
      const dataBase64 = await FileSystem.readAsStringAsync(compressed.uri, { encoding: 'base64' });
      // Skip anything that's still over 5MB after compression.
      if (base64ByteLength(dataBase64) > MAX_SUPPORT_IMAGE_BYTES) continue;
      images.push({ dataBase64, mime: compressed.mime });
    } catch {
      // A single bad attachment shouldn't sink the whole ticket — skip it.
    }
  }

  const lang: 'zh' | 'en' = getCurrentLang() === 'zh' ? 'zh' : 'en';

  const { data, error } = await supabase.functions.invoke('submit-support-ticket', {
    body: { subject, body, type, lang, images },
  });
  if (error) throw error;
  if (data && (data as { ok?: boolean }).ok === false) throw new Error('SUPPORT_FAILED');
}

/** The admin-curated Top Talent showcase, mirroring the Swift app's
 *  `browse_top_talent`. Featured creators only, in admin order — the
 *  Discoverable toggle no longer affects this list. */
export async function loadTopTalent(blockedIds: Set<string>, limit = 50): Promise<SearchUserResult[]> {
  const { data, error } = await supabase.rpc('browse_top_talent', { limit_count: limit });
  if (error || !data) return [];
  return (data as SearchUserResult[]).filter((u) => !blockedIds.has(u.id));
}

/** Add Friend's own browse list (decoupled from the now-curated Top Talent),
 *  mirroring the Swift app's `browse_addable_users`. All addable users ranked
 *  by followers, gated by the Discoverable (data_sharing) opt-out toggle. */
export async function browseAddableUsers(blockedIds: Set<string>, limit = 50): Promise<SearchUserResult[]> {
  const { data, error } = await supabase.rpc('browse_addable_users', { limit_count: limit });
  if (error || !data) return [];
  return (data as SearchUserResult[]).filter((u) => !blockedIds.has(u.id));
}

export interface MyInviteCode { code: string; uses: number; max_uses: number; }

/** The signed-in user's personal shareable invite code (mints one if needed).
 *  Mirrors the Swift app's get_or_create_my_invite_code. */
export async function getMyInviteCode(): Promise<MyInviteCode | null> {
  const { data, error } = await supabase.rpc('get_or_create_my_invite_code');
  if (error || !data) return null;
  const row = Array.isArray(data) ? data[0] : data;
  return row ? (row as MyInviteCode) : null;
}

export async function syncProfile(userId: string, email: string | null): Promise<UserProfile> {
  const { data } = await supabase.from('profiles').select('*').eq('id', userId);
  const row = (data as ProfileRow[] | null)?.[0];
  if (row) return mapProfile(row, email ?? undefined);
  // Create a minimal row if missing.
  await supabase.from('profiles').upsert({ id: userId, email }).then(() => {});
  return {
    id: userId, name: email ?? 'User', handle: '', role: '', bio: '', location: '',
    followers: '0', engagement: '0%', deals: '0', isAdmin: false, avatarUrl: null,
    notificationsEnabled: true, activityStatus: true, dataSharing: true,
  };
}

export async function getAccountFlags(userId: string): Promise<{ isAdmin: boolean; mustChangePassword: boolean }> {
  const { data } = await supabase
    .from('profiles')
    .select('is_admin,must_change_password')
    .eq('id', userId);
  const row = (data as any[] | null)?.[0];
  return { isAdmin: row?.is_admin ?? false, mustChangePassword: row?.must_change_password ?? false };
}

export async function updateProfile(
  userId: string,
  fields: { name: string; bio: string; location: string; handle?: string; avatarUrl?: string | null },
): Promise<void> {
  const payload: Record<string, unknown> = {
    id: userId, name: fields.name, bio: fields.bio, location: fields.location,
  };
  if (fields.handle !== undefined) payload.handle = fields.handle;
  if (fields.avatarUrl !== undefined) payload.avatar_url = fields.avatarUrl;
  const { error } = await supabase.from('profiles').upsert(payload);
  // Postgres unique_violation → the handle is taken by someone else.
  if (error) {
    if ((error as { code?: string }).code === '23505') throw new Error('HANDLE_TAKEN');
    throw error;
  }
}

/** True when `handle` is free (not used by another profile). Case-insensitive. */
export async function isHandleAvailable(handle: string, userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('profiles')
    .select('id')
    .ilike('handle', handle)
    .neq('id', userId)
    .limit(1);
  if (error) return true; // don't block on a check failure; the upsert still guards
  return ((data as any[]) ?? []).length === 0;
}

export async function acceptTerms(userId: string): Promise<void> {
  await supabase.from('profiles').update({ terms_accepted_at: new Date().toISOString() }).eq('id', userId);
}

/** Uploads an image to a bucket and returns the public/stored path. */
async function uploadFile(bucket: string, path: string, uri: string, contentType: string, upsert = false): Promise<void> {
  const res = await fetch(uri);
  const arrayBuffer = await res.arrayBuffer();
  const { error } = await supabase.storage.from(bucket).upload(path, arrayBuffer, { contentType, upsert });
  if (error) throw error;
}

export async function uploadAvatar(userId: string, uri: string): Promise<string> {
  const folder = userId.toLowerCase();
  const path = `${folder}/avatar-${cryptoRandom()}.jpg`;
  await uploadFile('avatars', path, uri, 'image/jpeg', true);
  const { data } = supabase.storage.from('avatars').getPublicUrl(path);
  return data.publicUrl;
}

// ─────────────────────────── Conversations (inbox) ───────────────────────────

export async function loadConversations(uid: string, blockedIds: Set<string>, myName = ''): Promise<Conversation[]> {
  const [dms, groups] = await Promise.all([loadDMThreads(uid), loadGroupThreads(uid, myName)]);
  return [...dms, ...groups]
    .filter((c) => (c.otherUserId ? !blockedIds.has(c.otherUserId) : true))
    .sort((a, b) => (b.lastMessageAt ?? '').localeCompare(a.lastMessageAt ?? ''));
}

async function loadDMThreads(uid: string): Promise<Conversation[]> {
  const { data, error } = await supabase.rpc('list_dm_threads');
  if (error || !data) return [];
  return (data as any[]).map((row) => {
    const name = row.other_name ?? row.other_handle ?? 'User';
    return {
      id: row.thread_id,
      name,
      avatarColors: avatarGradient(row.other_id),
      avatarUrl: row.other_avatar_url ?? null,
      lastMessage: row.last_message ?? '',
      time: relativeTime(row.last_message_at),
      unread: Math.max(0, row.unread_count ?? 0),
      isGroup: false,
      participantCount: 0,
      otherUserId: row.other_id,
      lastMessageAt: row.last_message_at ?? null,
      lastFromMe: row.last_sender_id === uid,
      lastMessageType: row.last_message_type ?? 'text',
      lastMessageRecalled: row.last_message_recalled ?? false,
      mentioned: false,
      isOnline: false,
      isOfficial: false,
    } as Conversation;
  });
}

/** Group ids that have any UNREAD message @-mentioning me (or @everyone). Uses
 *  each group's read cursor (group_members.last_read_at) so the flag persists as
 *  long as the mention is unread — not just when it's the latest message. */
async function loadMentionedGroupIds(uid: string, myName: string): Promise<Set<string>> {
  const result = new Set<string>();
  const { data: mem } = await supabase
    .from('group_members')
    .select('group_id,last_read_at')
    .eq('user_id', uid);
  const rows = (mem as any[]) ?? [];
  if (rows.length === 0) return result;
  const lastRead = new Map<string, string | null>();
  rows.forEach((m) => lastRead.set(m.group_id, m.last_read_at ?? null));
  const groupIds = rows.map((m) => m.group_id as string);

  const { data: msgs } = await supabase
    .from('group_messages')
    .select('group_id,body,created_at,sender_id')
    .in('group_id', groupIds)
    .neq('sender_id', uid)
    .ilike('body', '%@%')
    .order('created_at', { ascending: false })
    .limit(300);

  for (const m of ((msgs as any[]) ?? [])) {
    if (result.has(m.group_id)) continue;
    const lr = lastRead.get(m.group_id);
    if (lr && m.created_at && m.created_at <= lr) continue; // already read
    if (messageMentionsMe(m.body ?? '', myName)) result.add(m.group_id);
  }
  return result;
}

async function loadGroupThreads(uid: string, myName = ''): Promise<Conversation[]> {
  const [threadsRes, mentionedSet] = await Promise.all([
    supabase.rpc('list_group_threads'),
    loadMentionedGroupIds(uid, myName).catch(() => new Set<string>()),
  ]);
  const { data, error } = threadsRes;
  if (error || !data) return [];
  const rows = data as any[];

  // Resolve last-sender display names so group previews read "Name: message".
  const senderIds = Array.from(
    new Set(rows.map((r) => r.last_sender_id).filter((id: string | null) => id && id !== uid)),
  ) as string[];
  const nameById: Record<string, string> = {};
  if (senderIds.length) {
    const { data: profs } = await supabase.from('profiles').select('id,name,handle').in('id', senderIds);
    for (const p of ((profs as any[]) ?? [])) nameById[p.id] = p.name ?? p.handle ?? 'User';
  }

  return rows.map((row) => {
    const fromMe = row.last_sender_id === uid;
    const recalled = row.last_message_recalled ?? false;
    const rawBody = row.last_message ?? '';
    const mentioned = mentionedSet.has(row.group_id);
    let preview = rawBody;
    if (preview && !recalled && !fromMe && row.last_sender_id) {
      const sn = nameById[row.last_sender_id];
      if (sn) preview = `${sn}: ${preview}`;
    }
    return {
      id: row.group_id,
      name: row.name && row.name.length ? row.name : 'Group',
      avatarColors: avatarGradient(row.group_id),
      avatarUrl: row.avatar_url ?? null,
      lastMessage: preview,
      time: relativeTime(row.last_message_at),
      unread: Math.max(0, row.unread_count ?? 0),
      isGroup: true,
      participantCount: row.member_count ?? 0,
      otherUserId: null,
      lastMessageAt: row.last_message_at ?? null,
      lastFromMe: fromMe,
      lastMessageType: row.last_message_type ?? 'text',
      lastMessageRecalled: recalled,
      mentioned,
      isOnline: false,
      isOfficial: false,
    } as Conversation;
  });
}

// ─────────────────────────── Contacts / Friends ───────────────────────────

/** Display name for a single profile id (QR-scan confirmation preview). Null if not found. */
export async function getProfileName(id: string): Promise<string | null> {
  const { data } = await supabase.from('profiles').select('name').eq('id', id).maybeSingle();
  return (data?.name as string | undefined) ?? null;
}

function mapContact(p: ProfileRow): Contact {
  return {
    id: p.id,
    name: p.name ?? p.handle ?? 'User',
    handle: p.handle ?? '',
    role: p.role ?? '',
    platform: '',
    followers: p.followers ?? '0',
    avatarColors: avatarGradient(p.id),
    avatarUrl: p.avatar_url,
    isOnline: false,
  };
}

export async function loadContacts(uid: string, blockedIds: Set<string>): Promise<Contact[]> {
  const { data: links } = await supabase.from('friendships').select('friend_id').eq('user_id', uid);
  const friendIds = ((links as any[]) ?? []).map((l) => l.friend_id as string);
  if (friendIds.length === 0) return [];
  const { data: profs } = await supabase.from('profiles').select('*').in('id', friendIds);
  return ((profs as ProfileRow[]) ?? [])
    .map(mapContact)
    .filter((c) => !blockedIds.has(c.id))
    .sort((a, b) => a.name.localeCompare(b.name));
}

export async function loadFriendRequests(uid: string): Promise<FriendRequest[]> {
  const { data } = await supabase
    .from('friend_requests')
    .select('*')
    .eq('to_user_id', uid)
    .eq('status', 'pending')
    .order('created_at', { ascending: false });
  return ((data as any[]) ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    handle: row.handle ?? '',
    role: row.role ?? '',
    avatarColors: parseColors(row.avatar_colors),
    requestMessage: row.request_message ?? '',
  }));
}

export async function searchUsers(query: string, blockedIds: Set<string>): Promise<SearchUserResult[]> {
  const trimmed = query.trim();
  if (trimmed.length < 2) return [];
  const { data, error } = await supabase.rpc('search_users', { search_query: trimmed });
  if (error || !data) return [];
  return (data as SearchUserResult[]).filter((u) => !blockedIds.has(u.id));
}

export async function sendFriendRequest(targetId: string, message: string): Promise<string> {
  const { data, error } = await supabase.rpc('send_friend_request', { target_id: targetId, message });
  if (error) throw error;
  return data as string;
}

export async function respondFriendRequest(requestId: string, accept: boolean): Promise<string> {
  const { data, error } = await supabase.rpc('respond_friend_request', { request_id: requestId, accept });
  if (error) throw error;
  return data as string;
}

export async function removeFriend(friendId: string): Promise<void> {
  const { error } = await supabase.rpc('remove_friend', { target_id: friendId });
  if (error) throw error;
}

/** Names of people who accepted a friend request I sent and that I haven't been
 *  shown yet (drives the "X accepted your request" prompt). Mirrors the Swift app. */
export async function loadAcceptedFriendNames(uid: string): Promise<string[]> {
  const { data: rows } = await supabase
    .from('friend_requests')
    .select('to_user_id')
    .eq('from_user_id', uid)
    .eq('status', 'accepted')
    .eq('seen_by_sender', false);
  const list = (rows as any[]) ?? [];
  if (!list.length) return [];
  const ids = list.map((r) => r.to_user_id);
  const { data: profs } = await supabase.from('profiles').select('id,name,handle').in('id', ids);
  const nameById: Record<string, string> = {};
  for (const p of (((profs as any[]) ?? []))) nameById[p.id] = p.name ?? p.handle ?? 'Someone';
  return list.map((r) => nameById[r.to_user_id]).filter(Boolean);
}

/** Marks my accepted requests as seen, clearing the in-app prompt. */
export async function markFriendAcceptancesSeen(uid: string): Promise<void> {
  await supabase
    .from('friend_requests')
    .update({ seen_by_sender: true })
    .eq('from_user_id', uid)
    .eq('status', 'accepted')
    .eq('seen_by_sender', false);
}

// ─────────────────────────── Direct messages (1:1) ───────────────────────────

export async function getOrCreateThread(otherId: string): Promise<string> {
  const { data, error } = await supabase.rpc('get_or_create_thread', { p_other: otherId });
  if (error) throw error;
  return data as string;
}

export async function sendMessage(otherId: string, body: string, replyTo?: string | null): Promise<string> {
  const { data, error } = await supabase.rpc('send_dm', { p_other: otherId, p_body: body, p_reply_to: replyTo ?? null });
  if (error) throw error;
  return data as string;
}

export async function loadThreadMessages(threadId: string, uid: string): Promise<ChatMessage[]> {
  const [{ data: rows }, { data: deletions }, { data: clears }] = await Promise.all([
    supabase.from('dm_messages').select('*').eq('thread_id', threadId).order('created_at', { ascending: true }),
    supabase.from('message_deletions').select('message_id,kind').eq('user_id', uid).eq('kind', 'dm'),
    supabase.from('dm_clears').select('thread_id,cleared_before').eq('user_id', uid).eq('thread_id', threadId),
  ]);
  const deleted = new Set(((deletions as any[]) ?? []).map((d) => d.message_id as string));
  const clearedBefore = ((clears as any[]) ?? [])[0]?.cleared_before as string | undefined;
  return ((rows as any[]) ?? [])
    .filter((r) => !deleted.has(r.id))
    .filter((r) => !(clearedBefore && r.created_at && r.created_at <= clearedBefore))
    .map((r) => {
      const recalled = !!r.recalled_at;
      let kind = recalled ? 'text' : (r.message_type ?? 'text');
      if (!recalled && kind === 'file') {
        const mimeIsAudio = typeof r.file_mime === 'string' && r.file_mime.startsWith('audio');
        const nameIsAudio = typeof r.file_name === 'string' && (r.file_name === 'voice.m4a' || /\.(m4a|mp3|aac|wav|ogg)$/i.test(r.file_name));
        if (mimeIsAudio || nameIsAudio) kind = 'audio';
      }
      return {
        id: r.id,
        text: recalled ? '' : r.body,
        sender: r.sender_id === uid ? 'me' : 'them',
        senderId: r.sender_id,
        time: clockTime(r.created_at),
        kind,
        imagePath: recalled ? null : r.image_url,
        imageWidth: recalled ? null : r.image_width,
        imageHeight: recalled ? null : r.image_height,
        fileName: recalled ? null : r.file_name,
        fileSize: recalled ? null : r.file_size,
        fileMime: recalled ? null : r.file_mime,
        readAt: r.read_at,
        replyTo: r.reply_to_message_id,
        isRecalled: recalled,
        createdAt: r.created_at,
      } as ChatMessage;
    });
}

export async function markThreadRead(threadId: string): Promise<void> {
  await supabase.rpc('mark_thread_read', { p_thread: threadId });
}

/** Pick a storage extension + content-type from the picked asset's MIME so that
 *  animated GIFs (and PNG/WebP) keep their real format instead of becoming a
 *  static JPEG. */
function imageUpload(mime?: string | null): { ext: string; contentType: string } {
  const m = (mime ?? '').toLowerCase();
  if (m.includes('gif')) return { ext: 'gif', contentType: 'image/gif' };
  if (m.includes('png')) return { ext: 'png', contentType: 'image/png' };
  if (m.includes('webp')) return { ext: 'webp', contentType: 'image/webp' };
  return { ext: 'jpg', contentType: 'image/jpeg' };
}

export async function sendImageMessage(otherId: string, threadId: string, uri: string, width: number, height: number, caption = '', mimeType?: string | null): Promise<void> {
  const img = await maybeCompressImage(uri, mimeType, width);
  const { ext, contentType } = imageUpload(img.mime);
  const path = `${threadId.toLowerCase()}/${cryptoRandom()}.${ext}`;
  await uploadFile('chat-media', path, img.uri, contentType, false);
  const { error } = await supabase.rpc('send_dm_media', {
    p_other: otherId, p_image_url: path, p_caption: caption, p_width: width, p_height: height, p_reply_to: null,
  });
  if (error) throw error;
}

/** Uploads a picked video to chat-media, then sends it as a 1:1 video attachment.
 *  ("video" is one of the allowed message_type values, unlike audio.) */
export async function sendVideoMessage(otherId: string, threadId: string, uri: string): Promise<void> {
  const compressed = await maybeCompressVideo(uri);
  const path = `${threadId.toLowerCase()}/${cryptoRandom()}.mp4`;
  await uploadFile('chat-media', path, compressed, 'video/mp4', false);
  const { error } = await supabase.rpc('send_dm_attachment', {
    p_other: otherId, p_type: 'video', p_path: path, p_caption: '',
    p_file_name: 'video.mp4', p_file_size: null, p_file_mime: 'video/mp4', p_reply_to: null,
  });
  if (error) throw error;
}

export async function sendFileMessage(
  otherId: string, threadId: string, uri: string, fileName: string, fileSize: number | null, fileMime: string,
): Promise<void> {
  const ext = (fileName.split('.').pop() || 'bin').toLowerCase();
  const mime = fileMime || 'application/octet-stream';
  const path = `${threadId.toLowerCase()}/${cryptoRandom()}.${ext}`;
  await uploadFile('chat-media', path, uri, mime, false);
  const { error } = await supabase.rpc('send_dm_attachment', {
    p_other: otherId, p_type: 'file', p_path: path, p_caption: '',
    p_file_name: fileName, p_file_size: fileSize, p_file_mime: mime, p_reply_to: null,
  });
  if (error) throw error;
}

/** Uploads a recorded voice clip to chat-media, then sends it as a 1:1 audio attachment. */
export async function sendVoiceMessage(otherId: string, threadId: string, uri: string): Promise<void> {
  const path = `${threadId.toLowerCase()}/${cryptoRandom()}.m4a`;
  await uploadFile('chat-media', path, uri, 'audio/m4a', false);
  const { error } = await supabase.rpc('send_dm_attachment', {
    p_other: otherId, p_type: 'file', p_path: path, p_caption: '',
    p_file_name: 'voice.m4a', p_file_size: null, p_file_mime: 'audio/m4a', p_reply_to: null,
  });
  if (error) throw error;
}

const signedCache = new Map<string, { url: string; expires: number }>();
export async function signedMediaUrl(path: string): Promise<string> {
  const cached = signedCache.get(path);
  if (cached && cached.expires > Date.now() + 120000) return cached.url;
  const { data, error } = await supabase.storage.from('chat-media').createSignedUrl(path, 3600);
  if (error || !data) throw error ?? new Error('sign failed');
  signedCache.set(path, { url: data.signedUrl, expires: Date.now() + 3600000 });
  return data.signedUrl;
}

// ── On-device media cache ──────────────────────────────────────────────────
// Download a media object to a local file ONCE (keyed by its stable storage
// path) and reuse the local copy forever after — so viewing it again costs no
// bandwidth. Lives in cacheDirectory, which the OS may reclaim under pressure.
const MEDIA_CACHE_DIR = `${FileSystem.cacheDirectory ?? ''}wf-media/`;
let mediaCacheDirReady = false;

async function ensureMediaCacheDir(): Promise<void> {
  if (mediaCacheDirReady) return;
  await FileSystem.makeDirectoryAsync(MEDIA_CACHE_DIR, { intermediates: true }).catch(() => {});
  mediaCacheDirReady = true;
}

/** Local file uri for a chat-media `path`, downloading it once if not cached.
 *  Returns a `file://` uri (stable). Falls back to the signed URL if caching
 *  isn't possible (e.g. web). */
export async function cachedMediaUri(path: string, ext = 'mp4'): Promise<string> {
  if (Platform.OS === 'web' || !FileSystem.cacheDirectory) return signedMediaUrl(path);
  try {
    await ensureMediaCacheDir();
    const local = `${MEDIA_CACHE_DIR}${path.replace(/[^a-zA-Z0-9]/g, '_')}.${ext}`;
    const info = await FileSystem.getInfoAsync(local);
    if (info.exists && (info.size ?? 0) > 0) return local;
    const signed = await signedMediaUrl(path);
    const { uri } = await FileSystem.downloadAsync(signed, local);
    return uri;
  } catch {
    return signedMediaUrl(path);
  }
}

// ─────────────────────────── Group chat ───────────────────────────

export async function createGroup(name: string, memberIds: string[]): Promise<string> {
  const { data, error } = await supabase.rpc('create_group', { p_name: name, p_member_ids: memberIds });
  if (error) throw error;
  return data as string;
}

export async function loadGroupMessages(groupId: string, uid: string, blockedIds: Set<string>): Promise<GroupMessage[]> {
  const [{ data: rows }, { data: deletions }, { data: clears }] = await Promise.all([
    supabase
      .from('group_messages')
      .select('id,group_id,sender_id,body,message_type,image_url,image_width,image_height,file_name,file_size,file_mime,created_at,reply_to_message_id,recalled_at,recalled_by,sender:profiles!group_messages_sender_id_fkey(id,name,handle,avatar_url)')
      .eq('group_id', groupId)
      .order('created_at', { ascending: true }),
    supabase.from('message_deletions').select('message_id,kind').eq('user_id', uid).eq('kind', 'group'),
    supabase.from('group_clears').select('group_id,cleared_before').eq('user_id', uid).eq('group_id', groupId),
  ]);
  const deleted = new Set(((deletions as any[]) ?? []).map((d) => d.message_id as string));
  const clearedBefore = ((clears as any[]) ?? [])[0]?.cleared_before as string | undefined;
  return ((rows as any[]) ?? [])
    .filter((r) => !deleted.has(r.id))
    .filter((r) => !(clearedBefore && r.created_at && r.created_at <= clearedBefore))
    .filter((r) => !blockedIds.has(r.sender_id))
    .map((r) => {
      const recalled = !!r.recalled_at;
      let kind = recalled ? 'text' : (r.message_type ?? 'text');
      if (!recalled && kind === 'file') {
        const mimeIsAudio = typeof r.file_mime === 'string' && r.file_mime.startsWith('audio');
        const nameIsAudio = typeof r.file_name === 'string' && (r.file_name === 'voice.m4a' || /\.(m4a|mp3|aac|wav|ogg)$/i.test(r.file_name));
        if (mimeIsAudio || nameIsAudio) kind = 'audio';
      }
      const sender = r.sender ?? {};
      return {
        id: r.id,
        text: recalled ? '' : r.body,
        sender: r.sender_id === uid ? 'me' : 'them',
        senderId: r.sender_id,
        senderName: sender.name ?? sender.handle ?? 'User',
        senderAvatarUrl: sender.avatar_url ?? null,
        time: clockTime(r.created_at),
        kind,
        imagePath: recalled ? null : r.image_url,
        imageWidth: recalled ? null : r.image_width,
        imageHeight: recalled ? null : r.image_height,
        fileName: recalled ? null : r.file_name,
        fileSize: recalled ? null : r.file_size,
        fileMime: recalled ? null : r.file_mime,
        replyTo: r.reply_to_message_id ?? null,
        isRecalled: recalled,
        createdAt: r.created_at,
      } as GroupMessage;
    });
}

export async function sendGroupMessage(groupId: string, body: string, replyTo?: string | null): Promise<void> {
  const { error } = await supabase.rpc('send_group_message', { p_group: groupId, p_body: body, p_reply_to: replyTo ?? null });
  if (error) throw error;
}

export async function sendGroupImage(groupId: string, uri: string, width: number, height: number, caption = '', mimeType?: string | null): Promise<void> {
  const img = await maybeCompressImage(uri, mimeType, width);
  const { ext, contentType } = imageUpload(img.mime);
  const path = `${groupId.toLowerCase()}/${cryptoRandom()}.${ext}`;
  await uploadFile('chat-media', path, img.uri, contentType, false);
  const { error } = await supabase.rpc('send_group_attachment', {
    p_group: groupId, p_type: 'image', p_path: path, p_caption: caption,
    p_file_name: null, p_file_size: null, p_file_mime: contentType, p_width: width, p_height: height, p_reply_to: null,
  });
  if (error) throw error;
}

/** Uploads a picked video to chat-media, then sends it as a group video attachment. */
export async function sendGroupVideo(groupId: string, uri: string): Promise<void> {
  const compressed = await maybeCompressVideo(uri);
  const path = `${groupId.toLowerCase()}/${cryptoRandom()}.mp4`;
  await uploadFile('chat-media', path, compressed, 'video/mp4', false);
  const { error } = await supabase.rpc('send_group_attachment', {
    p_group: groupId, p_type: 'video', p_path: path, p_caption: '',
    p_file_name: 'video.mp4', p_file_size: null, p_file_mime: 'video/mp4',
    p_width: null, p_height: null, p_reply_to: null,
  });
  if (error) throw error;
}

export async function sendGroupFile(
  groupId: string, uri: string, fileName: string, fileSize: number | null, fileMime: string,
): Promise<void> {
  const ext = (fileName.split('.').pop() || 'bin').toLowerCase();
  const mime = fileMime || 'application/octet-stream';
  const path = `${groupId.toLowerCase()}/${cryptoRandom()}.${ext}`;
  await uploadFile('chat-media', path, uri, mime, false);
  const { error } = await supabase.rpc('send_group_attachment', {
    p_group: groupId, p_type: 'file', p_path: path, p_caption: '',
    p_file_name: fileName, p_file_size: fileSize, p_file_mime: mime,
    p_width: null, p_height: null, p_reply_to: null,
  });
  if (error) throw error;
}

/** Uploads a recorded voice clip to chat-media, then sends it as a group audio attachment. */
export async function sendGroupVoice(groupId: string, uri: string): Promise<void> {
  const path = `${groupId.toLowerCase()}/${cryptoRandom()}.m4a`;
  await uploadFile('chat-media', path, uri, 'audio/m4a', false);
  const { error } = await supabase.rpc('send_group_attachment', {
    p_group: groupId, p_type: 'file', p_path: path, p_caption: '',
    p_file_name: 'voice.m4a', p_file_size: null, p_file_mime: 'audio/m4a',
    p_width: null, p_height: null, p_reply_to: null,
  });
  if (error) throw error;
}

export async function markGroupRead(groupId: string): Promise<void> {
  await supabase.rpc('mark_group_read', { p_group: groupId });
}

export async function listGroupMembers(groupId: string): Promise<GroupMember[]> {
  const { data, error } = await supabase.rpc('list_group_members', { p_group: groupId });
  if (error || !data) return [];
  return (data as any[]).map((r) => ({
    id: r.user_id, name: r.name ?? r.handle ?? 'User', handle: r.handle ?? '',
    avatarUrl: r.avatar_url ?? null, role: r.role, isOwner: r.is_owner,
  }));
}

export async function renameGroup(groupId: string, name: string): Promise<void> {
  const { error } = await supabase.rpc('group_rename', { p_group: groupId, p_name: name });
  if (error) throw error;
}
export async function addGroupMember(groupId: string, userId: string): Promise<void> {
  const { error } = await supabase.rpc('group_add_member', { p_group: groupId, p_user: userId });
  if (error) throw error;
}
export async function removeGroupMember(groupId: string, userId: string): Promise<void> {
  const { error } = await supabase.rpc('group_remove_member', { p_group: groupId, p_user: userId });
  if (error) throw error;
}

/** Sets a group's avatar (owner). Uploads to the public avatars bucket, then
 *  stores the URL on group_threads via a SECURITY DEFINER RPC (avoids RLS on the
 *  direct table update). */
export async function changeGroupAvatar(groupId: string, uri: string): Promise<string> {
  const path = `group-${groupId.toLowerCase()}/avatar-${cryptoRandom()}.jpg`;
  await uploadFile('avatars', path, uri, 'image/jpeg', true);
  const { data: pub } = supabase.storage.from('avatars').getPublicUrl(path);
  const url = pub.publicUrl;
  const { error } = await supabase.rpc('group_set_avatar', { p_group: groupId, p_url: url });
  if (error) throw error;
  return url;
}

/** Leaves a group (removes my own membership row). */
export async function leaveGroup(groupId: string, uid: string): Promise<void> {
  const { error } = await supabase.from('group_members').delete().eq('group_id', groupId).eq('user_id', uid);
  if (error) throw error;
}

/** Dissolves a group entirely (owner). Relies on owner-scoped delete RLS;
 *  member/message rows should cascade. */
export async function dissolveGroup(groupId: string): Promise<void> {
  const { error } = await supabase.from('group_threads').delete().eq('id', groupId);
  if (error) throw error;
}

// ─────────────────────────── Forward ───────────────────────────

/** Forwards a message to friends and/or groups via the forward-message edge
 *  function (server-side copies media + re-sends). */
export async function forwardMessage(
  source: { kind: 'dm' | 'group'; messageId: string },
  friendIds: string[],
  groupIds: string[],
): Promise<void> {
  const targets = [
    ...friendIds.map((id) => ({ kind: 'friend', id })),
    ...groupIds.map((id) => ({ kind: 'group', id })),
  ];
  if (targets.length === 0) return;
  const { data, error } = await supabase.functions.invoke('forward-message', {
    body: { source, targets },
  });
  if (error) throw error;
  if (data && (data as { ok?: boolean }).ok === false) throw new Error('forward failed');
}

// ─────────────────────────── Delete / recall / clear ───────────────────────────

export async function deleteMessageForMe(messageId: string, kind: 'dm' | 'group'): Promise<void> {
  await supabase.rpc('delete_message_for_me', { p_message_id: messageId, p_kind: kind });
}
export async function recallMessage(messageId: string, kind: 'dm' | 'group'): Promise<void> {
  const { error } = await supabase.rpc('recall_message', { p_message_id: messageId, p_kind: kind });
  if (error) throw error;
}
export async function clearDMHistory(threadId: string): Promise<void> {
  await supabase.rpc('clear_dm_history', { p_thread_id: threadId });
}
export async function clearGroupHistory(groupId: string): Promise<void> {
  await supabase.rpc('clear_group_history', { p_group_id: groupId });
}
export async function hideConversation(id: string, type: 'dm' | 'group'): Promise<void> {
  await supabase.rpc('hide_conversation', { p_conversation_id: id, p_conversation_type: type });
}

// ─────────────────────────── Discover ───────────────────────────

// Discover now shows ONLY real DB rows — no SampleData/demo fallback. The two
// list_discover_* RPCs return the curated, ordered shapes (brands featured-first
// then name; campaigns newest-first). On any error we return empty arrays so the
// UI shows a friendly empty state rather than fake content.

/** Map a list_discover_brands() row to a Brand. */
function mapDiscoverBrand(r: any): Brand {
  return {
    id: r.id,
    name: r.name,
    category: r.category ?? '',
    tagline: r.tagline ?? '',
    symbol: r.symbol ?? 'sparkles',
    colors: parseColors(r.colors),
    activeCampaigns: r.active_campaigns ?? 0,
    iconUrl: r.icon_url ?? null,
    featuredRank: r.featured_rank ?? null,
    applicationCount: Number(r.application_count ?? 0),
  };
}

/** Map a list_discover_campaigns() row to a Campaign. */
function mapDiscoverCampaign(r: any): Campaign {
  return {
    id: r.id,
    title: r.title,
    brand: r.brand ?? '',
    brandId: r.brand_id ?? null,
    budget: r.budget ?? '',
    tags: r.tags ?? [],
    deadline: r.deadline ?? '',
    description: r.description ?? '',
    symbol: r.symbol ?? 'sparkles',
    colors: parseColors(r.colors),
    spotsLeft: r.spots_left ?? 0,
    iconUrl: r.icon_url ?? null,
    applicationCount: Number(r.application_count ?? 0),
    applied: !!r.applied,
  };
}

export async function loadDiscover(): Promise<{ brands: Brand[]; campaigns: Campaign[] }> {
  try {
    const [{ data: b, error: be }, { data: c, error: ce }] = await Promise.all([
      supabase.rpc('list_discover_brands'),
      supabase.rpc('list_discover_campaigns'),
    ]);
    if (be || ce) return { brands: [], campaigns: [] };
    return {
      brands: ((b as any[]) ?? []).map(mapDiscoverBrand),
      campaigns: ((c as any[]) ?? []).map(mapDiscoverCampaign),
    };
  } catch {
    return { brands: [], campaigns: [] };
  }
}

/** Apply to a campaign (idempotent; server decrements spots_left once). */
export async function applyToCampaign(campaignId: string): Promise<void> {
  const { error } = await supabase.rpc('apply_to_campaign', { p_campaign: campaignId });
  if (error) throw error;
}

/** Withdraw a previous application (gives the spot back). */
export async function withdrawFromCampaign(campaignId: string): Promise<void> {
  const { error } = await supabase.rpc('withdraw_from_campaign', { p_campaign: campaignId });
  if (error) throw error;
}

/** The caller's applied campaign ids — the server is the source of truth for
 *  "Applied" state (the on-device cache is just a fast mirror). */
export async function loadMyApplications(): Promise<string[]> {
  const { data, error } = await supabase.rpc('list_my_applications');
  if (error || !data) return [];
  // The RPC returns a setof uuid — rows may be bare strings or {…} objects.
  return (data as any[]).map((row) => (typeof row === 'string' ? row : (row.id ?? row))).filter(Boolean);
}

/** Uploads a brand/campaign icon to the public `discover` bucket and returns its
 *  public URL (stored on the row via the admin upsert RPCs). */
export async function uploadDiscoverIcon(kind: 'brands' | 'campaigns', id: string, uri: string): Promise<string> {
  const img = await maybeCompressImage(uri);
  const path = `${kind}/${id}-${cryptoRandom()}.jpg`;
  await uploadFile('discover', path, img.uri, 'image/jpeg', true);
  const { data } = supabase.storage.from('discover').getPublicUrl(path);
  return data.publicUrl;
}

// ─────────────────── Discover admin curation (is_admin-gated RPCs) ───────────────────
// Mirrors the Swift AppDataService admin-curation methods. Every RPC is
// is_admin-gated server-side. Reads go straight to the public tables (no
// SampleData fallback — the admin view must only show real, editable rows).

/** Parse a hex string ("#FF4D6D" / "FF4D6D") into a decimal int (e.g. 16730477).
 *  Falls back to the brand coral/tangerine ints used across the app. */
function hexToInt(s: string, fallback: number): number {
  const cleaned = s.trim().replace(/^#/, '');
  const n = parseInt(cleaned, 16);
  return Number.isFinite(n) ? n & 0xffffff : fallback;
}

/** Map a raw `brands` row (from select('*')) to a Brand, carrying featuredRank. */
function mapBrandRow(r: any): Brand {
  return {
    id: r.id, name: r.name, category: r.category ?? '', tagline: r.tagline ?? '',
    symbol: r.symbol ?? 'sparkles', colors: parseColors(r.colors), activeCampaigns: r.active_campaigns ?? 0,
    iconUrl: r.icon_url ?? null,
    featuredRank: r.featured_rank ?? null,
    applicationCount: Number(r.application_count ?? 0),
  };
}

/** Map a raw `campaigns` row (from select('*')) to a Campaign. */
function mapCampaignRow(r: any): Campaign {
  return {
    id: r.id, title: r.title, brand: r.brand, brandId: r.brand_id ?? null,
    budget: r.budget ?? '', tags: r.tags ?? [], deadline: r.deadline ?? '',
    description: r.description ?? '',
    symbol: r.symbol ?? 'sparkles', colors: parseColors(r.colors), spotsLeft: r.spots_left ?? 0,
    iconUrl: r.icon_url ?? null,
    applicationCount: Number(r.application_count ?? 0),
    applied: !!r.applied,
  };
}

/** A Brand plus its featured rank (null = not featured) — the admin list shape. */
export type AdminBrand = Brand & { featuredRank: number | null };

/** Admin: all brands, name-sorted, straight from the table (no SampleData
 *  fallback). Mirrors Swift's loadBrandsForAdmin. */
export async function loadBrandsForAdmin(): Promise<AdminBrand[]> {
  const { data, error } = await supabase.from('brands').select('*').order('name', { ascending: true });
  if (error) throw error;
  return ((data as any[]) ?? []).map(mapBrandRow);
}

/** Admin: create (id null) or update a brand (admin_upsert_brand RPC). Colors are
 *  sent as the JSON int-array string parseColors expects. Returns the brand id. */
export async function adminUpsertBrand(args: {
  id?: string | null;
  name: string;
  category?: string | null;
  tagline?: string | null;
  symbol?: string | null;
  color1?: string;
  color2?: string;
  activeCampaigns?: number | null;
  featuredRank?: number | null;
  iconUrl?: string | null;
}): Promise<string> {
  // colors/symbol are now only the DEFAULT fallback look (the icon image, when
  // uploaded, takes over). The RPC still needs them, so send the brand defaults
  // when the editor no longer collects them.
  const c1 = hexToInt(args.color1 ?? '', 0xff4d6d);
  const c2 = hexToInt(args.color2 ?? '', 0xff9a5a);
  const { data, error } = await supabase.rpc('admin_upsert_brand', {
    brand_id: args.id ?? null,
    p_name: args.name,
    p_category: args.category ?? null,
    p_tagline: args.tagline ?? null,
    p_symbol: args.symbol ?? null,
    p_colors: `[${c1},${c2}]`,
    p_active_campaigns: args.activeCampaigns ?? null,
    p_featured_rank: args.featuredRank ?? null,
    p_icon_url: args.iconUrl ?? null,
  });
  if (error) throw error;
  return data as string;
}

/** Admin: delete a brand (admin_delete_brand RPC). */
export async function adminDeleteBrand(id: string): Promise<void> {
  const { error } = await supabase.rpc('admin_delete_brand', { target: id });
  if (error) throw error;
}

/** Admin: feature / reorder / unfeature a brand (admin_set_featured_brand RPC).
 *  rank null = unfeature. */
export async function adminSetFeaturedBrand(brandId: string, rank: number | null): Promise<void> {
  const { error } = await supabase.rpc('admin_set_featured_brand', { target: brandId, rank });
  if (error) throw error;
}

/** Admin: all campaigns, newest first, straight from the table (no SampleData
 *  fallback). Mirrors Swift's loadCampaignsForAdmin. */
export async function loadCampaignsForAdmin(): Promise<Campaign[]> {
  const { data, error } = await supabase.from('campaigns').select('*').order('created_at', { ascending: false });
  if (error) throw error;
  return ((data as any[]) ?? []).map(mapCampaignRow);
}

/** Admin: create (id null) or update a campaign (admin_upsert_campaign RPC).
 *  Colors are sent as two decimal-int strings (color_a / color_b); the SQL
 *  combines them into the JSON `[a,b]` text parseColors expects. Returns the id. */
export async function adminUpsertCampaign(args: {
  id?: string | null;
  title: string;
  brand?: string | null;
  budget?: string | null;
  tags?: string[] | null;
  deadline?: string | null;
  symbol?: string | null;
  color1?: string;
  color2?: string;
  spotsLeft?: number | null;
  iconUrl?: string | null;
  description?: string | null;
  brandId?: string | null;
}): Promise<string> {
  // colors/symbol are now only the DEFAULT fallback look (the icon image, when
  // uploaded, takes over). The RPC still needs them, so send the brand defaults
  // when the editor no longer collects them.
  const a = hexToInt(args.color1 ?? '', 0xff4d6d);
  const b = hexToInt(args.color2 ?? '', 0xff9a5a);
  const { data, error } = await supabase.rpc('admin_upsert_campaign', {
    campaign_id: args.id ?? null,
    p_title: args.title,
    p_brand: args.brand ?? null,
    p_budget: args.budget ?? null,
    p_tags: args.tags ?? null,
    p_deadline: args.deadline ?? null,
    p_symbol: args.symbol ?? null,
    p_color_a: String(a),
    p_color_b: String(b),
    p_spots_left: args.spotsLeft ?? null,
    p_icon_url: args.iconUrl ?? null,
    p_description: args.description ?? null,
    p_brand_id: args.brandId ?? null,
  });
  if (error) throw error;
  return data as string;
}

/** Admin: delete a campaign (admin_delete_campaign RPC). */
export async function adminDeleteCampaign(id: string): Promise<void> {
  const { error } = await supabase.rpc('admin_delete_campaign', { target: id });
  if (error) throw error;
}

// ─────────────────────────── Trust & Safety ───────────────────────────

export async function loadBlocks(uid: string): Promise<Set<string>> {
  const { data } = await supabase.from('blocks').select('blocked_id').eq('blocker_id', uid);
  return new Set(((data as any[]) ?? []).map((r) => r.blocked_id as string));
}

export async function blockUser(uid: string, otherId: string): Promise<void> {
  const { error } = await supabase.from('blocks').upsert({ blocker_id: uid, blocked_id: otherId });
  if (error) throw error;
  try { await removeFriend(otherId); } catch { /* not friends — fine */ }
}

export async function unblockUser(uid: string, otherId: string): Promise<void> {
  const { error } = await supabase.from('blocks').delete().eq('blocker_id', uid).eq('blocked_id', otherId);
  if (error) throw error;
}

export async function loadBlockedContacts(uid: string): Promise<Contact[]> {
  const blocked = await loadBlocks(uid);
  if (blocked.size === 0) return [];
  const { data } = await supabase.from('profiles').select('*').in('id', Array.from(blocked));
  return ((data as ProfileRow[]) ?? []).map(mapContact).sort((a, b) => a.name.localeCompare(b.name));
}

export async function report(args: {
  uid: string; reportedUserId: string | null; messageId?: string | null;
  messageKind?: string | null; excerpt?: string | null; reason: ReportReason;
}): Promise<void> {
  const { error } = await supabase.from('reports').insert({
    reporter_id: args.uid,
    reported_user_id: args.reportedUserId,
    message_id: args.messageId ?? null,
    message_kind: args.messageKind ?? null,
    content_excerpt: args.excerpt ? args.excerpt.slice(0, 280) : null,
    reason: args.reason,
  });
  if (error) throw error;
}

// ─────────────────────────── Admin ───────────────────────────

export async function loadAllUsers(): Promise<AdminUser[]> {
  const { data } = await supabase.from('profiles').select('id,name,email,is_banned,is_admin').order('created_at', { ascending: false });
  return ((data as any[]) ?? []).map((r) => ({
    id: r.id, name: r.name ?? r.email ?? 'User', email: r.email ?? '', isActive: true, banned: !!r.is_banned, isAdmin: r.is_admin ?? false,
  }));
}

/** Admin: ban or unban a user (admin_ban_user RPC). */
export async function adminBanUser(userId: string, ban: boolean): Promise<void> {
  const { error } = await supabase.rpc('admin_ban_user', { target_id: userId, ban });
  if (error) throw error;
}

/** Admin: permanently delete a user (admin_delete_user RPC). */
export async function adminDeleteUser(userId: string): Promise<void> {
  const { error } = await supabase.rpc('admin_delete_user', { target_id: userId });
  if (error) throw error;
}

/** Admin: grant or revoke admin (is_admin) on another user (admin_set_admin RPC).
 *  Server-side this is is_admin-gated and blocks changing your own admin status. */
export async function adminSetAdmin(targetId: string, makeAdmin: boolean): Promise<void> {
  const { error } = await supabase.rpc('admin_set_admin', { target: targetId, make_admin: makeAdmin });
  if (error) throw error;
}

/** Admin: invite a new user by email (invite-user edge function). Returns the
 *  function's {ok,error} so the UI can show a specific message. */
export async function adminInviteUser(email: string): Promise<{ ok?: boolean; error?: string }> {
  const { data, error } = await supabase.functions.invoke('invite-user', { body: { email } });
  if (error) throw error;
  return (data ?? {}) as { ok?: boolean; error?: string };
}

export async function deleteAccount(): Promise<void> {
  const { error } = await supabase.functions.invoke('delete-account');
  if (error) throw error;
}

// ─────────────────────────── helpers ───────────────────────────

/** UUID-ish random id without a crypto dependency (good enough for object paths). */
function cryptoRandom(): string {
  return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
