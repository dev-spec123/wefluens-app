/**
 * Shared domain + Supabase row types — the shapes the UI consumes.
 * Mapped from the Supabase backend in api.ts (same backend as the Swift app).
 */

// MARK: - Profile

export interface UserProfile {
  id: string;
  name: string;
  handle: string;
  role: string;
  bio: string;
  location: string;
  followers: string;
  engagement: string;
  deals: string;
  isAdmin: boolean;
  avatarUrl: string | null;
  notificationsEnabled: boolean;
  activityStatus: boolean;
  dataSharing: boolean;
}

export interface ProfileRow {
  id: string;
  email: string | null;
  name: string | null;
  avatar_url: string | null;
  handle: string | null;
  role: string | null;
  bio: string | null;
  location: string | null;
  followers: string | null;
  engagement: string | null;
  deals: string | null;
  is_admin: boolean | null;
  notifications_enabled: boolean | null;
  activity_status: boolean | null;
  data_sharing: boolean | null;
  is_full_access: boolean | null;
  must_change_password: boolean | null;
  terms_accepted_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

// MARK: - Conversations / Chat

export type MessageSender = 'me' | 'them';
export type ChatMessageKind = 'text' | 'image' | 'video' | 'file' | 'audio';

/** One row in the chat inbox (a 1:1 thread or a group). */
export interface Conversation {
  id: string; // threadId or groupId
  name: string;
  avatarColors: [string, string];
  avatarUrl: string | null;
  lastMessage: string;
  time: string;
  unread: number;
  isGroup: boolean;
  participantCount: number;
  otherUserId: string | null; // null for groups
  lastMessageAt: string | null;
  lastFromMe: boolean;
  lastMessageType: string;
  lastMessageRecalled: boolean;
  /** True when the latest unread group message @-mentions me (or @everyone). */
  mentioned: boolean;
  /** True when the other user is online (DM presence dot); groups are always false. */
  isOnline: boolean;
  /** True for official / verified accounts — shows a verified badge. */
  isOfficial: boolean;
}

/** A 1:1 message in a thread. */
export interface ChatMessage {
  id: string;
  text: string;
  sender: MessageSender;
  senderId: string;
  time: string;
  kind: ChatMessageKind;
  imagePath: string | null;
  imageWidth: number | null;
  imageHeight: number | null;
  fileName: string | null;
  fileSize: number | null;
  fileMime: string | null;
  readAt: string | null;
  replyTo: string | null;
  isRecalled: boolean;
  createdAt: string | null;
}

/** A group message (carries sender profile for incoming bubbles). */
export interface GroupMessage {
  id: string;
  text: string;
  sender: MessageSender;
  senderId: string;
  senderName: string;
  senderAvatarUrl: string | null;
  time: string;
  kind: ChatMessageKind;
  imagePath: string | null;
  imageWidth: number | null;
  imageHeight: number | null;
  fileName: string | null;
  fileSize: number | null;
  fileMime: string | null;
  replyTo: string | null;
  isRecalled: boolean;
  createdAt: string | null;
}

// MARK: - Contacts / Friends

export interface Contact {
  id: string;
  name: string;
  handle: string;
  role: string;
  platform: string;
  followers: string;
  avatarColors: [string, string];
  avatarUrl: string | null;
  isOnline: boolean;
}

export interface FriendRequest {
  id: string;
  name: string;
  handle: string;
  role: string;
  avatarColors: [string, string];
  requestMessage: string;
}

/** One result of the search_users RPC. relationship ∈ none|friends|request_sent|request_received */
export interface SearchUserResult {
  id: string;
  name: string;
  handle: string;
  role: string;
  avatar_url: string | null;
  followers: string;
  relationship: 'none' | 'friends' | 'request_sent' | 'request_received';
  incoming_request_id: string | null;
}

// MARK: - Discover

export interface Brand {
  id: string;
  name: string;
  category: string;
  tagline: string;
  symbol: string;
  colors: [string, string];
  activeCampaigns: number;
  /** Public URL of an admin-uploaded brand icon; null = fall back to gradient+symbol. */
  iconUrl: string | null;
  /** Non-null = the brand is Featured (精选); the number is its display order. */
  featuredRank: number | null;
  /** How many creators have applied across this brand's campaigns (drives Hot/热门). */
  applicationCount: number;
}

export interface Campaign {
  id: string;
  title: string;
  brand: string;
  /** Owning brand id (null for legacy rows). */
  brandId: string | null;
  budget: string;
  tags: string[];
  deadline: string;
  description: string;
  symbol: string;
  colors: [string, string];
  spotsLeft: number;
  /** Public URL of an admin-uploaded campaign icon; null = fall back to gradient+symbol. */
  iconUrl: string | null;
  /** How many creators have applied to this campaign (server-side count). */
  applicationCount: number;
  /** True when the current user has already applied (seeded from the server). */
  applied: boolean;
}

/** A Discover event an admin publishes and creators sign up to participate in.
 *  Drafts (`published` false) only ever reach the admin screens — the public
 *  Discover read filters them out server-side. */
export interface Event {
  id: string;
  title: string;
  description: string;
  location: string;
  /** ISO timestamps; null when the admin hasn't dated the event yet. */
  startsAt: string | null;
  endsAt: string | null;
  /** Total participant slots; null = uncapped. */
  capacity: number | null;
  /** Remaining slots, derived server-side from the live signup count. Null when
   *  uncapped (the UI then shows no spots figure). */
  spotsLeft: number | null;
  tags: string[];
  brand: string;
  brandId: string | null;
  symbol: string;
  colors: [string, string];
  /** Public URL of an admin-uploaded event icon; null = fall back to gradient+symbol. */
  iconUrl: string | null;
  /** False = draft (admin-only, rejects signups); true = live on Discover. */
  published: boolean;
  /** How many creators have signed up (server-side count). */
  signupCount: number;
  /** True when the current user has already signed up. */
  signedUp: boolean;
}

/** One participant on an event's roster. Admin-only — influencers only ever see
 *  the aggregate signup count. */
export interface EventSignup {
  id: string;
  name: string;
  handle: string;
  role: string;
  email: string;
  avatarUrl: string | null;
  followers: string;
  /** ISO timestamp of when they signed up. */
  signedUpAt: string | null;
}

// MARK: - Groups

export interface GroupMember {
  id: string;
  name: string;
  handle: string;
  avatarUrl: string | null;
  role: string;
  isOwner: boolean;
}

// MARK: - Admin

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  isActive: boolean;
  banned: boolean;
  isAdmin: boolean;
}

// MARK: - Navigation params

export interface DMChatParams {
  threadId: string;
  otherUserId: string;
  title: string;
  avatarUrl?: string | null;
}

export interface GroupChatParams {
  groupId: string;
  title: string;
  memberCount: string;
}

// MARK: - Trust & Safety

export type ReportReason = 'spam' | 'harassment' | 'hate' | 'sexual' | 'violence' | 'other';

/** A report target — a user and/or a specific message. */
export interface ReportTarget {
  reportedUserId: string | null;
  messageId?: string | null;
  messageKind?: string | null; // 'dm' | 'group'
  excerpt?: string | null;
  subjectName: string;
  blockableUserId?: string | null;
}
