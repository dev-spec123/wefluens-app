# Add account system and cloud storage to Wefluens


## Features

- **Sign up & Log in** — Users can create an account or log in using email + password
- **Cloud-synced profile** — After logging in, your name and profile info are saved to the cloud and available on any device
- **Real data storage** — Chats, contacts, friend requests, and Discover content are stored in a cloud database instead of hardcoded samples
- **Secure sign out** — Log out anytime; your data stays safe in the cloud for when you log back in
- [x] Switched from Rork Auth (Google/Apple) to native Supabase Auth (email/password)
- [x] Database migrated from text-based user IDs to UUID (auth.users compatible)
- [x] All RLS policies rewritten from `user_id()` to `auth.uid()`
- [x] Auto-create profile on signup via `handle_new_user()` trigger

## Admin System

- **Admin account** — `jonnyc@wefluens.com` / `11111111` with backend management access
- **Backend Management** — Admin sees an "ADMIN" section in the Me tab with a full user management dashboard
- **User deactivation & deletion** — Admin can deactivate users (block sign-in) or permanently delete accounts
- [x] `is_admin` column added to profiles table with RLS policies for admin operations
- [x] `admin_delete_user` database function for secure user deletion
- [x] Admin-only UI section in ProfileView

## Invite-Only Registration (current)

- **Invite only** — public sign-up removed; the login screen is email + password only
- **Admin invites by email** — admin enters an email in Backend Management; we email an activation link
- **Activation link** — opens a Wefluens-branded web page that creates the account with initial password `11111111`
- **Forced password change** — on first login the user must set a new password before entering the app
- **Voluntary change** — "Change Password" is also available under Privacy & Security
- [x] `invites` table + `must_change_password` flag on profiles (with RLS)
- [x] `invite-user` edge function (admin-only) sends the activation email via Resend
- [x] `activate-invite` edge function (public) creates the confirmed user + branded landing page
- [x] `AuthManager.changePassword` + `ForcePasswordChangeView`, gated in ContentView
- [x] Admin invite UI (InviteUserSheet) in AdminUsersView
- [x] Three-language support (EN / 中文 / ES) for all new strings
- [x] Set `RESEND_API_KEY` env var; both edge functions redeployed to pick it up
- [x] Set `RESEND_FROM` to `Wefluens <invite@wefluens.com>`
- [x] Verified the `wefluens.com` sending domain in Resend (root-domain, GoDaddy) — sends to any recipient
- [x] Root cause of "邮件服务尚未配置" fixed: Rork private env vars never reach the Supabase edge runtime (`Deno.env` only exposes the auto-injected `SUPABASE_*`). Secrets now live in a service-role-only `app_secrets` table that `invite-user` reads at runtime — verified end-to-end with a live Resend send returning HTTP 200 + a real email id
- [x] Split `EMAIL_NOT_CONFIGURED` vs `EMAIL_SEND_FAILED` into distinct in-app messages (EN / 中文 / ES)
- Superseded: the previous 6-digit OTP self-signup flow (replaced by invite links)

## Friends (application-based add-friend)

- **Add Friend** — the Contacts 「邀请」 quick action is now 「添加好友」 (EN: Add Friend / ES: Agregar amigo) and opens a user search sheet. This is friend-to-friend only and never sends any email (completely separate from the admin `invite-user` flow)
- **Search by email or @handle/name** — privacy-safe: a `search_users` SECURITY DEFINER function matches on email but never returns it, and reports my relationship to each result (none / request_sent / request_received / friends)
- **Application-based** — sending creates a `pending` request; the recipient sees it under 「新的朋友」 and can Accept/Decline for real
- **Mutual friends** — accepting creates a bidirectional `friendships` graph; the contact list and the "X creators & partners" count both derive from it
- **In-app prompt** — when my sent request is accepted I get an in-app "X accepted your friend request" alert (no email/push)
- [x] `friendships` table (bidirectional, RLS read/delete own; writes only via SECURITY DEFINER fn)
- [x] `friend_requests`: status CHECK (pending/accepted/rejected), partial unique index blocking duplicate pending, `seen_by_sender` flag, sender-side UPDATE policy
- [x] `search_users`, `send_friend_request`, `respond_friend_request` SECURITY DEFINER functions (grant authenticated)
- [x] `AddFriendView` search sheet + wired 添加好友 button; `FriendRequestDetailView` Accept/Decline now call `respond_friend_request` for real (was local-only); contacts derive from `friendships`
- [x] Three-language support (EN / 中文 / ES) for all new strings
- [x] Live end-to-end verified: A sends → B accepts → friendship a↔b, counts A=1/B=1, request=accepted, RLS isolates each side (no leak), search-by-email returns the user with email hidden
- [x] **Remove friend** — `remove_friend(target_id)` SECURITY DEFINER fn atomically deletes both friendship rows (A→B and B→A) + any leftover requests so re-adding works; `ContactDetailView` has a destructive "Delete Friend" action behind a confirmation dialog (EN/中文/ES). Both sides' contact lists + counts auto-update (derive from `friendships`). Verified via rollback harness: two-sided delete leaves 0 rows on both sides

