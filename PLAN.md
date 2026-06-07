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

## Design

- **Welcome screen**: The Wefluens logo centered on a warm gradient background, with email and password fields and Sign In / Create Account buttons. A subtle loading animation appears while authenticating
- **Smooth transition**: After login, the welcome screen fades away and the familiar tab bar slides in, now populated with real cloud data

## Screens

- **Welcome screen** — App icon + tagline + email field + password field + Sign In button. Invite-only, so no public sign-up toggle
- **Set new password** — Shown right after the first login; the user must replace the initial password `11111111`
- **Main app (4 tabs)** — Same Chats / Contacts / Discover / Me layout you already have, now loading real data from the cloud database
- **Profile** — Shows your real name and email from your login account. The Edit Profile screen saves changes to the cloud. Sign Out actually works now
- **Admin Backend** — Admin-only user management dashboard accessible from the Me tab
