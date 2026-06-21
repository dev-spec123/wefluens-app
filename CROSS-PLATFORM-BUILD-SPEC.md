# Wefluens Connect — Cross-Platform Build Spec

This is the blueprint for rebuilding the Wefluens Connect app as a cross-platform client (recommended: Expo / React Native + TypeScript) that **reuses the existing Supabase backend unchanged**. The current production app is native Swift/SwiftUI (iOS only); only the client is being re-implemented. Every table, RPC, edge function, and storage bucket below already exists and must be called identically from the new app.

---

## Design System

This design system is sourced from the WeConnect SwiftUI app (`Theme.swift`, `Components.swift`). All colors, gradients, type, radii, and components below are documented as platform-agnostic tokens so they can be reproduced exactly in Expo / React Native. SwiftUI gradients default to `topLeading → bottomTrailing`, which maps to a CSS/React Native linear gradient of `start={{x:0,y:0}} end={{x:1,y:1}}` (a 135° diagonal). Hex values are given exactly as defined in source.

### Color Tokens

Colors are split into **semantic surface/text tokens** (which have distinct light and dark variants) and **brand tokens** (which are identical across modes).

#### Surfaces (light / dark variants)

| Token | Light hex | Dark hex | Usage |
|---|---|---|---|
| `paper` | `#F7F3EE` | `#0F0C0E` | App background / base canvas |
| `card` | `#FFFFFF` (pure white) | `#1C181B` | Elevated card surface |
| `cardSubtle` | `#FBF8F4` | `#252023` | Secondary/inset fill (e.g. unfilled chip background) |

#### Text / Ink (light / dark variants)

| Token | Light hex | Dark hex | Usage |
|---|---|---|---|
| `ink` | `#1C141A` | `#F0EBED` | Primary text |
| `inkSecondary` | `#8B8189` | `#9D95A0` | Secondary text, subtitles |
| `inkTertiary` | `#B6ADB3` | `#605A63` | Tertiary / disabled / hints |

#### Hairline / Border (light / dark variants)

| Token | Light | Dark | Usage |
|---|---|---|---|
| `hairline` | `rgba(0,0,0,0.06)` — black @ 6% opacity | `rgba(255,255,255,0.08)` — white @ 8% opacity | 1px borders/strokes on cards & chips |

#### Brand colors (same in light and dark)

| Token | Hex | Notes |
|---|---|---|
| `plum` | `#3A1B4A` | Deep editorial brand color (used in `dusk` gradient) |
| `coral` | `#FF4D6D` | Primary accent |
| `tangerine` | `#FF9A5A` | Warm secondary accent |
| `coralDark` | `#FF6B82` | Lightened coral used in dark-mode sunset variant |
| `danger` | `#E5484D` | Destructive actions (delete / remove) |

#### Fixed utility colors

| Purpose | Value |
|---|---|
| Online presence dot fill | `#2AD17E` (green) |
| Avatar circle ring stroke | `rgba(255,255,255,0.40)` — white @ 40% |
| Online dot ring stroke | `paper` color (mode-dependent), 2.5px |
| Card drop shadow color | `rgba(0,0,0,0.05)` light / `rgba(0,0,0,0.20)` dark |

> Implementation note: hex values in source are written as `0xRRGGBB` integers and expanded to sRGB. There are no alpha-baked hex values except via explicit `.opacity()` modifiers (documented above as `rgba`).

### Gradient Tokens

All gradients are linear. Unless stated otherwise, direction is **topLeading → bottomTrailing** (`start {x:0,y:0} → end {x:1,y:1}`, ≈135°). Two-stop gradients are evenly distributed (0% and 100%).

| Token | Stops (in order) | Direction | Usage |
|---|---|---|---|
| `sunset` | `#FF4D6D` (coral) → `#FF9A5A` (tangerine) | topLeading → bottomTrailing | **Primary brand gradient.** Filled chips, primary CTAs |
| `sunsetDark` | `#FF6B82` (coralDark) → `#FF9A5A` (tangerine) | topLeading → bottomTrailing | Dark-mode variant of `sunset` |
| `dusk` | `#3A1B4A` (plum) → `#FF4D6D` (coral) | topLeading → bottomTrailing | Deep editorial gradient for hero surfaces |
| `warmGlow` | `rgba(255,154,90,0.9)` (tangerine @ 90%) → `rgba(255,77,109,0.9)` (coral @ 90%) | **leading → trailing** (`{x:0,y:0.5} → {x:1,y:0.5}`, horizontal, 90°) | Warm horizontal glow accent |

#### Avatar gradients (dynamic)

Avatars build a 2+ stop linear gradient on the fly from an array of hex color stops (`colors: [UInt]`), direction topLeading → bottomTrailing. There is no fixed palette — the caller supplies the stops. (In SwiftUI these are memoized in a `gradientCache` keyed by the color array; in RN simply pass the stops array to `expo-linear-gradient`.)

### Typography

The app uses the **system font**. Several prominent text styles use SwiftUI's **rounded** design (`design: .rounded`) — on iOS this is **SF Pro Rounded**. To reproduce on Expo/React Native, bundle a rounded font (e.g. `SF Pro Rounded` on iOS, or a rounded substitute such as `Nunito`/`Quicksand`/`Baloo 2` cross-platform) and apply it to the tokens marked "rounded" below. All other text uses the default system font.

| Style | Size (pt/px) | Weight | Design | Where |
|---|---|---|---|---|
| Screen title | 32 | Bold (700) | **Rounded** | `ScreenHeader` title |
| Screen subtitle | 14 | Medium (500) | Default | `ScreenHeader` subtitle |
| Avatar initials | `size * 0.36` (≈18.7 at default 52) | Bold (700) | **Rounded** | `Avatar` initials placeholder |
| Avatar symbol glyph | `size * 0.40` (≈20.8 at default 52) | Semibold (600) | Default (SF Symbol) | `Avatar` SF Symbol placeholder |
| Tag chip label | 12 | Semibold (600) | Default | `TagChip` |

Weight mapping (SwiftUI → numeric / RN `fontWeight`): `.medium` → 500, `.semibold` → 600, `.bold` → 700.

### Corner Radii

| Token | Value | Usage |
|---|---|---|
| Card radius (default) | **22** | `cardStyle()` default corner radius (parameterizable) |
| Chip / pill | **fully rounded** (Capsule — radius = height/2) | `TagChip` background and stroke |
| Avatar | **circle** (radius = size/2) | `Avatar` clip shape + online dot |

### Spacing & Layout Conventions

| Context | Values |
|---|---|
| `TagChip` padding | horizontal **12**, vertical **6** |
| `ScreenHeader` internal spacing | **2** pt between title and subtitle; leading-aligned, full width |
| Border / stroke width | **1** pt for card, chip, and avatar ring strokes; **2.5** pt for the online-dot ring |
| Card shadow | radius **18**, offset **x:0, y:10**, color black @ 5% (light) / 20% (dark) |

There is no global spacing scale exported; spacing is applied per-component with the literal values above. Reuse 6 / 12 as the chip rhythm and 2 for tight header stacking.

### Reusable Components

#### `cardStyle()` modifier (`Theme.swift`)

Soft elevated card treatment applied to any container.

**Props**
| Prop | Type | Default |
|---|---|---|
| `cornerRadius` | number (CGFloat) | `22` |

**Visual spec**
- Background: `card` color for current scheme (`#FFFFFF` light / `#1C181B` dark).
- Clipped to a rounded rectangle of `cornerRadius`.
- Overlay border: `RoundedRectangle` stroke using `hairline` (black @ 6% light / white @ 8% dark), **1 pt**.
- Drop shadow: color black @ **5%** (light) / **20%** (dark), radius **18**, x **0**, y **10**.

RN equivalent: `borderRadius: cornerRadius`, `borderWidth: 1`, `borderColor: hairline`, `backgroundColor: card`, plus an iOS `shadow*` / Android `elevation` approximating radius 18 / y-offset 10.

#### `Avatar` (`Components.swift`)

Circular avatar showing (in priority order) a remote image, else a gradient placeholder with an SF Symbol or initials. Optional online-presence dot.

**Props**
| Prop | Type | Default | Notes |
|---|---|---|---|
| `colors` | `[UInt]` (array of hex stops) | — (required) | Gradient stops for the placeholder fill |
| `symbol` | `String?` (SF Symbol name) | `nil` | Drawn at `size * 0.40`, semibold, white |
| `initials` | `String?` | `nil` | Drawn at `size * 0.36`, bold, **rounded**, white. Used only if `symbol` is nil |
| `imageURL` | `String?` | `nil` | If non-empty & valid URL, shows the remote photo; otherwise falls back to placeholder |
| `size` | number (CGFloat) | `52` | Width & height |
| `isOnline` | `Bool` | `false` | Shows green presence dot |

**Init variants / usage patterns** (all driven by which optionals are supplied):
1. **Image avatar** — `imageURL` valid → remote photo, `aspectRatio fill`, clipped to circle. Falls back to placeholder on load failure/empty/invalid URL.
2. **Symbol avatar** — no image, `symbol` provided → gradient + white SF Symbol glyph.
3. **Initials avatar** — no image, no symbol, `initials` provided → gradient + white bold rounded initials.
4. **Bare gradient** — none of the above → gradient fill only.

**Visual spec**
- Frame: `size × size` (default 52×52), clipped to a `Circle`.
- Placeholder fill: linear gradient from `colors` (topLeading → bottomTrailing).
- Ring overlay: `Circle` stroke white @ **40%**, **1 pt**.
- Online dot (when `isOnline`): bottom-trailing aligned circle, fill `#2AD17E`, diameter `size * 0.26` (≈13.5 at default), with a ring stroke of `paper` color (mode-dependent), **2.5 pt**.

#### `TagChip` (`Components.swift`)

Pill-shaped tag/label.

**Props**
| Prop | Type | Default |
|---|---|---|
| `text` | `String` | — (required) |
| `filled` | `Bool` | `false` |

**Visual spec**
- Text: size **12**, semibold (600).
- Padding: horizontal **12**, vertical **6**.
- Shape: `Capsule` (fully rounded pill).
- **Unfilled** (`filled: false`): background `cardSubtle` (`#FBF8F4` / `#252023`); text color `inkSecondary` (`#8B8189` / `#9D95A0`); border `hairline`, 1 pt.
- **Filled** (`filled: true`): background `sunset` gradient (`#FF4D6D → #FF9A5A`); text color white; border transparent (`Color.clear`).

#### `ScreenHeader` (`Components.swift`)

Large screen/tab title with optional subtitle.

**Props**
| Prop | Type | Default |
|---|---|---|
| `title` | `String` | — (required) |
| `subtitle` | `String?` | `nil` |