## Chat (1:1 direct messages)

- **Real one-on-one text chat** — friends-only; sending a message never sends any email (pure database, completely separate from the admin invite flow)
- **Shared conversations** — both people see the same thread and each other's messages, with live updates via Supabase Realtime
- **Unread + previews** — the conversation list shows the last-message preview, relative time, and an unread badge; the Chats tab shows a total-unread red dot; opening a thread marks it read
- [x] `dm_threads` (one row per user pair, `user_low < user_high` normalized + unique) and `dm_messages` (sender/recipient/`read_at`, 1–4000 char CHECK), both RLS participant-only SELECT; no client write policies (all writes via SECURITY DEFINER fns)
- [x] `get_or_create_thread`, `send_dm`, `mark_thread_read`, `list_dm_threads` SECURITY DEFINER functions; friends-only enforced via `are_friends` in `send_dm`/`get_or_create_thread`
- [x] `dm_threads`/`dm_messages` added to the `supabase_realtime` publication (RLS-scoped live delivery to both participants only)
- [x] `ContactDetailView` 「发消息」 button wired to `get_or_create_thread` → real chat screen; `ChatThreadViewModel` sends via `send_dm` and subscribes to live inserts; `ChatsListView` uses `list_dm_threads`; `RootTabView` `observeInbox` keeps the tab badge live
- [x] Old per-user `conversations`/`messages` tables kept but deprecated (not deleted) per request
- [x] Three-language support (EN / 中文 / ES) for all new strings
- [x] iOS build green (`runChecks`) + live end-to-end verified via rollback harness: A→B send persists & creates a shared thread; B sees unread=1 + correct preview + other=A; B replies → A sees unread=1 + reply preview + last_sender=B; A opens → unread=0; thread total=2 msgs; non-friend send blocked; realtime enabled — all rolled back, production untouched

## Chat polish: clean bubbles, photo messages, avatar upload

