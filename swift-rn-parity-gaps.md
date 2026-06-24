# Wefluens —— Swift ↔ RN 界面对齐文档(双向)

2026-06-23 · 多智能体审计(对抗/自核验)· 精简版

## 图例
- **Swift / RN 列**:✅ 有 · ❌ 没有或明显不完整。**未列出的功能 = 两端均已对齐**。
- **级别**:P1 值得做 · P2 小项 · 装饰 纯视觉。
- 全部经核验(剔除误报);**0 个 P0**(无整屏缺失/功能损坏)。
- 本轮 RN 已补齐(现 ✅✅):点头像看资料 · 隐私连后端 · 云收藏 · 客服表单 · Top Talent/Brands 目录 · 推送客户端。

## 汇总

| 方向 | P1 | P2 | 装饰 | 合计 |
|---|---|---|---|---|
| **Swift 有 / RN 没有** | 16 | 47 | 21 | 84 |
| **RN 有 / Swift 没有** | 3 | 22 | 15 | 40 |

---

## A. Swift 有 / RN 没有(RN 待补)

| 区域 | 项目 | 说明 | Swift | RN | 级别 |
|---|---|---|:---:|:---:|---|
| Forward message | Selected-targets chip bar missing | Swift renders a horizontal, scrollable 'selected' bar above the list whenever totalSelected > 0 (selectedBar).… | ✅ | ❌ | P1 |
| Forward message | Header 'N selected' subtitle missing | Swift's nav bar shows the title 'Forward to…' with a second line '\(totalSelected) selected' under it when targets are chosen.… | ✅ | ❌ | P2 |
| Forward message | Search field has no clear (x) button | Swift's search field shows a tappable xmark.circle.fill that clears searchText when the field is non-empty.… | ✅ | ❌ | P2 |
| Forward message | Group rows missing member-count subtitle | Swift group target rows show a subtitle of '\(group.participantCount) members'.… | ✅ | ❌ | P2 |
| Forward message | Friend rows ignore role, always show @handle | Swift friend rows use the contact's role as the subtitle when it is non-empty, falling back to '@handle' only when role is empty (`subtitle: contact.r… | ✅ | ❌ | P2 |
| Forward message | No haptic feedback on selection or success | Swift fires UISelectionFeedbackGenerator().selectionChanged() on every row toggle and UINotificationFeedbackGenerator().notificationOccurred(.success)… | ✅ | ❌ | P2 |
| Forward message | Empty/loading state differs (no loading spinner, different icon) | Swift's content distinguishes loading from empty: when there are no friends/groups but data is still loading it shows a ProgressView spinner, otherwis… | ✅ | ❌ | P2 |
| Forward message | No animation on selection toggle / chip removal | Swift wraps every selection toggle and chip removal in withAnimation(.spring(...)) so the checkmark and chip bar animate in/out.… | ✅ | ❌ | 装饰 |
| Forward message | Online status dot not shown on rows | Swift passes isOnline: contact.isOnline into the row Avatar so an online dot can appear for online friends.… | ✅ | ❌ | 装饰 |
| Contacts list + Friend requests | No friend-request detail screen (inline-only in RN) | Swift makes each friend request a NavigationLink into a full-screen FriendRequestDetailView: large 96pt avatar with shadow, name, @handle, a filled ro… | ✅ | ❌ | P1 |
| Contacts list + Friend requests | Contact row omits followers count + platform | Swift's ContactRow shows a trailing column with the follower count (bold, rounded font) and the platform label (e.g. Instagram/TikTok).… | ✅ | ❌ | P1 |
| Contacts list + Friend requests | Quick-action cards downgraded to small header icons (no labels) | Swift renders a prominent quickActions row below the search bar: three full-width card-style buttons, each with a 48pt rounded coral-tinted icon and a… | ✅ | ❌ | P2 |
| Contacts list + Friend requests | Search does not match contact role | Swift's filter matches the trimmed query against name, remark, handle AND role (contact.role.localizedCaseInsensitiveContains).… | ✅ | ❌ | P2 |
| Contacts list + Friend requests | Per-request unread indicator dot missing | Swift's FriendRequestRow shows a coral filled dot (8pt circle) on the trailing edge of every pending request row, signaling it's unseen.… | ✅ | ❌ | 装饰 |
| QR scan | No scan-result confirmation overlay (auto-sends silently) | Swift, after a valid scan, sets isScanning=false and shows a full-screen resultOverlay (a dark 0.7 scrim with a card) that presents the scanned person… | ✅ | ❌ | P1 |
| QR scan | No scanned-user preview (avatar + name) before sending | In Swift's resultOverlay idle/sending state, the scanned user is shown with an Avatar (72pt, online dot) and their name in bold, plus a 'Cancel' optio… | ✅ | ❌ | P1 |
| QR scan | No in-screen success state | Swift shows a dedicated .sent success state inside the overlay: a green checkmark icon (size 56, 0x2AD17E), a bold 'sent' title (qrSentTitle), a subti… | ✅ | ❌ | P2 |
| QR scan | No in-screen failure state with retry | Swift shows a dedicated .failed state: a red X icon (size 56), bold failure title (qrFailedTitle), the actual errorMessage (falling back to qrFailedSu… | ✅ | ❌ | P2 |
| QR scan | Scan frame lacks coral corner accents | Swift's scanFrame draws the 240x240 rounded rectangle (white 0.5 stroke) PLUS four coral (Theme.coral) corner accent bars (28x3, rotated/offset to the… | ✅ | ❌ | 装饰 |
| Contact support | Inline animated success state replaced by a plain Alert | Swift renders a dedicated in-screen success state when a ticket is sent: a large green checkmark icon (checkmark.circle.fill, 52pt, #2AD17E) plus a ce… | ✅ | ❌ | P1 |
| Contact support | No success haptic feedback | On a successful submit Swift triggers UINotificationFeedbackGenerator().notificationOccurred(.success) to give tactile confirmation.… | ✅ | ❌ | P2 |
| Contact support | No inline error display; errors only shown via Alert | Swift surfaces failures as inline red error text inside the form (errorText shown below the message field, lines 79-83), and also sets a specific empt… | ✅ | ❌ | P2 |
| Contact support | Send button visual treatment is less rich | Swift's send button uses the Theme.sunset gradient background, a Capsule (pill) shape, and a coral drop shadow (shadow(color: Theme.coral.opacity(0.3)… | ✅ | ❌ | 装饰 |
| Contact support | Field labels not uppercased / no letter-spacing | Swift renders each field label uppercased, bold 12pt, with 1pt tracking (field() helper, lines 120-128).… | ✅ | ❌ | 装饰 |
| Add friend | Accept incoming friend request action missing | Swift's actionButton switches on relationship and, for relationship == "request_received", renders a filled "Accept" pill (l10n .friendRequestAccept) … | ✅ | ❌ | P1 |
| Add friend | Non-blocking toast replaced by blocking native Alert | Swift shows feedback via a custom in-app toast: an animated capsule that springs up from the bottom, stays non-blocking, and auto-dismisses after 2.6s… | ✅ | ❌ | P2 |
| Add friend | Success haptic feedback missing | Swift fires haptic(.success) (UINotificationFeedbackGenerator) when a friend request is successfully sent (status "sent") and when an incoming request… | ✅ | ❌ | P2 |
| Add friend | No user feedback for already_friends / incoming_exists results | When sendFriendRequest returns a non-'sent' status, Swift still surfaces a toast: "already_friends" shows addFriendAlreadyFriends and "incoming_exists… | ✅ | ❌ | P2 |
| Change password (voluntary) + forced first-login change | Missing 'new password must differ from initial' validation | Swift save() guards `newPassword != initialPassword` ("11111111") and shows a dedicated error forcePwSameAsInitial ("Please pick a password different … | ✅ | ❌ | P1 |
| Change password (voluntary) + forced first-login change | No decorative animated glow background | Swift renders a sunset-tinted blurred Circle (260x260, blur 80, opacity 0.25) behind the content as a hero glow, offset by y:-120 and animating up to … | ✅ | ❌ | 装饰 |
| Change password (voluntary) + forced first-login change | Hero icon differs (lock.rotation + coral shadow vs plain lock) | Swift uses the SF Symbol `lock.rotation` inside the icon circle with a coral-tinted drop shadow (radius 24, y 8).… | ✅ | ❌ | 装饰 |
| Change password (voluntary) + forced first-login change | No keyboard-driven background motion | Swift observes keyboardWillShow/WillHide notifications and animates the glow offset (and overall layout feel) when the keyboard appears.… | ✅ | ❌ | 装饰 |
| Reset password (deep link / set new password) | No success confirmation screen after reset | Swift shows a dedicated successView once the password update succeeds: a checkmark icon in a circle, the setPwSuccess message ("Your password has been… | ✅ | ❌ | P1 |
| Reset password (deep link / set new password) | Wrong subtitle copy used on recovery screen | Swift uses the recovery-appropriate string forcePwSubtitleOptional ("Choose a new password for your account.") as the subtitle.… | ✅ | ❌ | P2 |
| Reset password (deep link / set new password) | Missing decorative blurred circle and keyboard animation | Swift draws an animated sunset-colored blurred Circle behind the content that floats upward (offset -120 -> -220) with an easeOut animation when the k… | ✅ | ❌ | 装饰 |
| Reset password (deep link / set new password) | No state-transition / error animations | Swift animates the form-to-success crossfade (.animation(.easeInOut, value: didSucceed)) and fades the inline error in/out (.transition(.opacity) plus… | ✅ | ❌ | 装饰 |
| Chats list | Unread count in header subtitle is broken/missing | Swift header shows the live unread count as its own string: when totalUnread > 0 it renders "<N> <chatsUnread>" (e.g.… | ✅ | ❌ | P1 |
| Chats list | Online presence dot on conversation avatars not shown | Swift ConversationRow passes `isOnline: conversation.isOnline` into the Avatar, which renders a green presence dot for online users (ChatsListView.swi… | ✅ | ❌ | P2 |
| Chats list | Official / verified badge missing on conversation rows | Swift shows a coral checkmark.seal.fill verified badge next to the name when `conversation.isOfficial` is true (ChatsListView.swift `ConversationRow.b… | ✅ | ❌ | P2 |
| Group chat (create + detail) | Create group: selected-friends chips bar missing | Swift CreateGroupView renders a horizontal scrolling 'selectedBar' of removable avatar chips for every chosen friend (each chip = avatar + name + an x… | ✅ | ❌ | P1 |
| Group chat (create + detail) | Create group: empty-state hint subtitle missing | Swift's no-friends empty state shows a title (createGroupNoFriends) plus an explanatory subtitle (createGroupNoFriendsHint) telling the user how to ge… | ✅ | ❌ | P2 |
| Group chat (create + detail) | Create group: nav subtitle prompt when nothing selected missing | Swift's create-group nav bar always shows a subtitle: 'Select friends' (createGroupSelect) when nothing is chosen, switching to 'N selected' once frie… | ✅ | ❌ | P2 |
| Profile / Me | FAQ / Help screen not reachable from Me tab | Swift's Support group has a dedicated 'Help & FAQ' row (questionmark.circle.fill) that pushes FAQView — a static screen with 8 curated Q&A entries (ad… | ✅ | ❌ | P1 |
| Profile / Me | Favorites demoted from primary card to plain menu row; count subtitle dropped | Swift presents Favorites as its own prominent banner card directly under the QR banner (favoritesRow): 46x46 sunset-colored star icon, title, and a dy… | ✅ | ❌ | P2 |
| Edit profile | Location field is read-only in RN (cannot type a location) | Swift's location TextField is freely editable — the user can type any 'City, Country' manually, and it is only temporarily disabled while actively loc… | ✅ | ❌ | P1 |
| Edit profile | Locate button has fewer visual feedback states in RN | Swift's locateButton renders six distinct states via LocationStatus: idle (locate icon), locating (spinner), resolved (green checkmark that animates t… | ✅ | ❌ | P2 |
| Admin user management | Invite sheet much less polished (no subtitle/icon/initial-password hint) | Swift's InviteUserSheet is a full NavigationStack sheet with a paperplane icon, bold title (adminInviteTitle), and a subtitle that tells the admin the… | ✅ | ❌ | P1 |
| Admin user management | Ban / unban have no confirmation dialog | Swift gates ban and unban behind confirmationDialogs with descriptive messages ('NAME (EMAIL) will be blocked from signing in.' / '… will be able to s… | ✅ | ❌ | P1 |
| Help & FAQ | 'Help' row conflated with Contact Support; FAQ and Contact are not separate entries | In Swift the Support group (supportGroup) has Help & FAQ and Contact Support as two distinct rows: 'Help & FAQ' (questionmark.circle.fill) → FAQView, … | ✅ | ❌ | P1 |
| Chat detail (DM) | No avatar in chat header | Swift's navBar renders an Avatar (with the contact's image/initials and an online dot) next to the name and status, all wrapped in a button that opens… | ✅ | ❌ | P2 |
| Chat detail (DM) | Online/offline status is hardcoded, never live | Swift shows the other user's presence in the header: 'Active now' in green (0x2AD17E) when route.isOnline is true, otherwise 'Offline' in secondary in… | ✅ | ❌ | P2 |
| Chat detail (DM) | No full-screen recording HUD while holding the mic | Swift shows a prominent centered recording overlay while the mic is held down: a dimmed backdrop, an animated waveform symbol (variableColor iterative… | ✅ | ❌ | P2 |
| Chat detail (DM) | No Share action in the fullscreen image viewer | Swift's FullscreenImageView has three controls: close, save-to-Photos (with checkmark flash), and a ShareLink that opens the system share sheet.… | ✅ | ❌ | P2 |
| Chat detail (DM) | File bubble uses a single generic icon (no per-type icon/color) | Swift's ChatFileBubble picks a type-specific SF Symbol and color by extension: PDF (red doc.richtext), Word (blue doc.text), Excel/CSV (green tablecel… | ✅ | ❌ | P2 |
| Chat detail (DM) | No client-side file-size cap with a 'file too large' error | Swift enforces a 25 MB cap when importing a document and surfaces a real localized error (chatFileTooLarge) if the picked file exceeds it (and chatFil… | ✅ | ❌ | P2 |
| Chat detail (DM) | Quoted-reply preview is plainer (single gray line, no accent bar / panel) | Swift's QuotedReplyPreview renders a gradient (Theme.sunset) accent bar, the sender name on its own semibold line, and the quoted text on a second lin… | ✅ | ❌ | 装饰 |
| Auth (Sign-in + Sign-up) | Per-field inline validation errors | Swift shows individual error text + red border under each field; RN shows a single shared error box at the top. | ✅ | ❌ | P2 |
| Auth (Sign-in + Sign-up) | Rate-limit (429) specific message | Swift classifies errors and shows a tailored 'too many attempts, wait' message; RN just surfaces the raw error string. | ✅ | ❌ | P2 |
| Auth (Sign-in + Sign-up) | Keyboard-reactive background glow | Swift animates a blurred coral glow upward when the keyboard appears; RN has a static gradient background. | ✅ | ❌ | 装饰 |
| Auth (Sign-in + Sign-up) | Layered glowing logo | Swift logo is a double-circle with coral shadow glow; RN logo is a single flat circle. | ✅ | ❌ | 装饰 |
| Auth (Sign-in + Sign-up) | Terms/Guidelines as in-app sheets | Swift opens Terms and Community Guidelines in modal sheets over the form; RN navigates away to a separate /legal route. | ✅ | ❌ | 装饰 |
| Top Talent | No success/error toast — uses blocking Alert instead | Swift shows a custom non-blocking toast that slides up from the bottom and auto-dismisses after 2.6s (toastView, lines 221-235; showToast, lines 354-3… | ✅ | ❌ | P2 |
| Top Talent | No haptic feedback on friend actions | Swift fires UINotificationFeedbackGenerator success haptic when a friend request is successfully sent (addFriend, line 315) and when an incoming reque… | ✅ | ❌ | P2 |
| Top Talent | No pull-to-refresh on the directory list | Swift attaches .refreshable to the directory ScrollView so users can pull down to reload Top Talent (content, line 128: `.refreshable { if !isSearchAc… | ✅ | ❌ | P2 |
| Top Talent | No user feedback for already_friends / incoming_exists results | When sendFriendRequest returns 'already_friends' Swift shows a toast (addFriendAlreadyFriends, line 320) and for 'incoming_exists' shows a toast promp… | ✅ | ❌ | P2 |
| Contact / other-user profile | Online presence dot missing on hero avatar | Swift hero renders the Avatar with isOnline (Avatar(..., isOnline: contact.isOnline)) so a friend who is online shows the green presence dot on their … | ✅ | ❌ | P2 |
| Contact / other-user profile | Status / Platform stats are hardcoded instead of reflecting the contact | Swift stats row shows real values: platform stat = contact.platform, and status stat = contact.isOnline ? Online : Away (lines 178-180).… | ✅ | ❌ | P2 |
| Contact / other-user profile | Audience info row degraded to plain followers count | Swift's Details card third row is 'Audience' showing a combined value '\(contact.followers) on \(contact.platform)' (e.g.… | ✅ | ❌ | P2 |
| Contact / other-user profile | No success haptic feedback on block / remove | Swift fires UINotificationFeedbackGenerator().notificationOccurred(.success) after a successful block (line 133) and after a successful remove-friend … | ✅ | ❌ | 装饰 |
| Favorites | No haptic feedback on remove | Swift fires UISelectionFeedbackGenerator().selectionChanged() when a favorite is deleted, giving tactile confirmation.… | ✅ | ❌ | P2 |
| Favorites | No removal animation | Swift wraps the delete in withAnimation(.easeInOut(duration: 0.2)) so the row animates out of the list.… | ✅ | ❌ | P2 |
| Favorites | Text favorites have no leading icon badge | Swift gives EVERY row (including plain text) a colored coral SF Symbol badge in a rounded coral-tinted square (icon(for:) returns text.bubble for the … | ✅ | ❌ | P2 |
| Brands directory | No loading spinner on initial load | Swift shows a centered ProgressView (coral-tinted, scaled 1.1) while data loads when brands is empty (`if isLoading && brands.isEmpty { ProgressView()… | ✅ | ❌ | P2 |
| Brands directory | No animation on category chip selection | Swift animates category chip toggles with a spring (`withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }` in the `chip` helper), … | ✅ | ❌ | 装饰 |
| Campaign detail | Deliverables heading not localized in RN | Swift renders the Deliverables section heading via l10n.t(.campaignDetailDeliverables), which is translated to English/Chinese/Spanish in Localization… | ✅ | ❌ | P2 |
| Campaign detail | 'Estimated payout' label not localized in RN | In the bottom apply bar, Swift uses l10n.t(.campaignDetailEstimatedPayout), translated in all three languages.… | ✅ | ❌ | P2 |
| My QR code | No signed-out / missing-user prompt | Swift: when auth.userId is nil it does NOT render the QR card and instead shows a localized sign-in prompt text (l10n.t(.qrSignInPrompt)) so the user … | ✅ | ❌ | P2 |
| My QR code | Avatar drop shadow missing | Swift adds a soft drop shadow under the profile avatar in the QR header (.shadow(color: .black.opacity(0.12), radius: 14, y: 8)).… | ✅ | ❌ | 装饰 |
| Group info / members / settings | No haptic feedback on any interaction | The Swift screen fires haptics throughout: UISelectionFeedbackGenerator().selectionChanged() when opening Add Members, toggling mute, and toggling a c… | ✅ | ❌ | P2 |
| Settings | Missing section footer/help text under both cards | Swift renders an explanatory footer line below each settings card: settingsLanguageFooter ("Choose your preferred language.… | ✅ | ❌ | P2 |
| Blocked accounts | No success haptic on unblock | Swift fires a success haptic (UINotificationFeedbackGenerator().notificationOccurred(.success)) immediately after a successful unblock, giving tactile… | ✅ | ❌ | P2 |
| Shared UI components / primitives | Avatar white ring stroke | Every Swift Avatar gets a subtle white 0.4-opacity circle stroke overlay; RN Avatar has no border ring around the circle. | ✅ | ❌ | 装饰 |
| Shared UI components / primitives | Card elevation shadow | Swift cardStyle adds a soft drop shadow (radius 18); RN Card primitive only has border, no shadow. | ✅ | ❌ | 装饰 |
| Discover | No spring animation on filter / brand selection | Swift wraps both the category-chip filter change and the brand-card tap in withAnimation(.spring(response:0.3, dampingFraction:0.7)) so the chip highl… | ✅ | ❌ | 装饰 |

## B. RN 有 / Swift 没有(Swift 待补)

| 区域 | 项目 | 说明 | Swift | RN | 级别 |
|---|---|---|:---:|:---:|---|
| Edit profile | Handle uniqueness check | RN pre-checks api.isHandleAvailable and shows a 'handle taken' alert; Swift only validates format and relies on a generic DB error. | ❌ | ✅ | P1 |
| Edit profile | Live handle sanitization + max length | RN strips invalid chars to [a-z0-9_] and caps at 20 chars while typing; Swift allows any input with no maxLength. | ❌ | ✅ | P2 |
| Edit profile | Invalid-handle feedback | RN alerts when the handle fails the regex; Swift silently keeps Save disabled with no explanation to the user. | ❌ | ✅ | P2 |
| Edit profile | Field hint text | RN shows helper hints under the Handle and Location fields; Swift renders no hint labels. | ❌ | ✅ | 装饰 |
| Edit profile | Read-only location field | RN makes location editable=false (set only via GPS locate button); Swift lets users freely type into the location field. | ❌ | ✅ | 装饰 |
| Favorites | Viewable/playable media favorites | RN renders image thumbnails (open fullscreen), video (tap to play), file (share/open), and audio (playable bubble); Swift shows only an icon + text preview for every kind. | ❌ | ✅ | P1 |
| Favorites | Permanent on-device media copy | RN downloads a permanent local copy of favorited media so it still opens after server media expires; Swift stores no media path/file, so media is unrecoverable. | ❌ | ✅ | P1 |
| Favorites | File name shown on favorite row | RN file favorites display the real fileName; Swift has no fileName field so file favorites show only a generic preview string. | ❌ | ✅ | P2 |
| Chat detail (DM) | Delete confirmation dialog | RN asks to confirm single + batch message delete; Swift deletes instantly from the context menu with no confirmation. | ❌ | ✅ | P2 |
| Chat detail (DM) | Distinct 'friend removed' send error | On send failure RN checks if the contact was unfriended and shows chatFriendRemoved; Swift always shows the generic send-error alert. | ❌ | ✅ | P2 |
| Chat detail (DM) | Image-expired load fallback | RN image bubble shows an 'image expired' text + icon when the signed URL fails; Swift shows only a bare photo placeholder icon. | ❌ | ✅ | 装饰 |
| Chat detail (DM) | Copy confirmation toast | RN shows a 'Copied' toast after copying message text; Swift copies to the pasteboard silently with no feedback. | ❌ | ✅ | 装饰 |
| QR scan | Friend-request status feedback (already friends / incoming / sent) | RN shows distinct toasts for already_friends, incoming_exists, sent; Swift QRScanView ignores the RPC status and only shows generic sent/failed. | ❌ | ✅ | P2 |
| QR scan | Invalid-code and self-scan user feedback | RN notifies the user on invalid QR (qrInvalid) and self-scan (qrSelf); Swift silently returns with no feedback in both cases. | ❌ | ✅ | P2 |
| QR scan | Camera permission recovery UI | RN shows a 'grant camera permission' screen with a button when denied; Swift only shows a static placeholder label with no way to re-request access. | ❌ | ✅ | P2 |
| QR scan | Web/unsupported platform fallback | RN renders a dedicated web fallback screen explaining scanning needs the native camera; Swift has no equivalent (iOS-only) handling. | ❌ | ✅ | 装饰 |
| Group chat (create + detail) | Tap quoted reply to jump + highlight | RN group chat scrolls to the original on tapping a quote/pinned banner and flashes a highlight; Swift's group quote is non-tappable with no scroll-to-original. | ❌ | ✅ | P2 |
| Group chat (create + detail) | @everyone mention option | RN's @ mention picker includes a top '@everyone' entry; Swift's mention picker only lists individual members. | ❌ | ✅ | P2 |
| Group chat (create + detail) | Highlight bubbles that @-mention me | RN tints/borders incoming bubbles that mention me or @everyone; Swift only colors the @token text, no bubble-level highlight. | ❌ | ✅ | P2 |
| Discover | Pull-to-refresh on Discover | RN wraps the Discover ScrollView in a RefreshControl calling refreshDiscover(); Swift DiscoverView has no .refreshable. | ❌ | ✅ | P2 |
| Discover | Tag chips on campaign cards | RN CampaignCard renders campaign.tags as TagChips; Swift CampaignCard never displays tags (only uses them for filtering). | ❌ | ✅ | P2 |
| Discover | Empty states for brands/campaigns | RN shows EmptyState/no-brands & no-campaigns messages when lists are empty; Swift renders nothing with no empty-state UI. | ❌ | ✅ | P2 |
| Chats list | Delete clears chat history + warning subtitle | RN delete clears DM/group history then hides, with a destructive warning body; Swift only hides with a title-only alert. | ❌ | ✅ | P2 |
| Chats list | Unread badge caps at 99+ | RN caps the unread count display at "99+"; Swift renders the raw unbounded number, breaking the badge for large counts. | ❌ | ✅ | 装饰 |
| Chats list | Long-press action sheet shows conversation name | RN's long-press sheet has the conversation name as a title header; Swift's contextMenu shows no title. | ❌ | ✅ | 装饰 |
| Campaign detail | Withdraw-application confirmation | RN shows a destructive confirm dialog before withdrawing; Swift toggles the Applied capsule back instantly with no prompt. | ❌ | ✅ | P2 |
| Campaign detail | Distinct "Applied" button state | RN renders an outlined coral pill with checkmark when applied; Swift just greys the same capsule. | ❌ | ✅ | 装饰 |
| Contact / other-user profile | Dedicated "Set remark" card row | RN shows an always-visible remark card (pricetag icon, inline current value, chevron) on the profile; Swift hides remark editing inside the overflow menu only. | ❌ | ✅ | P2 |
| Contact / other-user profile | Custom remark editor modal | RN edits the remark via a styled modal with TextField, 40-char limit, Cancel/Save buttons; Swift uses a plain system alert TextField. | ❌ | ✅ | 装饰 |
| Contacts list + Friend requests | Empty state for no contacts | RN shows an EmptyState ('No contacts yet' / search-no-results) when the list is empty; Swift renders nothing below the quick actions. | ❌ | ✅ | P2 |
| Add friend | Real profile photos in search results | RN passes imageUrl=avatar_url so result rows show real avatars; Swift AddFriendView omits imageURL and always shows initials. | ❌ | ✅ | P2 |
| Profile / Me | Deep-link to OS settings on notification denial | When push permission is denied, RN reverts the toggle and opens system notification settings; Swift just reverts silently with no guidance. | ❌ | ✅ | P2 |
| Notifications | Deep-link to OS settings on permission denial | RN reverts the notif toggle AND calls Linking.openSettings() to send the user to system settings; Swift only silently reverts. | ❌ | ✅ | P2 |
| Report / Trust & Safety | Privacy Policy legal document | RN has a full Privacy Policy doc (legal.tsx doc='privacy', linked from About); Swift LegalDocView only has Terms + Guidelines, no privacy policy. | ❌ | ✅ | P2 |
| Contact support | Intro/description text on support form | RN shows an intro line ('Tell us what went wrong... we read every message') above the fields; Swift form has no intro text. | ❌ | ✅ | 装饰 |
| Contact support | Field placeholder text | RN sets placeholders on subject ('Brief summary') and message ('Describe your issue…'); Swift TextField/TextEditor have empty placeholders. | ❌ | ✅ | 装饰 |
| Shared UI components / primitives | ActionSheet primitive (cross-platform bottom sheet) | RN ships a reusable ActionSheet component for row/message menus; Swift uses ad-hoc confirmationDialog/context menus, no shared sheet primitive. | ❌ | ✅ | 装饰 |
| Shared UI components / primitives | SecondaryButton accepts custom tint color | RN SecondaryButton takes a color prop (defaults coral); equivalent tinted pill button isn't a shared Swift primitive. | ❌ | ✅ | 装饰 |
| Settings | Appearance option icons | RN shows an icon (phone/sunny/moon) on each theme row; Swift's appearance rows show text label only. | ❌ | ✅ | 装饰 |
| Change password | Success toast on voluntary password change | RN change-password screen shows a 'Password changed.' toast on success; Swift's forced=false flow just dismisses the sheet silently. | ❌ | ✅ | 装饰 |