**Visual spec**
- Layout: leading-aligned `VStack`, **2 pt** spacing, full available width.
- Title: size **32**, bold (700), **rounded** design, color `ink`.
- Subtitle (optional): size **14**, medium (500), color `inkSecondary`.

### Light / Dark Mode Handling

The app persists a user choice (`light` / `dark`) under `UserDefaults` key `wefluens.colorscheme`, defaulting to **light**. Every semantic surface, text, and hairline token resolves through a `for scheme:` function — reproduce in RN with a theme context that switches the variant table above based on `useColorScheme()` plus a persisted override. Brand colors and the `sunset`/`dusk`/`warmGlow` gradients do **not** change between modes (only `sunset` has an explicit dark sibling, `sunsetDark`, that swaps `coral` for `coralDark`).

---

I now have a complete picture. Here is the Markdown section.

## Screens & Navigation

### Root Auth Gating (`ContentView`)

`ContentView` is the app's root view. It observes `AuthManager` (`@Environment(AuthManager.self)`) and lazily owns the `AppDataService` (`@State private var dataService`). It renders exactly one of four states, animated with opacity cross-fades:

1. **Loading** — when `auth.isLoading` is true, shows `launchScreen` (a full-bleed `Theme.dusk` background with a centered white `ProgressView` scaled 1.4×).
2. **Authenticated but data service not yet built** — when `auth.isAuthenticated` and `auth.userId != nil` but `dataService == nil`, shows a coral `ProgressView` on a paper background while a `.task` bootstraps the data layer. Bootstrap order: `AppDataService(userId:)` is constructed, then `syncProfile` (creates the profile row), `checkAccountFlags` (reads admin + forced-password flags — requires the profile to exist), `loadBlocks` (so blocked users are filtered before contacts/conversations load), one-time terms acceptance stamp (if `AuthView.pendingTermsKey` is set in `UserDefaults`), then `loadConversations`, `loadContacts`, `loadDiscover`. On completion, `dataService` is set with an ease-in-out animation.
3. **Must change password** — once the data service exists, if `auth.mustChangePassword` is true, shows `ForcePasswordChangeView()` (mandatory variant). Otherwise →
4. **Main app** — `RootTabView()` with the `AppDataService` injected into the environment.
5. **Unauthenticated** — when not loading and not authenticated, shows `AuthView()`.

Additional root behavior:
- `.onChange(of: auth.isAuthenticated)` clears `dataService` to `nil` on sign-out.
- `.onOpenURL` forwards deep links to `auth.handleDeepLink(url)`.
- `.fullScreenCover(isPresented: $auth.passwordRecoveryActive)` presents `SetNewPasswordView()` over everything (used by the password-reset deep link flow).

### Bottom Tab Structure (`RootTabView`)

A native SwiftUI `TabView` (WeChat-style) bound to `@State selection: AppTab` (defaults to `.chats`). Tab bar appearance is configured at init via `configureTabBarAppearance()` with dynamic (trait-aware) light/dark colors and a coral tint for the selected item. `.task { await data.observeInbox() }` starts realtime inbox observation. The four tabs (enum `AppTab`):

| Tab | Root View | Icon (SF Symbol) | Notes |
|-----|-----------|------------------|-------|
| Chats | `ChatsListView` | `bubble.left.and.bubble.right.fill` | Shows a `.badge(data.totalUnread)` |
| Contacts | `ContactsView` | `person.2.fill` | |
| Discover | `DiscoverView` | `sparkles` | |
| Me | `ProfileView` | `person.crop.circle.fill` | |

---

### AuthView (Auth stack — root unauthenticated screen)

- **Purpose:** Invite-only sign-in plus optional self sign-up. Email + password only (no public account creation beyond invite).
- **Lives in:** Shown by `ContentView` when unauthenticated (not part of the tab bar).
- **Navigated to:** Automatically when not authenticated, or after sign-out.
- **Key UI / actions:**
  - Branded `Theme.dusk` background with a blurred sunset circle that shifts up when the keyboard appears; "Wefluens Connect" logo + tagline.
  - Email field (`envelope.fill`), password `SecureField` (`lock.fill`), with inline per-field validation errors (`emailError`, `passwordError`, `confirmError`).
  - Inline auth error banner (coral) distinguishing rate-limit (429) from generic errors.
  - **Toggle Sign In ⇄ Create Account** button; in sign-up mode adds a confirm-password field and a Terms agreement row.
  - **Agreement row** (sign-up only): checkbox + tappable links to Terms of Use and Community Guidelines (each opens `LegalDocView` in a sheet via `showTerms`/`showGuidelines`). Sign-up disabled until checked.
  - **Submit** runs `validateSignUp` (valid email, ≥8 char password, matching confirm) → `auth.signUp` (sets `pendingTermsKey`), or for sign-in validates email/non-empty password → `auth.signIn`.
  - **Forgot password** (sign-in only): `auth.sendPasswordReset` → "reset sent" alert.
  - **Check-your-email screen** (`checkEmailView`): shown when `auth.signUpNeedsConfirmation`; envelope icon, pending email, "Back to Sign In" button (`auth.cancelSignUpConfirmation`).

### ForcePasswordChangeView (Auth stack / Settings sheet)

- **Purpose:** Force a password change after an invited user first signs in with the initial password (`11111111`). Reused as an optional voluntary change (`forced = false`).
- **Lives in:** Full-screen from `ContentView` when `auth.mustChangePassword` (forced); also presented as a sheet from `PrivacySecurityView` (`forced: false`).
- **Navigated to:** Automatically post-sign-in for invited users; or Me → Privacy & Security → Change Password.
- **Key UI / actions:**
  - `Theme.dusk` background, `lock.rotation` icon, title + subtitle (subtitle differs for forced vs. optional).
  - Two `SecureField`s (new password, confirm).
  - **Cancel** button shown only when `!forced`; **Sign Out** button shown only when `forced`.
  - **Save**: validates ≥8 chars, not equal to initial password, matching confirm → `auth.changePassword`. Forced flow flips `mustChangePassword` (ContentView swaps to tabs); optional flow dismisses the sheet.
  - `.interactiveDismissDisabled(forced)`.

### SetNewPasswordView (Root full-screen cover)

- **Purpose:** Set a new password after opening a `wefluens://reset-password` deep link.
- **Lives in:** Root-level `.fullScreenCover` driven by `auth.passwordRecoveryActive`.
- **Navigated to:** Opening the password-reset deep link.
- **Key UI / actions:**
  - `Theme.dusk` background, `lock.rotation` icon.
  - Two `SecureField`s (new password, confirm).
  - **Save**: validates ≥8 chars + match → `auth.updateRecoveredPassword`; on success shows a checkmark **success view** with a "Back to Sign In" button that sets `auth.passwordRecoveryActive = false`.
  - `.interactiveDismissDisabled(true)`.

---

## Chats Tab

### ChatsListView (Chats tab root)

- **Purpose:** Conversation inbox — list of DM and group threads.
- **Lives in:** Chats tab; hosts a `NavigationStack(path:)`.
- **Navigated to:** Chats tab selection.
- **Key UI / actions:**
  - Custom header: "Chats" title + unread summary ("N unread" / "All caught up"), a **theme toggle** (moon/sun, toggles `theme.mode`), and a **compose menu** (`square.and.pencil`) with "New Group" → opens `CreateGroupView` as a full-screen cover.
  - **Search bar** filtering by name / last message.
  - **Pinned** and **Messages** sections; each row (`ConversationRow`) shows avatar (online dot, official seal, group glyph), name, last-message preview (handles "You:" prefix, `[Photo]`/`[File]`, recalled placeholder), time, unread badge or pin glyph.
  - Rows are `NavigationLink`s: DM → `ChatDetailView` (via `DMChatRoute`), group → `GroupChatDetailView` (via `GroupChatRoute`).
  - **Swipe-to-delete** (`SwipeableRow`): drag reveals a red trash button → confirmation alert → `data.hideConversation`.
  - Pull-to-refresh and `.onAppear` call `data.loadConversations()`. Empty state when filtered list is empty.

### ChatDetailView (Chats stack — pushed)

- **Purpose:** Real 1:1 chat thread (text, image, file, quoted replies, read receipts).
- **Lives in:** Chats stack (also reachable from Contacts via `ContactDetailView`).
- **Navigated to:** Tapping a DM row in `ChatsListView`, or "Message" in `ContactDetailView`.
- **Key UI / actions:**
  - Custom nav bar: back chevron, avatar (online dot), title + "Active now"/"Offline", and an **ellipsis menu**: **Report** (`ReportTarget(user:)` → `ReportSheet`), **Block** (confirmation → `data.blockUser`, then pops), **Clear history** (confirmation → `vm.clearHistory`).
  - **Message list** (`MessageBubble`): coral bubbles for me / paper bubbles for them; image bubbles (`ChatImageBubble`, signed URL, sized to pixel dims), file bubbles (`ChatFileBubble`, opens via QuickLook download), quoted-reply previews (`QuotedReplyPreview`, tap scrolls + highlights original), recalled-message placeholder, and a read receipt ("Read"/"Delivered") under my newest message.
  - **Context menu per bubble:** Reply, Forward (→ `ForwardMessageView` sheet), Copy (text only), Report (incoming only), Recall (mine, within 2-min window), Delete.
  - **Reply composer bar** above the input when replying.
  - **Input bar:** "+" menu (attach Photo via `PhotosPicker`, attach File via `fileImporter`, 25 MB cap), vertical-growing text field, send button (`send_dm`). Tab bar hidden.

### GroupChatDetailView (Chats stack — pushed)