- **Clean bubbles** — removed the custom `BubbleShape` tail/burr; both sides now use a uniform 20pt continuous rounded rectangle (iMessage-style); styling only, send logic untouched
- **Avatar upload fixed** — the `avatars` Storage bucket never existed (uploads 400'd) and failures were silently swallowed while still showing "saved". Now: public `avatars` bucket + Storage RLS (anyone reads; a user writes only their own `{uid}/` folder), images compressed before upload, and upload failures raise a real error (no fake success). `avatar_url` is persisted and mirrored to the Me page / contacts / chat
- **Photo messages** — the chat `+` button opens the photo library (system-keyboard emoji already work, so no custom panel); images upload to a **private** `chat-media` bucket and display via short-lived signed URLs
- [x] `dm_messages` gained `message_type` (`text`/`image`), `image_url` (private path), `image_width`/`image_height`; body CHECK relaxed so an image may have an empty caption; added `dm_messages_image_present` CHECK
- [x] `send_dm_media` SECURITY DEFINER fn (friends-only, mirrors `send_dm`); `send_dm` + `list_dm_threads` recreated to track `last_message_type`; the list shows a localized `[图片]`/`[Photo]`/`[Foto]` preview for caption-less images
- [x] Private `chat-media` bucket with thread-scoped Storage RLS — only the two thread participants (verified by the thread id in the object path) can read/write; client fetches via `createSignedURL`, cached by path so realtime reloads don't re-sign
- [x] `ChatThreadViewModel.sendImage` (upload → `send_dm_media` → reload), `ChatDetailView` image bubbles + `PhotosPicker`, `ChatsListView` `[图片]` preview; three-language strings (EN / 中文 / ES)
- [x] iOS build green (`runChecks`) + live rollback harness verified: empty-caption image stored as `type=image` w/ dimensions; recipient sees unread=1 + `last_type=image` + `[图片]` preview; captioned image shows its caption; non-friend image blocked; buckets+policies present; realtime enabled — all rolled back, production untouched

### Re-apply pass — the view layer had NOT actually landed; avatar now shown app-wide; invite toast

- [x] `getSchema` confirmed the chat-image backend is genuinely live in production: `dm_messages.message_type/image_url/image_width/image_height` + `dm_threads.last_message_type` all present; `profiles.avatar_url` present with public read
- [x] **Bubbles (re-applied for real):** deleted `BubbleShape` (the tailed shape whose fixed-radius arcs self-intersected into circles/teardrops for short messages) and switched both sides to `RoundedRectangle(cornerRadius: 20, style: .continuous)` — width follows content, never collapses to a circle
- [x] **Photo messages (re-applied for real):** `MessageBubble` gained a real image branch (`ChatImageBubble`) — loads the private `chat-media` object via a cached signed URL, reserves space from stored pixel dimensions to avoid jump, clips to the same 20pt shape; optional caption beneath
- [x] **Avatar shown everywhere:** `Avatar` component now takes `imageURL` (AsyncImage + letter fallback); `avatar_url` propagated through `Conversation`/`Contact`/`DMChatRoute` and rendered on the Me page, chat header, conversation list, and contacts
- [x] **Storage ensured live (idempotent migration):** `avatars` bucket forced `public = true` (true root cause of "avatar saved but shows letters" — a private bucket's public URL 400s on read, no error alert), `chat-media` forced private, both with explicit RLS (avatars: public read + owner-folder writes; chat-media: thread-participant read/write by path)
- [x] **Invite toast:** fixed the bug where clearing the email on success wiped the feedback; added a prominent green success / red failure toast with haptics (EN / 中文 / ES strings already present)
- [x] iOS build green (`runChecks`) after the re-apply pass

## Chat attachments: files (video next)

- **Send a file** — the chat `+` is now a menu (Photo / File); File opens the document picker (PDF / Word / Excel / PowerPoint / text). The file uploads to the private `chat-media` bucket and appears as a chip (type icon + name + size). Tapping it downloads via a signed URL and opens QuickLook. Conversation list shows a localized `[文件]`/`[File]`/`[Archivo]` preview
- **Two-step rollout** — files shipped first; video reuses the same backend (columns + function already live) and is the next step
- [x] Backend migration (one pass, additive + safe): `dm_messages` gained `file_name`/`file_size`/`file_mime`/`thumb_url`/`duration_ms`; `image_url` reused as the generic media path and `image_width/height` as poster dims; `dm_messages_type_check` extended to `text/image/video/file`; `dm_messages_image_present` renamed/generalized to `dm_messages_media_present` (any non-text needs a path); `dm_messages_body_len` left unchanged (already allows empty non-text body)
- [x] New generic `send_dm_attachment` SECURITY DEFINER fn (friends-only, mirrors `send_dm_media`, stamps `last_message_type`) — `send_dm` / `send_dm_media` left untouched; `list_dm_threads` unchanged (already returns `last_message_type`)
- [x] Private `chat-media` reused: same thread-id path-based Storage RLS (extension-agnostic, no new policy); bucket `file_size_limit` raised to 50 MB (covers 25 MB files now + 50 MB video later)
- [x] App: `ChatMessage` gained `.file` kind + name/size/mime; `MessageBubble` gained a `.file` branch only (text + `ChatImageBubble` untouched); new `ChatFileBubble` (icon/name/size chip → QuickLook); `+` menu + `.fileImporter` with a real 25 MB error (never silent); `ChatsListView` `[文件]` preview via `lastMessageType`; three-language strings
- [x] iOS build green (`runChecks`) + live rollback harness verified: A→B `send_dm_attachment` stores `type=file` + path + name/size/mime, empty body allowed; B sees `unread=1` + `last_type=file` + `[文件]` preview + other=A; `media_present` blocks a pathless file; `video` type already accepted (video-ready); non-friend file blocked — all rolled back, production untouched

## Chat: read receipts (step 1 of 2 — quoted replies next)

- **iMessage-style read receipt** — one lightweight gray line under *my most recent* sent message only (never one per bubble): 「已读 / Read / Leído」 once the other person opens the thread, otherwise 「已送达 / Delivered / Entregado」
- **Live flip** — when the recipient opens the thread, `mark_thread_read` stamps `read_at` and the sender's view cross-fades Delivered → Read in real time (no manual refresh)
- [x] Backend (additive, safe): `dm_messages` set to `REPLICA IDENTITY FULL` so Supabase Realtime can evaluate the participant RLS policy on UPDATE events and ship the `read_at` change to the sender; `read_at` + `mark_thread_read` were already in place
- [x] App: `ChatMessage` gained `readAt` (mapped from `read_at`); `ChatThreadViewModel.subscribe` added an `UpdateAction` listener (reload-only, never writes → no loop) alongside the existing insert listener; `ChatDetailView` renders the receipt under `lastMineId` only — `textBubble` / `ChatImageBubble` / `ChatFileBubble` left untouched; three-language strings
- [x] iOS build green (`runChecks`) + live rollback harness verified: A→B `send_dm` leaves `read_at = NULL` (Delivered); B `mark_thread_read` sets `read_at` (Read); `dm_messages` confirmed `REPLICA IDENTITY FULL` + in `supabase_realtime` publication with UPDATE emitted — all rolled back, production untouched
- Next (approved, not started): quoted replies — `reply_to_message_id`, optional `p_reply_to` on the three send fns (DROP+recreate, behavior unchanged when omitted), new `QuotedReplyPreview` above the bubble, long-press → Reply

## Design

- **Welcome screen**: The Wefluens logo centered on a warm gradient background, with email and password fields and Sign In / Create Account buttons. A subtle loading animation appears while authenticating
- **Smooth transition**: After login, the welcome screen fades away and the familiar tab bar slides in, now populated with real cloud data

## Screens

- **Welcome screen** — App icon + tagline + email field + password field + Sign In button. Invite-only, so no public sign-up toggle
- **Set new password** — Shown right after the first login; the user must replace the initial password `11111111`
- **Main app (4 tabs)** — Same Chats / Contacts / Discover / Me layout you already have, now loading real data from the cloud database
- **Profile** — Shows your real name and email from your login account. The Edit Profile screen saves changes to the cloud. Sign Out actually works now
- **Admin Backend** — Admin-only user management dashboard accessible from the Me tab
