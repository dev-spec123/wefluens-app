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
- [ ] Set `RESEND_API_KEY` env var (and verify a sending domain in Resend to email any recipient)
- Superseded: the previous 6-digit OTP self-signup flow (replaced by invite links)

## Design

- **Welcome screen**: The Wefluens logo centered on a warm gradient background, with email and password fields and Sign In / Create Account buttons. A subtle loading animation appears while authenticating
- **Smooth transition**: After login, the welcome screen fades away and the familiar tab bar slides in, now populated with real cloud data

## Screens

- **Welcome screen** — App icon + tagline + email field + password field + Sign In button. Invite-only, so no public sign-up toggle
- **Set new password** — Shown right after the first login; the user must replace the initial password `11111111`
- **Main app (4 tabs)** — Same Chats / Contacts / Discover / Me layout you already have, now loading real data from the cloud database
- **Profile** — Shows your real name and email from your login account. The Edit Profile screen saves changes to the cloud. Sign Out actually works now
- **Admin Backend** — Admin-only user management dashboard accessible from the Me tab