- **Purpose:** Real group chat (text + image + file). Incoming bubbles grouped by sender run.
- **Lives in:** Chats stack.
- **Navigated to:** Tapping a group row in `ChatsListView`, or after creating a group in `CreateGroupView`.
- **Key UI / actions:**
  - Nav bar: back chevron, group avatar, live title + member count, **ellipsis menu** (Clear history), and a **members button** (`person.3.fill`) → opens `GroupSettingsView` sheet.
  - **Message list** (`GroupMessageBubble`): mine right/coral; others left with avatar + name shown once per run; reuses 1:1 image/file bubbles; recalled placeholder.
  - **Context menu per bubble:** Forward (→ `ForwardMessageView`), Report (others' messages), Recall (mine, 2-min window), Delete, **Block** (others — confirmation → `data.blockUser`, reloads).
  - **Input bar:** identical "+" attach menu + send (`send_group_message`).
  - Live header overrides (`liveTitle`/`liveMemberCount`) update after settings changes.

### CreateGroupView (Chats — full-screen cover)

- **Purpose:** Pick ≥2 friends to start a new group chat.
- **Lives in:** Chats stack, presented as a `fullScreenCover` from `ChatsListView`.
- **Navigated to:** Chats header compose menu → "New Group".
- **Key UI / actions:**
  - Nav bar: close (X), title, subtitle ("Select…"/"N selected"), **Create** button (enabled when ≥2 selected).
  - Horizontal **selected-friends chips** bar (tap chip to remove).
  - **Group name** text field (auto-generates from member names when blank), **search field**, multi-select **contact list** (radio checkmark) drawn from `data.contacts`.
  - **Create** → `data.createGroup`; on success calls `onCreated(route)` so the parent dismisses and pushes `GroupChatDetailView`. Empty state when the user has no friends.

### ForwardMessageView (Chats — sheet)

- **Purpose:** Multi-select target picker to forward a message to friends and/or groups.
- **Lives in:** Presented as a `.sheet` (inside a `NavigationStack`) from `ChatDetailView` and `GroupChatDetailView`.
- **Navigated to:** Long-press a bubble → Forward.
- **Key UI / actions:**
  - Nav bar: close (X), title, "N selected", **Send** button.
  - Horizontal **selected chips** bar; **search field**; **Friends** and **Groups** sections (each a multi-select row with checkmark).
  - **Send** → `data.forwardMessage(source:friendIds:groupIds:)` (server-side copy + permission re-check); dismisses on success. Empty state when no targets.

### GroupSettingsView (Chats — sheet)

- **Purpose:** Group info: member roster, owner-only rename/remove, member invite.
- **Lives in:** Presented as a `.sheet` from `GroupChatDetailView`.
- **Navigated to:** Group chat nav bar → members button.
- **Key UI / actions:**
  - Nav bar: close (X) + "Group Settings" title.
  - **Name section:** editable field + inline **Save** for the owner (`data.renameGroup`); read-only for non-owners.
  - **Members section:** header with count + **Add Members** button (opens `GroupAddMembersView` sheet); each `memberRow` shows avatar, name, handle, "Owner" badge, and (owner-only) a red **minus** remove button → confirmation → `data.removeGroupMember`.
  - `onChanged` callback bubbles name/count up to the chat header.

#### GroupAddMembersView (nested sheet within GroupSettingsView)

- **Purpose:** Multi-select friend picker to invite friends into the group (excludes existing members).
- **Lives in:** `.sheet` from `GroupSettingsView`.
- **Navigated to:** Group Settings → Add Members.
- **Key UI / actions:** Nav bar with close, title, "N selected", **Save**; search field; multi-select friend list (checkmark). **Save** adds each via `data.addGroupMember`, surfaces errors, calls `onAdded` then dismisses. Empty state when no friends remain to add.

---

## Contacts Tab

### ContactsView (Contacts tab root)

- **Purpose:** Friends directory grouped alphabetically, with friend-request inbox and quick actions.
- **Lives in:** Contacts tab; hosts a `NavigationStack`.
- **Navigated to:** Contacts tab selection.
- **Key UI / actions:**
  - `ScreenHeader` ("Contacts" + "N connections"), **search bar** (name/handle/role).
  - **Quick actions** row: **Add Friend** (opens `AddFriendView` sheet), "Top Talent", "Brands" (decorative).
  - **New friend requests** section (when present): rows → `FriendRequestDetailView`.
  - **Alphabetical sections** of `ContactRow` (avatar, name, role, followers, platform); each row is a `NavigationLink(value: contact.id)` → `ContactDetailView`.
  - Pull-to-refresh / `.onAppear` → `data.loadContacts()`.
  - **"Request accepted" alert** (driven by `data.friendAcceptedNames`; dismissing marks them seen).

### FriendRequestDetailView (Contacts stack — pushed)

- **Purpose:** Review an incoming friend request and accept/decline it.
- **Lives in:** Contacts stack.
- **Navigated to:** Tapping a request row in `ContactsView`.
- **Key UI / actions:** Large avatar, name, handle, role chip, request message; **Decline** / **Accept** buttons → `data.respondToFriendRequest`, then refreshes contacts, shows an inline result label ("Added"/"Declined"), and auto-dismisses. Back chevron overlay.

### ContactDetailView (Contacts stack — pushed)

- **Purpose:** A friend's profile with stats, message/call actions, and safety controls.
- **Lives in:** Contacts stack (and pushes `ChatDetailView`).
- **Navigated to:** Tapping a contact in `ContactsView`.
- **Key UI / actions:**
  - Hero card (avatar, name, handle, role chip); **stats** row (followers, platform, online/away).
  - **Actions:** **Message** → `data.getOrCreateThread` then `navigationDestination(item:)` pushes `ChatDetailView`; a decorative **phone** button.
  - **Info card** (handle, role, audience).
  - **Remove Friend** button → confirmation → `data.removeFriend`, then pops.
  - Top-left back chevron; **top-right ellipsis menu**: **Report** (→ `ReportSheet`), **Block** (confirmation → `data.blockUser`, then pops).

### AddFriendView (Contacts — sheet)

- **Purpose:** Search platform users by email/@handle and send friend requests.
- **Lives in:** Presented as a `.sheet` (own `NavigationStack`) from `ContactsView`.
- **Navigated to:** Contacts → Add Friend quick action.
- **Key UI / actions:**
  - Search field with debounced search (`data.searchUsers`, min 2 chars), clear button, Done toolbar button.
  - States: hint (empty), searching spinner, no-results, results list.
  - **Result rows:** avatar, name, subtitle; per-row **action button** reflecting relationship — Add (`data.sendFriendRequest`), Requested (pending), Friends (done), or Accept (`data.respondToFriendRequest` for incoming).
  - Bottom **toast** for action feedback; haptics.

---

## Discover Tab

### DiscoverView (Discover tab root)

- **Purpose:** Brand/campaign marketplace browse surface.
- **Lives in:** Discover tab; hosts a `NavigationStack`.
- **Navigated to:** Discover tab selection.
- **Key UI / actions:**
  - `ScreenHeader` ("Discover" + subtitle).
  - **Featured** hero card (decorative "View Brief" button).
  - **Filter bar** (All/Beauty/Fashion/Wellness/Tech `TagChip`s; selection is local state, not yet applied to the list).
  - **Top Brands** horizontal carousel of `BrandCard`s.
  - **Open Campaigns** vertical list of `CampaignCard`s; each is a `NavigationLink(value: campaign.id)` → `CampaignDetailView`.

### CampaignDetailView (Discover stack — pushed)

- **Purpose:** Full campaign brief with apply CTA.
- **Lives in:** Discover stack.
- **Navigated to:** Tapping a campaign card in `DiscoverView`.
- **Key UI / actions:** Gradient hero (brand + title), **quick stats** (budget, deadline, spots), **About** card (description + tag chips), **Deliverables** card (static checklist). Top-left back chevron; bottom pinned **apply bar** (budget + estimated payout + decorative **Apply** button). Tab bar hidden.

---

## Me Tab

### ProfileView ("Me" tab root)

- **Purpose:** The signed-in user's profile hub + settings entry points.
- **Lives in:** Me tab; hosts a `NavigationStack`.
- **Navigated to:** Me tab selection.
- **Key UI / actions:**
  - **Profile card** (dusk banner, avatar, name, role/email, admin badge if `auth.isAdmin`, bio, location) with an **Edit Profile** `NavigationLink` → `EditProfileView`.
  - **Stats** row (reach, engagement, deals).
  - **Availability card** with an "Open to deals" toggle (local state).
  - **QR banner** → `NavigationLink` to `QRCodeView`.
  - **Preferences group:** Notifications toggle (local), Language → `SettingsView`, Privacy → `PrivacySecurityView`.
  - **Admin group** (only when `auth.isAdmin`): → `AdminUsersView`.
  - **Support group:** Help / Contact / Rate (decorative).
  - **Sign Out** button → `auth.signOut`.
  - `.task`/refreshable → `data.refreshProfile()`.

### EditProfileView (Me stack — pushed)

- **Purpose:** Edit name, bio, location, and avatar.
- **Lives in:** Me stack.
- **Navigated to:** Profile card → Edit Profile.
- **Key UI / actions:**
  - **Avatar section** with a `PhotosPicker` camera button ("Change Photo").
  - **Form:** Name, Handle (read-only/disabled), Bio (multi-line), Location field with a **locate** button (`LocationService`, showing idle/locating/resolved/denied/error states).
  - **Save** button (enabled only on changes): uploads avatar (`data.uploadAvatar`) then `data.updateProfile`, re-fetches, shows a success toast, then dismisses. Cancel toolbar button; "Save Failed" alert on error.

### SettingsView (Me stack — pushed)

- **Purpose:** App language selection.
- **Lives in:** Me stack.
- **Navigated to:** Profile → Preferences → Language.
- **Key UI / actions:** Language section listing `AppLanguage.allCases` (flag + native name); tapping sets `l10n.language` with a checkmark on the current one; footer note; Done toolbar button.

### PrivacySecurityView (Me stack — pushed)

- **Purpose:** Privacy, security, and safety/legal controls.
- **Lives in:** Me stack.
- **Navigated to:** Profile → Preferences → Privacy.
- **Key UI / actions:**
  - **Privacy group:** **Change Password** action row → presents `ForcePasswordChangeView(forced: false)` as a sheet; **Blocked Accounts** → `BlockedAccountsView`; **Visibility** (placeholder `NavigationLink` to `EmptyView`); **Activity status** toggle; **Data sharing** toggle (both local state).
  - **Legal & Safety group:** **Terms of Use** → `LegalDocView(kind: .terms)`; **Community Guidelines** → `LegalDocView(kind: .guidelines)`.

### AdminUsersView (Me stack — pushed, admin only)

- **Purpose:** Backend user management — list/invite/ban/unban/delete users.
- **Lives in:** Me stack; only shown when `auth.isAdmin`.
- **Navigated to:** Profile → Admin → "User Management".
- **Key UI / actions:**
  - Toolbar: **Invite** (`person.badge.plus`) → `InviteUserSheet`; **Refresh** (`arrow.clockwise`).
  - Loads users directly from the `profiles` table; states: loading spinner, empty, list.
  - **List:** an "Invite teammate" CTA row + an "All Users" section of `UserRow`s (avatar, name, Banned/Admin badges, email, per-row **ellipsis menu**: Ban/Unban + Delete).
  - **Confirmation dialogs** for Ban (`admin_ban_user`), Unban, and Delete (`admin_delete_user`); error alert.
  - **InviteUserSheet** (nested sheet): email field, **Send invite** → `invite-user` edge function, success/error toast with code-mapped messages, Done button.

### QRCodeView (Me stack — pushed)

- **Purpose:** Show the user's QR code (`wefluens://user/<uuid>`) for adding friends.
- **Lives in:** Me stack.
- **Navigated to:** Profile → QR banner.
- **Key UI / actions:** Profile header (avatar, name, handle), generated **QR code card** (CoreImage, with truncated UID), instructions, and a **Scan QR Code** `NavigationLink` → `QRScanView`.

### QRScanView (Me stack — pushed)

- **Purpose:** Scan another user's QR code and send them a friend request.
- **Lives in:** Me stack.
- **Navigated to:** QRCodeView → Scan QR Code.
- **Key UI / actions:** Full-screen camera preview (`AVCaptureSession` via `CameraPreview`), scan-frame overlay with corner accents, close (X) button. On a valid `wefluens://user/<uuid>` scan (not self), shows a **result overlay**: confirm → **Send Friend Request** (inserts into `friend_requests`), with sending/sent/failed states (Done / Try Again / Cancel). Shows a placeholder label when no camera is available.

---

## Trust & Safety (cross-cutting views)

### ReportSheet (sheet — invoked across the app)

- **Purpose:** File a report against a user or a specific message (optionally also block).
- **Lives in:** Presented as `.sheet(item: $reportTarget)` from `ContactDetailView`, `ChatDetailView` (header + bubble), and `GroupChatDetailView` (bubble).
- **Navigated to:** Report actions in chat menus, bubble context menus, and contact detail.
- **Key UI / actions:** Reason picker (`ReportReason`: spam, harassment, hate, sexual, violence, other) as single-select rows; optional **"Also block"** toggle (shown when a `blockableUserId` exists); **Submit** → `data.report` (+ `data.blockUser` if toggled) → success state ("Thanks for reporting") with Done. Cancel/Done toolbar; error alert.

### BlockedAccountsView (Me stack — pushed)

- **Purpose:** List blocked accounts and unblock them.
- **Lives in:** Me stack, under Privacy & Security.
- **Navigated to:** Privacy & Security → Blocked Accounts.
- **Key UI / actions:** Loads via `data.loadBlockedContacts()`; states: loading, empty ("nobody blocked"), list. Each row (avatar, name, handle) has an **Unblock** button → `data.unblockUser`, removing the row. Error alert.

### LegalDocView (sheet or pushed)

- **Purpose:** Render the Terms of Use (EULA) or Community Guidelines.
- **Lives in:** Presented as a `.sheet` from `AuthView` (sign-up agreement links) and pushed as a `NavigationLink` from `PrivacySecurityView`.
- **Navigated to:** Sign-up Terms/Guidelines links, or Privacy & Security → Legal & Safety.
- **Key UI / actions:** Title + "Last updated" date, then static titled sections (`termsSections` or `guidelinesSections`) covering acceptance, eligibility, zero-tolerance/objectionable-content policy, reporting & moderation, enforcement, and support contact. Done toolbar button.

---

## Data Layer & Supabase API

This section is the complete backend contract the cross-platform client must reuse via `supabase-js`. The iOS app authenticates with native Supabase Auth (email/password); the SDK manages the session. The Postgres schema, RPC functions, edge functions, and storage buckets below are the source of truth — call them identically. All `id` columns and `*_id`/`user_id` columns are `uuid`. Timestamps are `timestamptz` (ISO 8601 strings over the wire).

### Client Initialization

```js
const supabase = createClient(EXPO_PUBLIC_SUPABASE_URL, EXPO_PUBLIC_SUPABASE_ANON_KEY)
```

RLS is enforced everywhere; the contract below describes what an authenticated user may read/write. The client only ever READS server-controlled flags (`is_full_access`, `is_admin`, `approval_status`, `is_banned`).

---

### Tables (`public` schema)

#### `profiles`
The user/account record (PK `id` = the auth user id).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, = auth.users.id |
| `email` | string \| null | matched by search server-side, never returned by search |
| `name` | string \| null | |
| `avatar_url` | string \| null | public URL into `avatars` bucket |
| `handle` | string \| null | |
| `role` | string \| null | |
| `bio` | string \| null | |
| `location` | string \| null | |
| `followers` | string \| null | |
| `engagement` | string \| null | |
| `deals` | string \| null | |
| `is_admin` | boolean \| null | read-only on client |
| `is_banned` | boolean \| null | read-only |
| `is_full_access` | boolean | server-controlled; `true` unlocks features beyond free 1:1 chat + add-friends. Client READS only. |
| `approval_status` | string | default value server-set; read-only |
| `must_change_password` | boolean \| null | read-only |
| `terms_accepted_at` | string \| null | stamped via `acceptTerms` (ISO8601) |
| `created_at` | string \| null | |
| `updated_at` | string \| null | |

Client operations:
- `select().eq("id", uid)` — fetch own/other profile.
- `upsert({ id, email?, name?, avatar_url?, handle?, role?, bio?, location?, followers?, engagement?, deals?, is_admin? })` — sync/create + edit own profile. Only the column subset above is written by the client (snake_case keys).
- `update({ terms_accepted_at }).eq("id", uid)` — terms acceptance.
- `select().in("id", [ids])` — batch resolve friend / blocked / accepter names.
- World-readable for purposes of group-message sender embedding (co-members who aren't friends still resolve).

#### `blocks`
Composite PK `(blocker_id, blocked_id)`.

| Column | Type |
|---|---|
| `blocker_id` | uuid → profiles.id |
| `blocked_id` | uuid → profiles.id |
| `created_at` | string |

- `select("blocked_id").eq("blocker_id", uid)` — my block list.
- `upsert({ blocker_id, blocked_id })` — block (idempotent on composite key).
- `delete().eq("blocker_id", uid).eq("blocked_id", other)` — unblock.
- `select().in("id", blockedIds)` on `profiles` to render the Blocked Accounts screen.

#### `reports`
Content/user moderation reports.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `reporter_id` | uuid → profiles.id | required |
| `reported_user_id` | uuid \| null → profiles.id | |
| `message_id` | uuid \| null | |
| `message_kind` | string \| null | `"dm"` / `"group"` |
| `content_excerpt` | string \| null | client caps to 280 chars |
| `reason` | string \| null | |
| `status` | string | server default |
| `created_at` | string | |

- `insert({ reporter_id, reported_user_id?, message_id?, message_kind?, content_excerpt?, reason })`.

#### `friend_requests`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `from_user_id` | uuid → profiles.id | |
| `to_user_id` | uuid → profiles.id | |
| `name` | string | snapshot of sender display name |
| `handle` | string \| null | |
| `role` | string \| null | |
| `avatar_colors` | string \| null | JSON array string e.g. `"[16722029,16751706]"` |
| `request_message` | string \| null | |
| `status` | string \| null | `"pending"` / `"accepted"` / (rejected) |
| `seen_by_sender` | boolean \| null | drives "X accepted your request" prompt |
| `created_at` | string \| null | |

- `select().eq("to_user_id", uid).eq("status","pending").order("created_at",{ascending:false})` — incoming "New Friends".
- `select().eq("from_user_id", uid).eq("status","accepted").eq("seen_by_sender", false)` — unseen acceptances (then resolve `to_user_id` names from `profiles`).
- `update({ seen_by_sender: true }).eq("from_user_id", uid).eq("status","accepted").eq("seen_by_sender", false)` — mark acceptances seen.
- Creation/response go through the `send_friend_request` / `respond_friend_request` RPCs, not direct inserts.

#### `friendships`
The bidirectional friend graph (each accepted request produces two rows). Source of truth for the contact list + count.

| Column | Type |
|---|---|
| `id` | uuid PK |
| `user_id` | uuid → profiles.id |
| `friend_id` | uuid → profiles.id |
| `created_at` | string \| null |

- `select("friend_id").eq("user_id", uid)` — my friend ids → then `profiles.select().in("id", friendIds)`.
- Deletion goes through `remove_friend` RPC (the DELETE RLS policy alone only removes my own side).

#### `dm_threads`
One row per 1:1 pair. Participants stored canonically as `user_high`/`user_low`.

| Column | Type |
|---|---|
| `id` | uuid PK |
| `user_high` | uuid → profiles.id |
| `user_low` | uuid → profiles.id |
| `last_message` | string \| null |
| `last_message_at` | string \| null |
| `last_message_type` | string |
| `last_sender_id` | uuid \| null → profiles.id |
| `created_at` | string \| null |

Threads are created/fetched via `get_or_create_thread`; the inbox is read via `list_dm_threads`. Direct selects are not the normal path.

#### `dm_messages`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `thread_id` | uuid → dm_threads.id | |
| `sender_id` | uuid → profiles.id | |
| `recipient_id` | uuid → profiles.id | |
| `body` | string | text body / caption |
| `message_type` | string | `"text"` / `"image"` / `"video"` / `"file"` (default `"text"`) |
| `image_url` | string \| null | storage PATH in `chat-media` (not a URL) |
| `image_width` | number \| null | |
| `image_height` | number \| null | |
| `file_name` | string \| null | |
| `file_size` | number \| null | |
| `file_mime` | string \| null | |
| `thumb_url` | string \| null | video thumbnail path |
| `duration_ms` | number \| null | video duration |
| `read_at` | string \| null | read receipt (recipient side) |
| `reply_to_message_id` | uuid \| null → dm_messages.id | quoted message |
| `recalled_at` | string \| null | non-null = recalled |
| `recalled_by` | uuid \| null → profiles.id | |
| `created_at` | string \| null | |

- Read: `select().eq("thread_id", id).order("created_at",{ascending:true})` (RLS limits to the two participants). Sending is via RPCs only (`send_dm` / `send_dm_media` / `send_dm_attachment`).

#### `group_threads`
| Column | Type |
|---|---|
| `id` | uuid PK |
| `name` | string (default empty) |
| `avatar_url` | string \| null |
| `created_by` | uuid → profiles.id |
| `last_message` | string \| null |
| `last_message_at` | string \| null |
| `last_message_type` | string |
| `last_sender_id` | uuid \| null → profiles.id |
| `created_at` | string |

Created via `create_group`; inbox via `list_group_threads`.

#### `group_members`
Composite PK `(group_id, user_id)`.

| Column | Type | Notes |
|---|---|---|
| `group_id` | uuid → group_threads.id | |
| `user_id` | uuid → profiles.id | |
| `role` | string | `"admin"` / member (default member) |
| `joined_at` | string | |
| `last_read_at` | string | drives unread count; advanced by `mark_group_read` |

Membership is managed through RPCs (`create_group`, `group_add_member`, `group_remove_member`); roster read via `list_group_members`.

#### `group_messages`
Same media columns as `dm_messages`, minus `recipient_id`/`read_at` semantics being per-pair.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `group_id` | uuid → group_threads.id | |
| `sender_id` | uuid → profiles.id | |
| `body` | string (default empty) | |
| `message_type` | string | `"text"`/`"image"`/`"video"`/`"file"` |
| `image_url` | string \| null | `chat-media` path |
| `image_width` / `image_height` | number \| null | |
| `file_name` / `file_size` / `file_mime` | string/number/string \| null | |
| `thumb_url` | string \| null | |
| `duration_ms` | number \| null | |
| `read_at` | string \| null | |
| `reply_to_message_id` | uuid \| null → group_messages.id | |
| `recalled_at` | string \| null | |
| `recalled_by` | uuid \| null → profiles.id | |
| `created_at` | string | |

- Read with embedded sender profile:
  `select("id,group_id,sender_id,body,message_type,image_url,image_width,image_height,file_name,file_size,file_mime,created_at,reply_to_message_id,recalled_at,recalled_by,sender:profiles!group_messages_sender_id_fkey(id,name,handle,avatar_url)").eq("group_id", id).order("created_at",{ascending:true})`.
  The embed uses FK alias `group_messages_sender_id_fkey`. Sending is via RPCs only.

#### `message_deletions`
Per-user soft-delete ("delete for me").

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid → profiles.id | |
| `message_id` | uuid | dm or group message id |
| `kind` | string | `"dm"` / `"group"` |
| `created_at` | string \| null | |

- Read: `select("message_id,kind").eq("user_id", uid).eq("kind", "dm"|"group")` — filter out hidden messages client-side. Writes go through `delete_message_for_me`.

#### `dm_clears`
Per-user clear-history watermark for a DM thread.

| Column | Type |
|---|---|
| `id` | uuid PK |
| `user_id` | uuid → profiles.id |
| `thread_id` | uuid → dm_threads.id |
| `cleared_before` | string (timestamptz) |
| `created_at` | string \| null |

- Read: `select("thread_id,cleared_before").eq("user_id", uid).eq("thread_id", id)`; messages with `created_at <= cleared_before` are hidden. Written by `clear_dm_history`.

#### `group_clears`
Same as `dm_clears` but keyed by `group_id`. Read: `select("group_id,cleared_before").eq("user_id", uid).eq("group_id", id)`. Written by `clear_group_history`.

#### `conversation_hides`
Per-user hidden-conversation marker (swipe-to-delete; reappears on a newer message).

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid → profiles.id | |
| `conversation_id` | uuid | thread or group id |
| `conversation_type` | string | `"dm"` / `"group"` |
| `hidden_at` | string | |

Written by `hide_conversation`; consumed server-side by the `list_*_threads` RPCs.

#### `brands` (Discover)
| Column | Type |
|---|---|
| `id` | uuid PK |
| `name` | string |
| `category` | string \| null |
| `tagline` | string \| null |
| `symbol` | string \| null (SF-symbol-style name) |
| `colors` | string \| null (JSON array string of ints) |
| `active_campaigns` | number \| null |
| `created_at` | string \| null |

- `select()` — public read, full table.

#### `campaigns` (Discover)
| Column | Type |
|---|---|
| `id` | uuid PK |
| `brand_id` | uuid \| null → brands.id |
| `title` | string |
| `brand` | string (denormalized brand name) |
| `budget` | string \| null |
| `tags` | string[] \| null |
| `deadline` | string \| null |
| `symbol` | string \| null |
| `colors` | string \| null (JSON array string) |
| `spots_left` | number \| null |
| `created_at` | string \| null |

- `select()` — public read, full table.

#### `invites`
Invite-based onboarding (consumed by edge functions, not directly by the chat client).

| Column | Type |
|---|---|
| `id` | uuid PK |
| `email` | string |
| `token` | string |
| `status` | string (default) |
| `invited_by` | uuid \| null |
| `expires_at` | string |
| `activated_at` | string \| null |
| `created_at` | string \| null |

#### Legacy / unused-by-new-client tables
Present in schema but superseded by the thread/group model — do NOT build new features on these:
- `conversations` — legacy inbox rows (`user_id`, `name`, `avatar`, `avatar_colors`, `last_message`, `time`, `unread`, `is_pinned`, `is_official`, `is_online`, `is_group`, `participant_count`, `created_at`, `updated_at`). The real inbox comes from `list_dm_threads` + `list_group_threads`.
- `messages` — legacy flat messages (`conversation_id`, `sender_id`, `text`, `time`, `created_at`). Superseded by `dm_messages`/`group_messages`.
- `contacts` — legacy denormalized contacts (`user_id`, `name`, `handle`, `role`, `platform`, `followers`, `avatar_colors`, `is_online`, `created_at`). Real contacts derive from `friendships` + `profiles`.
- `app_secrets` — server-only key/value (`key`, `value`, `updated_at`); not client-accessible.

---

### RPC Functions (`supabase.rpc(name, params)`)

All params are named exactly as below (snake_case / `p_`-prefixed). `?`-suffixed params are optional (server defaults to NULL / documented default).

#### Messaging — DM
- **`get_or_create_thread`** — params `{ p_other: uuid }` → returns `uuid` (thread id, as a string). Server rejects non-friends (friends-only chat).
- **`send_dm`** — params `{ p_other: uuid, p_body: string, p_reply_to?: uuid }` → returns `uuid` (thread id). Friend-validated, pure DB.
- **`send_dm_media`** — params `{ p_other: uuid, p_image_url: string (storage path), p_caption?: string, p_width?: number, p_height?: number, p_reply_to?: uuid }` → returns `uuid` (thread id). Image messages.
- **`send_dm_attachment`** — params `{ p_other: uuid, p_type: string ("file"|"video"|"image"), p_path: string, p_caption?: string, p_file_name?: string, p_file_size?: number, p_file_mime?: string, p_width?: number, p_height?: number, p_duration_ms?: number, p_thumb_path?: string, p_reply_to?: uuid }` → returns `uuid` (thread id). Generic friend-validated attachment.
- **`mark_thread_read`** — params `{ p_thread: uuid }` → returns `void`. Marks messages addressed to me in this thread read.

#### Messaging — Group
- **`create_group`** — params `{ p_name: string, p_member_ids: uuid[] }` → returns `uuid` (group id). Atomic: adds caller as admin, validates each member via `are_friends`, rolls back fully on failure.
- **`send_group_message`** — params `{ p_group: uuid, p_body: string, p_reply_to?: uuid }` → returns `uuid` (group id). Member-validated, text only.
- **`send_group_attachment`** — params `{ p_group: uuid, p_type: string ("image"|"video"|"file"), p_path: string, p_caption?: string, p_file_name?: string, p_file_size?: number, p_file_mime?: string, p_width?: number, p_height?: number, p_duration_ms?: number, p_thumb_path?: string, p_reply_to?: uuid }` → returns `uuid` (group id). Member-validated image/file/video.
- **`mark_group_read`** — params `{ p_group: uuid }` → returns `void`. Advances my `last_read_at` (clears unread).

#### Inbox listing (no args)
- **`list_dm_threads`** — args: none → returns array of rows:
  `{ thread_id: uuid, other_id: uuid, other_name: string, other_handle: string, other_role: string, other_avatar_url: string, last_message: string, last_message_at: timestamptz, last_sender_id: uuid, last_message_type: string, last_message_recalled: boolean, unread_count: number }`. Respects hides/clears server-side.
- **`list_group_threads`** — args: none → returns array of rows:
  `{ group_id: uuid, name: string, avatar_url: string, created_by: uuid, last_message: string, last_message_at: timestamptz, last_sender_id: uuid, last_message_type: string, last_message_recalled: boolean, member_count: number, unread_count: number }`.

#### Group management
- **`list_group_members`** — params `{ p_group: uuid }` → returns array of rows:
  `{ user_id: uuid, name: string, handle: string, avatar_url: string, role: string, is_owner: boolean }`. Member-only; owner sorted first.
- **`group_rename`** — params `{ p_group: uuid, p_name: string }` → returns `void`. Owner-only.
- **`group_add_member`** — params `{ p_group: uuid, p_user: uuid }` → returns `void`. Any member may add, but only their own friend.
- **`group_remove_member`** — params `{ p_group: uuid, p_user: uuid }` → returns `void`. Owner-only; owner can never be removed.

#### Friends
- **`search_users`** — params `{ search_query: string }` (client requires ≥2 chars) → returns array of rows:
  `{ id: uuid, name: string, handle: string, role: string, avatar_url: string, followers: string, relationship: string ("none"|"friends"|"request_sent"|"request_received"), incoming_request_id: uuid }`. Matches email/handle/name server-side; email never returned. Client filters out blocked users.
- **`send_friend_request`** — params `{ target_id: uuid, message?: string }` → returns `string` status: `"sent"` / `"already_sent"` / `"already_friends"` / `"incoming_exists"`.
- **`respond_friend_request`** — params `{ request_id: uuid, accept: boolean }` → returns `string` status. On accept the server creates the bidirectional friendship atomically.
- **`remove_friend`** — params `{ target_id: uuid }` → returns `string`. Deletes both friendship rows (SECURITY DEFINER).

#### Delete / Recall / Clear / Hide
- **`delete_message_for_me`** — params `{ p_message_id: uuid, p_kind: string ("dm"|"group") }` → returns `void`. Per-user soft delete.
- **`recall_message`** — params `{ p_message_id: uuid, p_kind: string ("dm"|"group") }` → returns `void`. Sender-only, within a 2-minute window (client also gates the button on `created_at`).
- **`clear_dm_history`** — params `{ p_thread_id: uuid }` → returns `void`. Per-user clear watermark.
- **`clear_group_history`** — params `{ p_group_id: uuid }` → returns `void`. Per-user clear watermark.
- **`hide_conversation`** — params `{ p_conversation_id: uuid, p_conversation_type: string ("dm"|"group") }` → returns `void`. Clears my history + marks hidden; reappears on a newer message.

#### Helpers / admin (server-side; not normally client-called)
- `are_friends({ a: uuid, b: uuid })` → boolean
- `is_group_member({ p_group: uuid, p_uid: uuid })` → boolean
- `is_admin({ uid: uuid })` → boolean
- `user_id()` → uuid (current auth user)
- `admin_approve_user({ target_id })` → void
- `admin_reject_user({ target_id })` → void
- `admin_ban_user({ ban: boolean, target_id })` → void
- `admin_delete_user({ target_id })` → void

---

### Edge Functions (`supabase.functions.invoke(name, { body })`)

- **`invite-user`** — admin-side invite creation. Payload: `{ email: string }` (plus optional inviter context via auth). Creates an `invites` row + sends the invite email. (Consumed by the admin/onboarding surface, not the chat flow.)
- **`activate-invite`** — redeems an invite token at signup. Payload: `{ token: string }` (with the new account's auth context) → activates the matching `invites` row (`status`, `activated_at`) and unlocks the account.
- **`delete-account`** — self-service account deletion (App Store requirement). Payload: none beyond the caller's auth (acts on the authenticated user) → deletes the user's auth record and cascades their data.
- **`forward-message`** — forwards an existing message to multiple targets. Payload:
  ```json
  {
    "source": { "kind": "dm" | "group", "messageId": "<uuid>" },
    "targets": [
      { "kind": "friend" | "group", "id": "<uuid>" }
    ]
  }
  ```
  Returns `{ "ok": boolean, "forwarded"?: number, "failed"?: number }`. Server does the `storage.copy` of media (never re-uploaded) + dual permission checks (source read + target write), then dispatches through the existing send functions. Client treats `ok === false` as an error.

---

### Storage Buckets

#### `avatars` (public)
- Path convention: `{userId-lowercased}/avatar-{uuid-lowercased}.jpg`.
- Upload: `storage.from("avatars").upload(path, jpegData, { contentType: "image/jpeg", upsert: true })`.
- Read: `storage.from("avatars").getPublicURL(path)` → store the resulting public URL in `profiles.avatar_url`.
- Client pre-processing: downscale to max dimension 512px, JPEG quality ~0.82. RLS: only the owning user (first path segment = their uid, lowercased) may write.

#### `chat-media` (private)
- Path convention:
  - DM: `{threadId-lowercased}/{uuid-lowercased}.jpg` (images) or `{threadId-lowercased}/{uuid-lowercased}.{ext}` (files).
  - Group: `{groupId-lowercased}/{uuid-lowercased}.jpg` or `.{ext}`.
- Upload images: `upload(path, jpegData, { contentType: "image/jpeg", upsert: false })`; client downscales to max 1280px, JPEG quality ~0.8, and records pixel `width`/`height` for layout.
- Upload files: `upload(path, data, { contentType: mimeType, upsert: false })` — no compression (byte-exact); record original `fileName`, `fileSize`, `mimeType`.
- Read: `storage.from("chat-media").createSignedURL(path, 3600)` (1-hour signed URL; client caches by path and re-signs ~2 min before expiry).
- The stored PATH (not a URL) is what's passed to `send_dm_media` / `send_dm_attachment` / `send_group_attachment` as `p_image_url` / `p_path` and persisted in `*.image_url`.
- RLS: DM media is readable/writable only by the two thread participants; group media by any group member (path's first segment = thread/group id gates access).

---

### Realtime

Subscribe to a per-user channel and refresh the inbox on any relevant change:
```js
supabase.channel(`inbox-${uid}`)
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dm_messages' }, reload)
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'group_messages' }, reload)
  .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'dm_messages' }, reload)
  .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'group_messages' }, reload)
  .subscribe()
```
RLS scopes delivered events to threads/groups the user belongs to. INSERTs cover new messages (DM + group, incoming or own); UPDATEs propagate recalls so the inbox preview flips to the recalled placeholder live.

---

### Domain Models (client-side shapes the data maps into)

- **UserProfile**: `{ name, handle, role, bio, location, followers, engagement, deals, isAdmin, avatarUrl }`. Built from a `profiles` row.
- **Conversation** (unified inbox item): `{ id (thread/group id), name, avatar (symbol), avatarColors, lastMessage, time (display), unread, isPinned, isOfficial, isOnline, isGroup, participantCount, otherUserId (DM only), avatarInitials, lastMessageAt, lastFromMe, lastMessageIsImage, lastMessageType, lastMessageRecalled, avatarUrl }`. DMs map from `list_dm_threads`, groups from `list_group_threads`; merged + sorted by `lastMessageAt` desc; blocked-user DMs filtered out.
- **ChatMessage** (1:1): `{ id, text, sender (me|them), time, kind (text|image|video|file), imagePath (chat-media path), imageWidth, imageHeight, fileName, fileSize, fileMime, readAt, replyTo (uuid), isRecalled, senderId, createdAt }`. Maps from a `dm_messages` row; recalled rows render an empty/placeholder bubble.
- **GroupChatMessage**: ChatMessage fields plus per-message sender identity `{ senderId, senderName, senderColors, senderAvatarUrl }`. Maps from a `group_messages` row with embedded `sender` profile; messages from blocked users are filtered out.
- **Contact**: `{ id, name, handle, role, platform, followers, avatarColors, isOnline, avatarUrl }`. Derived from `friendships` → `profiles`.
- **FriendRequest**: `{ id, name, handle, role, avatarColors, requestMessage }`. From `friend_requests` (incoming pending).
- **SearchUserResult**: `{ id, name, handle, role, avatarUrl, followers, relationship, incomingRequestId }`. From `search_users`.
- **GroupMember**: `{ id (user id), name, handle, avatarUrl, role, isOwner }`. From `list_group_members`.
- **Brand**: `{ id, name, category, tagline, symbol, colors, activeCampaigns }`. From `brands`.
- **Campaign**: `{ id, title, brand, budget, tags, deadline, symbol, colors, spotsLeft }`. From `campaigns`.
- **ForwardSource**: `{ kind (dm|group), messageId }` — input to `forward-message`.

Notes on encoding conventions the client must preserve:
- `avatar_colors` / `colors` are stored as JSON-array-of-int **strings** (e.g. `"[16722029,16751706]"`); parse to a color list, default to a fallback gradient on parse failure.
- Message `kind` derives from `message_type`; `"image"`→image, `"video"`→video, `"file"`→file, else text. A non-null `recalled_at` overrides to a recalled placeholder regardless of type.
- Media `image_url` / `p_path` values are storage PATHS, never URLs — always resolve through `createSignedURL` for `chat-media`.
- Recall is sender-only within 2 minutes; the client must gate the recall affordance on `createdAt` even though the server also enforces it.

---

I have everything I need. Here is the documentation.

## Auth & Onboarding

This section documents the complete authentication and onboarding flow the new app must replicate. The current implementation is native SwiftUI on top of **Supabase Auth**, with two Supabase Edge Functions (Deno) backing a legacy admin-invite path. There are two parallel ways an account comes into existence: **public email/password sign-up** (the path the UI primarily exposes) and the **legacy admin-invite system** (edge functions that pre-create accounts). Both converge on the same sign-in screen and the same profile-flag gating.

### Source of truth

| Concern | File |
|---|---|
| Auth state machine, Supabase calls, deep links, profile flags | `AuthManager.swift` |
| Sign-in / sign-up / forgot-password UI + EULA gate | `Views/AuthView.swift` |
| Root gating on auth + flags, deep-link entry, terms-stamp bridge | `ContentView.swift` |
| Forced (and optional) password change screen | `Views/ForcePasswordChangeView.swift` |
| Set-new-password screen for recovery deep links | `Views/SetNewPasswordView.swift` |
| Admin invite creation + email | `backend/functions/invite-user/index.ts` |
| Public invite-activation landing page | `backend/functions/activate-invite/index.ts` |

> Note: the file headers (e.g. "invite-only sign-in … there is no public sign-up") are stale. The `AuthView` UI exposes a full toggle between **Sign in** and **Create account**, and `AuthManager.signUp(...)` calls `supabase.auth.signUp`. The new app should treat **public sign-up as a first-class, supported path** alongside the legacy invite system.

### Auth state model (`AuthManager`)

Observable flags that drive the UI:

- `isLoading` — true until the initial session check (`checkAuth`) completes; root shows a launch screen.
- `isAuthenticated` — a valid Supabase session exists.
- `isSigningIn` — in-flight sign-in/sign-up guard (also prevents double-submit).
- `showError` / `errorMessage` / `lastErrorKind` — inline error surfacing. `lastErrorKind` is `.rateLimit` or `.generic`; classification is by matching `"rate limit"`, `"too many"`, or `"429"` in the lowercased error description (Supabase 429 email/auth rate-limit).
- `signUpNeedsConfirmation` / `pendingConfirmationEmail` — drive the "check your email" screen after a sign-up that returned no session.
- `passwordRecoveryActive` — true while in a recovery session opened from a reset deep link; presents the full-screen "set new password" cover.
- `mustChangePassword` — from the `profiles.must_change_password` flag.
- `isAdmin` — from the `profiles.is_admin` flag.
- `userId` (Supabase `user.id` UUID) and `userEmail` are derived from the session.

**Session lifecycle.** On init, `checkAuth()` reads `supabase.auth.session`, sets `isAuthenticated`, then arms a single long-lived `authStateChanges` listener (`startAuthStateListener`), which is always cancelled before re-arming so listeners never stack. The listener maps Supabase events:
- `.passwordRecovery` → stores session, sets `passwordRecoveryActive = true` (keeps the user out of the app).
- `.signedIn` → stores session, `isAuthenticated = true`.
- `.signedOut` → clears session, `isAuthenticated = false`.

On `signOut()` the listener is cancelled/torn down and `isAdmin` + `mustChangePassword` are reset; the next `signIn` re-arms the listener.

### Public sign-up

`AuthManager.signUp(email:password:)` calls:

```swift
supabase.auth.signUp(email:, password:, redirectTo: signUpRedirectURL)  // wefluens://auth-callback
```

- If email confirmation is **disabled** server-side, Supabase returns a session → the user is signed in immediately and the listener is re-armed.
- If email confirmation is **enabled**, no session is returned → `pendingConfirmationEmail` is set, `signUpNeedsConfirmation = true`, and `AuthView` swaps to the **"check your email"** screen (`envelope.badge.fill`, the pending email, and a "Back to sign in" button that calls `cancelSignUpConfirmation()`).

Client-side sign-up validation (`AuthView.validateSignUp`): valid email (non-empty local part, `@`, dotted domain), password ≥ **8** chars (`minPasswordLength`), and `confirmPassword == password`. The "Create account" button is disabled until email, password, confirm-password are non-empty **and** the terms checkbox is checked (`canSubmit`).

### Sign-in

`AuthManager.signIn(email:password:)` → `supabase.auth.signIn(email:, password:)`. Client validation requires a valid email and a non-empty password. Errors are shown inline (rate-limit gets a dedicated localized message; everything else falls back to the server message) and the form stays usable.

### Password reset (forgot password)

1. On the sign-in form, **Forgot password** calls `AuthManager.sendPasswordReset(email:)` → `supabase.auth.resetPasswordForEmail(email, redirectTo: resetRedirectURL)` (`wefluens://reset-password`). It always resolves without revealing whether the address exists; only transport errors surface. A "reset sent" alert is shown.
2. The user opens the emailed link → deep link handling (below) opens a recovery session and sets `passwordRecoveryActive`.
3. `ContentView` presents `SetNewPasswordView` as a `fullScreenCover` bound to `auth.passwordRecoveryActive`. It validates new password ≥ 8 chars and match, then calls `AuthManager.updateRecoveredPassword(to:)` → `supabase.auth.update(UserAttributes(password:))`, clears `passwordRecoveryActive`, **signs the user out**, and shows a success view so the user logs in fresh with the new password.

### Email-confirmation handling

Sign-up confirmation and the resulting deep link are handled exactly as described above: no session → "check your email" screen; tapping the confirmation link (`wefluens://auth-callback`) is exchanged for a session via the deep-link handler, after which the auth-state listener signs the user in.

### Deep-link scheme

The `wefluens` URL scheme is registered in `Info.plist`. The two hosts:

- **`wefluens://auth-callback`** (`signUpRedirectURL`) — the redirect for **sign-up email confirmation**. When opened, the session is exchanged and the user is signed in.
- **`wefluens://reset-password`** (`resetRedirectURL`) — the redirect for **password-reset** emails. When opened, the app enters a password-recovery session and shows `SetNewPasswordView`.

`ContentView` registers `.onOpenURL { url in Task { await auth.handleDeepLink(url) } }`. `handleDeepLink(_:)` calls `supabase.auth.session(from: url)` to exchange the link for a session; as a safeguard, if `url.host == "reset-password"` it forces `passwordRecoveryActive = true` regardless of event ordering (recovery links sometimes surface as a plain sign-in).

> **The new app must register the same `wefluens://` scheme and handle both hosts** with equivalent semantics, or migrate to a new scheme and update the Supabase redirect allow-list and both edge-function/email links accordingly.

### Profile flags: `must_change_password` and `is_admin`

Stored on the `profiles` table, keyed by the auth user's `id` (UUID). Read by `AuthManager.checkAccountFlags()`:

```sql
select is_admin, must_change_password from profiles where id = <uid>
```

- **`is_admin`** — gates admin-only features (e.g. inviting users). The `invite-user` edge function independently re-checks `profiles.is_admin` server-side before allowing an invite.
- **`must_change_password`** — when true, `ContentView` renders `ForcePasswordChangeView` instead of the main `RootTabView`, blocking app use until the password is changed.

`ForcePasswordChangeView` (forced mode): requires new password ≥ 8 chars, not equal to the initial password `11111111`, and matching confirmation. On save, `AuthManager.changePassword(to:)` updates the Supabase password **and** writes `must_change_password = false` to the user's `profiles` row, then `mustChangePassword` flips and `ContentView` swaps in the main app. The same view is reusable in non-forced mode (e.g. Privacy & Security) as a voluntary, dismissible password change.

### Bootstrap / gating order (`ContentView`)

When authenticated with a `userId` but no `dataService` yet, the bootstrap task runs in this exact order (must be preserved):

1. `AppDataService(userId:)` created.
2. `syncProfile(userId:email:)` — **creates the profile row if missing** (must run before flags are read).
3. `checkAccountFlags()` — reads `is_admin` + `must_change_password` (requires the profile to exist).
4. `loadBlocks()` — block list loaded before conversations/contacts so blocked users are filtered out.
5. **Terms stamp** (see below).
6. `loadConversations()`, `loadContacts()`, `loadDiscover()`.

Gating precedence after bootstrap: `isLoading` → launch screen; not authenticated → `AuthView`; authenticated + `mustChangePassword` → `ForcePasswordChangeView`; otherwise → `RootTabView`.

### EULA / terms acceptance gate at sign-up

Required for a user-generated-content app. At sign-up the form shows an **agreement row**: a checkbox plus tappable links to the **Terms of Use** and **Community Guidelines** (`LegalDocView(kind: .terms)` / `.guidelines`, shown as sheets). Sign-up is disabled until the checkbox is checked.

The `pendingTermsAccept` UserDefaults bridge wires the UI consent to a server-side timestamp, because at submit time no session/profile yet exists:

1. In `AuthView.submit()` (sign-up branch), just before calling `signUp`, the app sets `UserDefaults.standard.set(true, forKey: AuthView.pendingTermsKey)` where `pendingTermsKey = "wefluens.pendingTermsAccept"`.
2. After a session exists and the profile is synced, `ContentView`'s bootstrap checks that key; if true it calls `await ds.acceptTerms()` and then removes the key (so it is stamped exactly once).
3. `acceptTerms()` writes the acceptance timestamp to **`profiles.terms_accepted_at`** server-side.

The new app must reproduce: the checkbox gate (with reachable Terms + Community Guidelines documents), a durable pending-consent bridge that survives the no-session sign-up window, and a one-time server stamp into `profiles.terms_accepted_at`.

### Legacy invite system (admin pre-created accounts)

An older, admin-driven path that still must be supported. Two edge functions plus an `invites` table and an `app_secrets` table.

**`invite-user` (admin-only).** Requires an authenticated caller (`requireUser`) whose `profiles.is_admin` is true (else `403 FORBIDDEN`). It:
- Validates the email; rejects `INVALID_EMAIL`, and `ALREADY_REGISTERED` if a `profiles` row already exists for that email.
- Generates a 32-byte hex `token`, deletes any prior `pending` invite for that email, and inserts a new `invites` row: `{ email, token, status: "pending", invited_by, expires_at = now + 7 days }`.
- Loads Resend email config (`RESEND_API_KEY`, `RESEND_FROM`) from env **or** the service-role-only `app_secrets` table (Rork private env vars don't reach the Supabase edge runtime; default sender `Wefluens <invite@wefluens.com>`). Returns `EMAIL_NOT_CONFIGURED` if no key.
- Sends a bilingual (zh/en) HTML email via Resend containing the activation link `${SUPABASE_URL}/functions/v1/activate-invite?token=<token>` and the shared **initial password `11111111`**. Link is valid 7 days.
- A `?selfcheck=wefluens-diag` query returns a sanitized diagnostic (never the key itself).

**`activate-invite` (public landing page).** Opened from the invite email link:
- Validates `token`; renders bilingual HTML error pages for missing/invalid (`400/404`), already-activated (success page with `alreadyActive`), or expired (`410`) invites.
- On a valid pending invite, creates a **confirmed** auth user via `admin.auth.admin.createUser({ email, password: "11111111", email_confirm: true })`. The `handle_new_user` DB trigger creates the `profiles` row; this function then updates that row with `must_change_password: true` and `email`, and marks the invite `status: "activated"` with `activated_at`.
- If `createUser` errors (typically user already exists), it treats the invite as already activated.
- Renders an HTML success page instructing the user to open the Wefluens app and sign in with the email + `11111111`, after which the app will force a password change.

**Invited-user end-to-end flow:** admin invites → user clicks email link → `activate-invite` creates a confirmed account (password `11111111`, `must_change_password = true`) → user signs in normally in the app → `checkAccountFlags()` sees `must_change_password` → `ForcePasswordChangeView` forces a new password (rejecting `11111111`) → flag cleared → app unlocked.

### Supabase URL configuration requirements

For the deep links and email flows to work, the Supabase project's **Authentication → URL Configuration** must include:

- **Site URL** — the project's base URL used for default email redirects.
- **Additional Redirect URLs (allow-list)** — must contain both app deep links, or Supabase will reject the `redirectTo`:
  - `wefluens://auth-callback` (sign-up confirmation)
  - `wefluens://reset-password` (password reset)

Additionally: the `wefluens` URL scheme must be registered in the app's `Info.plist`; the **email-confirmation** setting determines whether public sign-up returns a session immediately or routes through the "check your email" screen; and the invite email links point at `${SUPABASE_URL}/functions/v1/activate-invite`, so `SUPABASE_URL` and the edge functions must be deployed/reachable. Resend credentials (`RESEND_API_KEY`, `RESEND_FROM`) must be present in env or the `app_secrets` table for invites to send.

---

I have everything I need. Here is the documentation.

## Trust & Safety (required for Google Play too)

The iOS app ships a complete Trust & Safety stack (built for App Store Guideline 1.2 on user-generated content). **The Android app MUST replicate all of it** — report flow, block flow with full surface filtering, a blocked-accounts management screen, and the in-app Terms of Use + Community Guidelines with a sign-up agreement gate. The backend is shared (Supabase tables `reports`, `blocks`, and `profiles.terms_accepted_at`), so Android only needs the client wiring.

### 1. Report flow

Users can report **a user** (from a profile or chat header) or **a specific message** (1:1 or group). Reports are written to the `reports` table for operator/moderator review.

**Reasons enum** (`ReportReason` — raw value is stored verbatim in `reports.reason`):

| Raw value | User-facing label | Icon (iOS SF Symbol — pick an Android equivalent) |
|---|---|---|
| `spam` | Spam | `exclamationmark.bubble.fill` |
| `harassment` | Harassment | `person.fill.xmark` |
| `hate` | Hate speech | `hand.raised.slash.fill` |
| `sexual` | Sexual content | `eye.slash.fill` |
| `violence` | Violence | `exclamationmark.triangle.fill` |
| `other` | Other | `ellipsis.circle.fill` |

**`reports` table columns** (insert payload `ReportInsert`):

| Column | Type | Notes |
|---|---|---|
| `reporter_id` | UUID | The reporting (current) user. Always set. |
| `reported_user_id` | UUID, nullable | The reported user (set for both user- and message-reports when the author is known). |
| `message_id` | UUID, nullable | Set only when reporting a specific message. |
| `message_kind` | String, nullable | `"dm"` or `"group"`. |
| `content_excerpt` | String, nullable | The reported message text, **truncated to 280 chars** client-side (`String(prefix(280))`) so a long message can't bloat the row. |
| `reason` | String, nullable | One of the six raw enum values above. |

**Report sheet UX** (`ReportSheet` driven by a `ReportTarget` via `.sheet(item:)`):
- Subtitle/explainer, then a single-select list of the six reasons (radio-style checkmark).
- An **"Also block this user"** toggle is shown whenever the target has a blockable user id. On submit, if toggled on, it calls `blockUser` after the report succeeds (best-effort, `try?`).
- Submit button is disabled until a reason is selected; shows a spinner while submitting.
- On success: a confirmation/"thanks" state ("Reports are confidential and reviewed within 24 hours") with success haptic; error path shows an alert.
- `report()` requires an authenticated user (throws "Not signed in" otherwise).

**Where report is wired in:**
- **ContactDetailView** — top-right `...` menu → "Report" builds `ReportTarget(user:name:)`.
- **ChatDetailView (1:1)** — header `...` menu reports the other user; per-message `onReport` builds `ReportTarget(messageId:kind:"dm":excerpt:userId:name:)`.
- **GroupChatDetailView** — header menu + per-message `onReport` builds `ReportTarget(messageId:kind:"group":excerpt:userId: row.message.senderId, name: senderName)`.

### 2. Block flow

Blocks are stored in the `blocks` table and mirrored into an in-memory `Set<UUID> blockedUserIds` for fast filtering.

**`blocks` table columns:**

| Column | Type | Notes |
|---|---|---|
| `blocker_id` | UUID | Current user. |
| `blocked_id` | UUID | The blocked user. |

Composite key `(blocker_id, blocked_id)`; **block is an upsert** (idempotent). `BlockRow` (read) selects only `blocked_id`; `BlockInsert` (write) carries both ids.

**Operations (`AppDataService`):**
- `loadBlocks()` — selects `blocked_id where blocker_id = me`, rebuilds `blockedUserIds`. Called at bootstrap and on every `loadContacts()` (refreshed *before* filtering). Cheap.
- `blockUser(otherId)` — upserts the block, inserts into the in-memory set, **also drops the friendship** (`removeFriend`, best-effort) so the user leaves contacts entirely, then refreshes contacts + conversations so they disappear immediately.
- `unblockUser(otherId)` — deletes the `blocks` row (matched on both ids), removes from the set, refreshes contacts + conversations so the user can reappear.
- `loadBlockedContacts()` — calls `loadBlocks()`, then loads the `profiles` for the blocked ids; returns `[Contact]` sorted by name (for the management screen).

**Exactly which surfaces filter blocked users** (all gated on `blockedUserIds`):
1. **`loadConversations()`** — hides 1:1 threads whose `otherUserId` is blocked (groups have no `otherUserId`, so they remain).
2. **`loadContacts()`** — calls `loadBlocks()` first, then filters blocked users out of the friends list.
3. **`loadGroupMessages()`** — drops individual messages whose `senderId` is blocked (so a blocked member's messages vanish inside a shared group).
4. **`searchUsers()`** — filters blocked users out of search results.

**Where block is wired in:**
- **ContactDetailView** — `...` menu → "Block" (destructive) → confirm → `blockUser(contact.id)` → dismiss back.
- **ChatDetailView (1:1)** — header menu → block confirm → `blockUser(route.otherUserId)`.
- **GroupChatDetailView** — per-message `onBlock` sets a pending block id + confirm → `blockUser(id)`.
- Also reachable via the **"Also block"** toggle in the report sheet.

### 3. Blocked-accounts management screen

`BlockedAccountsView`, reached from **Profile → Privacy & Security → Blocked Accounts** (`PrivacySecurityView` links to it with title/subtitle).

- `.task` calls `loadBlockedContacts()`; shows a spinner while loading.
- **Empty state**: shield icon + "No blocked accounts" title/subtitle.
- **List**: each row = avatar + name + handle + an **"Unblock"** pill button. Tapping it shows a per-row spinner, calls `unblockUser(contact.id)`, removes the row on success (success haptic), and shows an error alert on failure.

Android must provide the equivalent screen reachable from its Privacy & Security settings.

### 4. Terms of Use + Community Guidelines

In-app legal docs (`LegalDocView`, kind = `.terms` or `.guidelines`). Shown at **sign-up (the agreement gate — acceptance is required)** and reachable from **Privacy & Security**. Each renders a title, a "Last updated: June 2026" line, and a list of heading/body sections. Support email: `support@wefluens.com`.

**Acceptance:** after a user signs up having agreed, `acceptTerms()` stamps `profiles.terms_accepted_at` (ISO-8601) via `TermsAcceptedUpdate`. Android must keep the sign-up agreement gate and write the same timestamp.

**Terms of Use (EULA) — 7 sections (use this exact copy on Android):**
1. **Acceptance** — Wefluens Connect is a social platform where creators and brands connect, message, and collaborate; using the app means agreeing to the Terms and Community Guidelines.
2. **Eligibility** — must be at least **17 years old** and legally able to enter the agreement; user responsible for credential security and all account activity.
3. **Your content** — users retain ownership of their content and grant a limited license to host/display it so the app can function.
4. **Zero tolerance for objectionable content and abuse** — no objectionable, abusive, or illegal content/behavior; no harassment/threats/abuse; violations may lead to immediate removal and account termination.
5. **Reporting and moderation** — the app provides tools to report content/users and block abusive users; reports reviewed and acted on **typically within 24 hours**; report from chat/profile, manage blocks in Privacy & Security.
6. **Account deletion** — delete account anytime from Profile → Privacy & Security; the company may suspend/terminate violators.
7. **Disclaimer & contact** — provided "as is"; questions to `support@wefluens.com`.

**Community Guidelines — 5 sections (use this exact copy on Android):**
1. **Be respectful** — professional community; no harassment, bullying, hate speech, or threats.
2. **No objectionable content** — no sexually explicit, violent, hateful, discriminatory, illegal, or exploitative content (text, images, files, group chats); **zero tolerance**, removed on awareness.
3. **No spam or scams** — no unsolicited bulk messages, deceptive offers, phishing, or impersonation.
4. **Report and block** — tap Report on a message/chat/profile; Block a user to cut off contact and visibility; reports are confidential and **reviewed within 24 hours**.
5. **Enforcement** — violating content removed; violators may be suspended or permanently removed; serious violations reported to authorities; safety team at `support@wefluens.com`.

---

Relevant iOS source files (Android parity targets):
- `rork-wefluens/ios-wefluens/WeConnect/Views/Safety/ReportSheet.swift`
- `rork-wefluens/ios-wefluens/WeConnect/Views/Safety/BlockedAccountsView.swift`
- `rork-wefluens/ios-wefluens/WeConnect/Views/Safety/LegalDocView.swift`
- `rork-wefluens/ios-wefluens/WeConnect/Services/AppDataService.swift` (lines ~608–716 for block/report/terms; filtering at ~239, ~347/372, ~420, ~1052)
- `rork-wefluens/ios-wefluens/WeConnect/Models/DatabaseModels.swift` (lines ~45–85: `BlockRow`, `BlockInsert`, `ReportInsert`, `TermsAcceptedUpdate`)
- Wiring: `Views/Contacts/ContactDetailView.swift`, `Views/Chats/ChatDetailView.swift`, `Views/Chats/GroupChatDetailView.swift`, `Views/Profile/PrivacySecurityView.swift`

---

## Localization

The iOS app (`ios-wefluens/WeConnect/Localization.swift`) ships a self-contained, code-only trilingual system — **English (`en`)**, **简体中文 (`zh`)**, **Español (`es`)** — with no `.strings`/`.xcstrings` files or bundle lookups. It has three moving parts:

### Architecture

- **`AppLanguage`** — a `String`-backed `enum` (`CaseIterable`, `Identifiable`) of the three supported locales, each carrying a `nativeName` (e.g. "简体中文") and a `flag` emoji for use in the language picker.
- **`L10n`** — a `String`-backed `enum` enumerating every translatable key (~250 cases), grouped by feature area via `// MARK`-style comment blocks. Keys are camelCase and prefixed by category (`chatRecall…`, `adminInvite…`, etc.), so the key name itself encodes its category.
- **`LocalizationManager`** — an `@Observable` class holding the current `language`. Lookup is `manager.t(_ key: L10n) -> String`, which indexes a nested static dictionary `[AppLanguage: [L10n: String]]`. Translations live entirely in that in-memory `tables` literal.

### Persistence

The chosen language is written to **`UserDefaults`** under the key **`"wefluens.language"`** inside the `language` property's `didSet`. On `init`, the stored raw value is read back and mapped via `AppLanguage(rawValue:)`, defaulting to `.english` if absent or unrecognized.

### Fallback behavior

`t(_:)` is two-level defensive:
1. If the current language's table is missing, fall back to the English table.
2. If a key is missing in the chosen table, fall back to the English value, and if that is also absent, return `key.rawValue` (the raw enum name) so the UI never shows blank. In practice the Chinese table omits a few keys present in English/Spanish (it relies on this English fallback).

### Key categories (approximate counts)

| Category | Key prefix(es) | ~Count |
|---|---|---|
| Tabs | `tab*` | 4 |
| Chats (list) | `chats*` | 8 |
| Chat detail / messaging | `chat*` (detail, attach, recall, forward, clear) | ~40 |
| Forward | `forward*` | 7 |
| Groups (settings + create) | `groupSettings*`, `createGroup*` | ~20 |
| Contacts | `contacts*`, `contactDetail*` | ~20 |
| Add friend / requests | `addFriend*`, `friendRequest*`, `friendAccepted*` | ~18 |
| Discover / campaigns | `discover*`, `filter*`, `campaignDetail*` | ~22 |
| Profile | `profile*` | ~14 |
| Edit profile / privacy | `editProfile*`, `privacy*` | ~18 |
| Settings / theme | `settings*`, `theme*` | ~8 |
| Auth | `auth*`, `forcePw*`, `setPw*` | ~40 |
| Trust & Safety | `report*`, `block*`, `unblock*`, `blocked*`, `legal*` | ~25 |
| Admin | `admin*` | ~22 |

Roughly **250 keys total**, fully translated across all three languages (with the minor Chinese gaps noted above covered by fallback).

### Mirroring this in the Expo app

The cleanest parity is a string-keyed map with a small runtime, using **`i18n-js`** (or `i18next` / `react-i18next` if you want richer plural/interpolation support):

- **Key map** — port the `L10n` cases verbatim as the shared key set, structured as one resource object per locale:
  ```ts
  // i18n/en.ts, zh.ts, es.ts — same keys across all three
  export default { tabChats: "Chats", chatRecallExpired: "…", adminInviteSubtitle: "…" }
  ```
  Reuse the existing camelCase key names so iOS and Expo stay 1:1 and translations can be diffed/shared.
- **Manager equivalent** — wrap `i18n-js` in a small store (Zustand or React Context) exposing `t(key)` and `setLanguage(lang)`, mirroring `LocalizationManager`.
- **Persistence** — store the selected locale under the same logical key, e.g. `AsyncStorage.setItem('wefluens.language', lang)` (you can reuse the literal `"wefluens.language"` string for cross-platform consistency), hydrating it on app launch.
- **Fallback** — set `i18n.defaultLocale = 'en'` and `i18n.enableFallback = true` so missing keys resolve to English, matching the Swift two-level fallback; `i18n-js` returns a `missing translation` marker rather than the raw key, so optionally provide a `missingBehavior` that echoes the key to match the Swift `key.rawValue` behavior.
- **Locale list** — model `AppLanguage` as a constant array of `{ code, nativeName, flag }` to drive the language picker, identical to the Swift enum metadata.

Note the EN and ES tables are the authoritative complete set; when porting, generate the `zh` resource by filling its gaps from EN (or accept the same English fallback at runtime).
