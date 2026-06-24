# Wefluens Connect — Mobile (Expo / React Native)

Cross-platform (Android + iOS + web) client for Wefluens Connect, built with Expo
SDK 56 + expo-router + TypeScript. It **reuses the existing Supabase backend** that
the native Swift iOS app uses — same auth, database, RPCs, edge functions, and
storage. Only the UI is re-implemented here.

## 1. Configure credentials

Copy your Supabase project values into `.env.local` (already gitignored):

```
EXPO_PUBLIC_SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=YOUR-ANON-PUBLIC-KEY
```

Find them in Supabase → **Project Settings → API**. (Same variable names the Swift
app used.)

## 2. Run it (debug on a real Android phone in ~1 minute)

```bash
npm install            # if you haven't already
npx expo start         # opens a QR code
```

Install **Expo Go** from the Play Store, scan the QR — the app runs on your phone
with hot reload. `npx expo start --web` runs it in a browser; `--android` opens an
emulator if you have one.

## 3. Build for Google Play (and the App Store)

```bash
npm install -g eas-cli
eas login              # free Expo account
eas build:configure
eas build --platform android       # produces an .aab for Play
eas build --platform ios           # produces an .ipa for the App Store
```

## Project structure

- `src/app/` — screens (expo-router file-based routing). `(auth)` = sign-in,
  `(tabs)` = Chats / Contacts / Discover / Me, plus chat, group, contact, etc.
- `src/lib/` — `supabase.ts` (client), `api.ts` (all backend calls), `theme.ts`
  (design tokens, 1:1 with the Swift app), `i18n.tsx` (EN/中文/ES), `types.ts`,
  `format.ts`.
- `src/context/` — `AuthContext` (session, deep links) and `AppDataContext`
  (inbox + realtime, contacts, discover, blocked users).
- `src/components/ui.tsx` — shared UI (Avatar, buttons, cards, nav bar, fields).

## Trust & Safety (required by both stores for user content)

Report (messages + users), block / unblock with app-wide filtering, a managed
blocked-accounts list, an EULA + Community Guidelines agreement gate at sign-up,
and in-app account deletion are all implemented.
