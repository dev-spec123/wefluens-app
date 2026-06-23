//
//  Localization.swift
//  WeConnect
//
//  Lightweight trilingual (EN / 中文 / Español) localization system.
//

import SwiftUI

/// Supported app languages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh"
    case spanish = "es"

    var id: String { rawValue }

    /// Name shown in its own language.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        case .spanish: return "Español"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .chinese: return "🇨🇳"
        case .spanish: return "🇪🇸"
        }
    }
}

/// Translation keys used across the app.
enum L10n: String {
    // Tabs
    case tabChats, tabContacts, tabDiscover, tabMe

    // Chats
    case chatsTitle, chatsUnread, chatsCaughtUp, chatsSearch, chatsPinned, chatsMessages, chatsEmpty
    case chatsNewGroup

    // Conversation context menu (pin / mute / delete)
    case convPin, convUnpin, convMute, convUnmute, convDelete

    // ChatDetail
    case chatDetailActiveNow, chatDetailOffline, chatDetailToday, chatDetailMessagePlaceholder
    case chatDetailGroupMembers
    case chatYouPrefix, chatThreadEmpty, chatStartError, chatSendError, chatImagePreview
    case chatFilePreview, chatAttachPhoto, chatAttachFile, chatFileTooLarge, chatFileError
    case chatVoice, chatHoldToTalk, chatRecording, chatVoicePermissionDenied
    case chatRead, chatDelivered
    case chatReply, chatCopy, chatYou, chatVideoPreview
    case chatForward, chatDelete, chatRecall, chatRecallFailed, chatRecallExpired, chatRecallAlreadyRecalled, chatRecallForbidden, chatRecallError, chatClearHistory, chatClearHistoryConfirm, chatMessageRecalled, chatDeleteConversation

    // Forward message
    case forwardTitle, forwardSend, forwardFriends, forwardGroups
    case forwardSearch, forwardNoTargets, forwardError

    // Group settings
    case groupSettingsTitle, groupSettingsMembers, groupSettingsAddMembers
    case groupSettingsName, groupSettingsNamePlaceholder, groupSettingsSave
    case groupSettingsOwner, groupSettingsRemove, groupSettingsRemoveConfirm
    case groupSettingsRenameError, groupSettingsAddError, groupSettingsRemoveError
    case groupSettingsNoFriendsToAdd
    case groupSettingsChangePhoto, groupSettingsMute
    case groupSettingsLeave, groupSettingsLeaveConfirm
    case groupSettingsDissolve, groupSettingsDissolveConfirm

    // Contacts
    case contactsTitle, contactsSubtitle, contactsSearch, contactsInvite, contactsTopTalent, contactsBrands
    case contactsNewFriends, contactsFriendRequests, contactsAddFriend
    case talentEmpty, brandsEmpty, brandsNoCampaigns, brandsSearch, brandsNoMatches
    case talentSearch, talentOptInHint
    case contactsRemark, contactsSetRemark

    // Add Friend (search + request)
    case addFriendSearchPlaceholder, addFriendHint, addFriendNoResults, addFriendSearching
    case addFriendAdd, addFriendRequested, addFriendFriends, addFriendSent
    case addFriendAlreadyFriends, addFriendIncoming, addFriendError
    case friendAcceptedTitle, friendAcceptedMessage

    // FriendRequestDetail
    case friendRequestAccept, friendRequestDecline, friendRequestMessage
    case friendRequestAdded, friendRequestDeclined, friendRequestError

    // ContactDetail
    case contactDetailFollowers, contactDetailPlatform, contactDetailStatus
    case contactDetailOnline, contactDetailAway, contactDetailMessage
    case contactDetailDetails, contactDetailHandle, contactDetailRole, contactDetailAudience
    case contactDetailRemoveFriend, contactDetailRemoveFriendMsg, contactDetailRemoveFriendError

    // Create Group
    case createGroupTitle, createGroupSelect, createGroupCreate, createGroupSearch
    case createGroupSelected, createGroupNamePlaceholder, createGroupNoFriends
    case createGroupNoFriendsHint, createGroupError

    // Discover
    case discoverTitle, discoverSubtitle, discoverFeatured, discoverViewBrief, discoverTopBrands, discoverOpenCampaigns, discoverActive
    case discoverDue, discoverSpotsLeft
    case filterAll, filterBeauty, filterFashion, filterWellness, filterTech

    // CampaignDetail
    case campaignDetailBudget, campaignDetailDeadline, campaignDetailSpots
    case campaignDetailApply, campaignDetailApplied, campaignDetailAbout, campaignDetailDeliverables
    case campaignDetailEstimatedPayout

    // Edit Profile
    case editProfileTitle, editProfileName, editProfileBio, editProfileLocation, editProfileSave
    case editProfileLocationPlaceholder, editProfileAutoLocate, editProfileLocating
    case editProfileChangePhoto, editProfilePhotoUpdated

    // Privacy & Security
    case privacyTitle, privacyBlockedAccounts, privacyBlockedAccountsSub
    case privacyVisibility, privacyVisibilitySub
    case privacyActivityStatus, privacyActivityStatusSub
    case privacyDataSharing, privacyDataSharingSub

    // Profile
    case profileEdit, profileReach, profileEngagement, profileDeals
    case profileOpenDeals, profileOpenDealsSub
    case profilePreferences, profileNotifications, profilePrivacy, profileLanguage
    case profileSupport, profileHelp, profileContact, profileRate
    case profileSignOut
    case faqTitle
    case supportFormTitle, supportSubjectField, supportMessageField
    case supportSendButton, supportSentMsg, supportErrorMsg, supportEmptyMsg

    // Settings
    case settingsTitle, settingsLanguage, settingsLanguageFooter, settingsDone
    case settingsAppearance, settingsAppearanceFooter

    // Theme
    case themeSystem, themeLight, themeDark

    // Auth
    case authTagline, authEmailPlaceholder, authPasswordPlaceholder
    case authConfirmPasswordPlaceholder, authPasswordMismatch
    case authSignUpButton, authSignInButton, authNoAccount, authHaveAccount
    case authVerificationSentTitle, authVerificationSentMessage, authVerificationSentOk
    case authVerifyTitle, authVerifySubtitle, authVerifyButton
    case authResendCode, authResendIn, authChangeEmail, authCodeResent
    case authInviteOnly
    case authForgotPassword, authResetSentTitle, authResetSentMessage
    case authErrInvalidEmail, authErrPasswordShort, authErrPasswordRequired
    case authErrRateLimit, authErrGeneric
    case authCheckEmailTitle, authCheckEmailMessage, authBackToSignIn, setPwSuccess

    // Forced password change
    case forcePwTitle, forcePwSubtitle, forcePwSubtitleOptional, forcePwNew, forcePwConfirm
    case forcePwSave, forcePwTooShort, forcePwSameAsInitial, forcePwChangePassword

    // Admin
    case adminTitle, adminAllUsers, adminDeactivate, adminDelete, adminDeactivateConfirm
    case adminDeleteConfirm, adminCancel, adminNoUsers, adminStatusActive, adminStatusDeactivated
    case adminBadge
    case adminInvite, adminInviteTitle, adminInviteSubtitle, adminInviteEmailPlaceholder
    case adminInviteSend, adminInviteSent, adminInviteErrInvalid, adminInviteErrExists
    case adminInviteErrEmail, adminInviteErrSend, adminInviteErrGeneric

    // Trust & Safety (block / report / terms)
    case reportTitle, reportSubtitle
    case reportReasonSpam, reportReasonHarass, reportReasonHate
    case reportReasonSexual, reportReasonViolence, reportReasonOther
    case reportSubmit, reportThanksTitle, reportThanksMessage, reportAlsoBlock, reportError
    case blockAction, blockConfirm, blockError, unblockAction, unblockConfirm
    case blockedEmptyTitle, blockedEmptySub
    case legalTerms, legalGuidelines, legalSafety
    case authAgreePrefix

    // Favorites (收藏) of messages
    case favoritesTitle, favoriteAction, favoritesEmpty

    // Pinned group message (群公告 banner)
    case pinMessage, unpinMessage, pinnedLabel

    // Parity batch: account deletion, About screen, chats "+" menu
    case profileDeleteAccount, profileDeleteMessage, profileDeleteConfirm
    case profileAbout, aboutTitle, aboutVersion
    case chatsAddFriend, chatsScan
    case chatSelect, chatSelectedLabel
}

/// App-wide localization manager. Persists the chosen language.
@Observable
final class LocalizationManager {
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    private static let storageKey = "wefluens.language"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    /// Returns the localized string for the given key in the current language.
    func t(_ key: L10n) -> String {
        let table = Self.tables[language] ?? Self.tables[.english]!
        return table[key] ?? Self.tables[.english]?[key] ?? key.rawValue
    }

    private static let tables: [AppLanguage: [L10n: String]] = [
        .english: [
            .tabChats: "Chats", .tabContacts: "Contacts", .tabDiscover: "Discover", .tabMe: "Me",
            .chatsTitle: "Chats", .chatsUnread: "unread messages", .chatsCaughtUp: "You're all caught up",
            .chatsSearch: "Search conversations", .chatsPinned: "Pinned", .chatsMessages: "Messages",
            .chatsEmpty: "No conversations found", .chatsNewGroup: "New Group",
            .convPin: "Pin to top", .convUnpin: "Unpin", .convMute: "Mute",
            .convUnmute: "Unmute", .convDelete: "Delete",
            .chatDetailActiveNow: "Active now", .chatDetailOffline: "Offline",
            .chatDetailToday: "Today", .chatDetailMessagePlaceholder: "Message…",
            .chatDetailGroupMembers: "members",
            .chatYouPrefix: "You: ",
            .chatThreadEmpty: "Say hello 👋",
            .chatStartError: "Couldn't open the chat. Please try again.",
            .chatSendError: "Couldn't send. Please try again.",
            .chatImagePreview: "[Photo]",
            .chatFilePreview: "[File]",
            .chatAttachPhoto: "Photo",
            .chatAttachFile: "File",
            .chatFileTooLarge: "File too large (max 25 MB).",
            .chatFileError: "Couldn't attach that file. Please try again.",
            .chatVoice: "[Voice]",
            .chatHoldToTalk: "Hold to talk",
            .chatRecording: "Recording… release to send",
            .chatVoicePermissionDenied: "Microphone access is off. Enable it in Settings to send voice messages.",
            .chatRead: "Read",
            .chatDelivered: "Delivered",
            .chatReply: "Reply",
            .chatCopy: "Copy",
            .chatYou: "You",
            .chatVideoPreview: "[Video]",
            .chatForward: "Forward",
            .chatDelete: "Delete",
            .chatRecall: "Recall",
            .chatRecallFailed: "Couldn't recall. Either you're not the sender or the 2-minute window has expired.",
            .chatRecallExpired: "The 2-minute recall window has expired.",
            .chatRecallAlreadyRecalled: "This message has already been recalled.",
            .chatRecallForbidden: "You can only recall your own messages.",
            .chatRecallError: "Couldn't recall. Please try again.",
            .chatClearHistory: "Clear Chat History",
            .chatDeleteConversation: "Delete this conversation? It will only be removed for you.",
            .chatClearHistoryConfirm: "Clear all chat history? This only affects you — everyone else keeps their messages.",
            .chatMessageRecalled: "Message recalled",
            .forwardTitle: "Forward to…",
            .forwardSend: "Send",
            .forwardFriends: "Friends",
            .forwardGroups: "Groups",
            .forwardSearch: "Search…",
            .forwardNoTargets: "No conversations available",
            .forwardError: "Couldn't forward. Please try again.",
            .groupSettingsTitle: "Group Info",
            .groupSettingsMembers: "Members",
            .groupSettingsAddMembers: "Add Members",
            .groupSettingsName: "Group Name",
            .groupSettingsNamePlaceholder: "Group name",
            .groupSettingsSave: "Save",
            .groupSettingsOwner: "Owner",
            .groupSettingsRemove: "Remove",
            .groupSettingsRemoveConfirm: "Remove this member from the group?",
            .groupSettingsRenameError: "Couldn't rename the group. Please try again.",
            .groupSettingsAddError: "Couldn't add members. Please try again.",
            .groupSettingsRemoveError: "Couldn't remove this member. Please try again.",
            .groupSettingsNoFriendsToAdd: "All your friends are already in this group",
            .groupSettingsChangePhoto: "Change Group Photo",
            .groupSettingsMute: "Mute Notifications",
            .groupSettingsLeave: "Leave Group",
            .groupSettingsLeaveConfirm: "Leave this group? You'll stop receiving its messages.",
            .groupSettingsDissolve: "Dissolve Group",
            .groupSettingsDissolveConfirm: "Dissolve this group? It will be permanently removed for everyone. This can't be undone.",
            .contactsTitle: "Contacts", .contactsSubtitle: "creators & partners", .contactsSearch: "Search contacts",
            .contactsInvite: "Invite", .contactsTopTalent: "Top Talent", .contactsBrands: "Brands",
            .contactsNewFriends: "New Friends", .contactsFriendRequests: "Friend Request",
            .contactsAddFriend: "Add Friend",
            .talentEmpty: "No creators here yet.",
            .brandsEmpty: "No brands available yet.",
            .brandsNoCampaigns: "No open campaigns from this brand right now.",
            .brandsSearch: "Search brands",
            .brandsNoMatches: "No brands match your search.",
            .talentSearch: "Search creators",
            .talentOptInHint: "Turn on “Discoverable” in Privacy & Security to appear in this directory.",
            .contactsRemark: "Remark", .contactsSetRemark: "Set remark",
            .addFriendSearchPlaceholder: "Search by email or @handle",
            .addFriendHint: "Find people by their email or username, then send a friend request.",
            .addFriendNoResults: "No users found",
            .addFriendSearching: "Searching…",
            .addFriendAdd: "Add",
            .addFriendRequested: "Requested",
            .addFriendFriends: "Friends",
            .addFriendSent: "Friend request sent!",
            .addFriendAlreadyFriends: "You're already friends",
            .addFriendIncoming: "They already sent you a request — check New Friends",
            .addFriendError: "Something went wrong. Please try again.",
            .friendAcceptedTitle: "New Friend",
            .friendAcceptedMessage: "accepted your friend request",
            .friendRequestAccept: "Accept", .friendRequestDecline: "Decline",
            .friendRequestMessage: "Hello! I'd like to add you as a friend.",
            .friendRequestAdded: "Friend added!", .friendRequestDeclined: "Declined",
            .friendRequestError: "Couldn't complete. Please try again.",
            .contactDetailFollowers: "Followers", .contactDetailPlatform: "Platform",
            .contactDetailStatus: "Status", .contactDetailOnline: "Online", .contactDetailAway: "Away",
            .contactDetailMessage: "Message", .contactDetailDetails: "Details",
            .contactDetailHandle: "Handle", .contactDetailRole: "Role", .contactDetailAudience: "Audience",
            .contactDetailRemoveFriend: "Delete Friend",
            .contactDetailRemoveFriendMsg: "You'll both be removed from each other's contacts. This can't be undone.",
            .contactDetailRemoveFriendError: "Couldn't remove this friend. Please try again.",
            .createGroupTitle: "New Group Chat", .createGroupSelect: "Select Members",
            .createGroupCreate: "Create Group", .createGroupSearch: "Search contacts…",
            .createGroupSelected: "selected",
            .createGroupNamePlaceholder: "Group name (optional)",
            .createGroupNoFriends: "No friends yet",
            .createGroupNoFriendsHint: "Add some friends first, then start a group",
            .createGroupError: "Couldn't create the group. Please try again.",
            .discoverTitle: "Discover", .discoverSubtitle: "Brands & campaigns for your roster",
            .discoverFeatured: "FEATURED", .discoverViewBrief: "View brief", .discoverTopBrands: "Top Brands",
            .discoverOpenCampaigns: "Open Campaigns", .discoverActive: "active",
            .discoverDue: "Due", .discoverSpotsLeft: "spots left",
            .filterAll: "All", .filterBeauty: "Beauty", .filterFashion: "Fashion", .filterWellness: "Wellness", .filterTech: "Tech",
            .campaignDetailBudget: "Budget", .campaignDetailDeadline: "Deadline",
            .campaignDetailSpots: "Spots", .campaignDetailApply: "Apply now", .campaignDetailApplied: "Applied ✓",
            .campaignDetailAbout: "About this campaign", .campaignDetailDeliverables: "Deliverables",
            .campaignDetailEstimatedPayout: "Estimated payout",
            .editProfileTitle: "Edit Profile", .editProfileName: "Full Name",
            .editProfileBio: "Bio", .editProfileLocation: "Location", .editProfileSave: "Save Changes",
            .editProfileLocationPlaceholder: "Tap the pin to auto-locate", .editProfileAutoLocate: "Auto-locate", .editProfileLocating: "Locating…",
            .editProfileChangePhoto: "Change Photo", .editProfilePhotoUpdated: "Photo updated!",
            .privacyTitle: "Privacy & Security",
            .privacyBlockedAccounts: "Blocked Accounts", .privacyBlockedAccountsSub: "Manage accounts you've blocked",
            .privacyVisibility: "Profile Visibility", .privacyVisibilitySub: "Control who can see your profile",
            .privacyActivityStatus: "Activity Status", .privacyActivityStatusSub: "Show when you're active",
            .privacyDataSharing: "Discoverable", .privacyDataSharingSub: "Appear in the Top Talent directory",
            .profileEdit: "Edit Profile", .profileReach: "Reach", .profileEngagement: "Engagement", .profileDeals: "Deals closed",
            .profileOpenDeals: "Open to new deals", .profileOpenDealsSub: "Brands can see you're available",
            .profilePreferences: "Preferences", .profileNotifications: "Push Notifications",
            .profilePrivacy: "Privacy & Security", .profileLanguage: "Language",
            .profileSupport: "Support", .profileHelp: "Help & FAQ", .profileContact: "Contact Support", .profileRate: "Rate the App",
            .faqTitle: "Help & FAQ",
            .supportFormTitle: "Contact Support",
            .supportSubjectField: "Subject",
            .supportMessageField: "How can we help?",
            .supportSendButton: "Send",
            .supportSentMsg: "Thanks — we got your message and will get back to you by email.",
            .supportErrorMsg: "Couldn't send your message. Please try again.",
            .supportEmptyMsg: "Please add a subject and a message.",
            .profileSignOut: "Sign Out",
            .settingsTitle: "Settings", .settingsLanguage: "Language",
            .settingsLanguageFooter: "Choose your preferred language. It applies across the whole app.",
            .settingsDone: "Done",
            .settingsAppearance: "Appearance", .settingsAppearanceFooter: "Switch between light and dark mode.",
            .themeSystem: "System", .themeLight: "Light", .themeDark: "Dark",
            .authTagline: "Where creators and brands connect",
            .authEmailPlaceholder: "Email",
            .authPasswordPlaceholder: "Password",
            .authConfirmPasswordPlaceholder: "Confirm Password",
            .authPasswordMismatch: "Passwords do not match",
            .authSignUpButton: "Create Account",
            .authSignInButton: "Sign In",
            .authNoAccount: "Don't have an account? Sign up",
            .authHaveAccount: "Already have an account? Sign in",
            .authVerificationSentTitle: "Link Sent",
            .authVerificationSentMessage: "A verification link has been sent to your email. Please check your inbox and tap the link to activate your account.",
            .authVerificationSentOk: "OK",
            .authVerifyTitle: "Verify your email",
            .authVerifySubtitle: "Enter the 6-digit code we sent to",
            .authVerifyButton: "Verify",
            .authResendCode: "Resend code",
            .authResendIn: "Resend in",
            .authChangeEmail: "Change email",
            .authCodeResent: "A new code has been sent",
            .authInviteOnly: "Invite only — ask your admin for access",
            .authForgotPassword: "Forgot password?",
            .authResetSentTitle: "Reset Link Sent",
            .authResetSentMessage: "If an account exists for that email, we've sent a password reset link. Please check your inbox.",
            .authErrInvalidEmail: "Enter a valid email address",
            .authErrPasswordShort: "Password must be at least 8 characters",
            .authErrPasswordRequired: "Enter your password",
            .authErrRateLimit: "Too many attempts. Please wait about a minute and try again.",
            .authErrGeneric: "Something went wrong. Please try again.",
            .authCheckEmailTitle: "Check your email",
            .authCheckEmailMessage: "We sent a confirmation link to",
            .authBackToSignIn: "Back to sign in",
            .setPwSuccess: "Your password has been updated. Please sign in with your new password.",
            .forcePwTitle: "Set a new password",
            .forcePwSubtitle: "For your security, please replace the initial password before continuing.",
            .forcePwSubtitleOptional: "Choose a new password for your account.",
            .forcePwNew: "New password",
            .forcePwConfirm: "Confirm new password",
            .forcePwSave: "Save & Continue",
            .forcePwTooShort: "Password must be at least 8 characters",
            .forcePwSameAsInitial: "Please pick a password different from the initial one",
            .forcePwChangePassword: "Change Password",
            .adminTitle: "Backend Management",
            .adminBadge: "ADMIN",
            .adminAllUsers: "All Users",
            .adminDeactivate: "Deactivate",
            .adminDelete: "Delete",
            .adminDeactivateConfirm: "Deactivate this user? They won't be able to sign in.",
            .adminDeleteConfirm: "Permanently delete this user? This cannot be undone.",
            .adminCancel: "Cancel",
            .adminNoUsers: "No users found",
            .adminStatusActive: "Active",
            .adminStatusDeactivated: "Deactivated",
            .adminInvite: "Invite a User",
            .adminInviteTitle: "Invite a new user",
            .adminInviteSubtitle: "Enter their email — we'll send an activation link. The initial password is 11111111.",
            .adminInviteEmailPlaceholder: "User's email",
            .adminInviteSend: "Send Invite",
            .adminInviteSent: "Invite sent! Ask them to check their inbox.",
            .adminInviteErrInvalid: "That email doesn't look right",
            .adminInviteErrExists: "That email is already registered",
            .adminInviteErrEmail: "Email service isn't configured yet — contact the developer",
            .adminInviteErrSend: "Couldn't send the email — the sender domain or address was rejected. Please try again.",
            .adminInviteErrGeneric: "Couldn't send the invite. Please try again.",
            .reportTitle: "Report",
            .reportSubtitle: "Tell us what's wrong. Reports are confidential and reviewed within 24 hours.",
            .reportReasonSpam: "Spam or scam",
            .reportReasonHarass: "Harassment or bullying",
            .reportReasonHate: "Hate speech or symbols",
            .reportReasonSexual: "Nudity or sexual content",
            .reportReasonViolence: "Violence or threats",
            .reportReasonOther: "Something else",
            .reportSubmit: "Submit Report",
            .reportThanksTitle: "Report received",
            .reportThanksMessage: "Thanks for helping keep Wefluens Connect safe. Our team reviews every report within 24 hours and removes content or removes users that violate our guidelines.",
            .reportAlsoBlock: "Also block this user",
            .reportError: "Couldn't submit your report. Please try again.",
            .blockAction: "Block",
            .blockConfirm: "Block this user? They won't be able to contact you, and you won't see their content.",
            .blockError: "Couldn't block this user. Please try again.",
            .unblockAction: "Unblock",
            .unblockConfirm: "Unblock this user? They'll be able to contact you again.",
            .blockedEmptyTitle: "No blocked accounts",
            .blockedEmptySub: "People you block can't contact you or see your content. They'll appear here.",
            .legalTerms: "Terms of Use",
            .legalGuidelines: "Community Guidelines",
            .legalSafety: "Safety & Terms",
            .authAgreePrefix: "I agree to Wefluens Connect's",
            .favoritesTitle: "Favorites",
            .favoriteAction: "Favorite",
            .favoritesEmpty: "No favorites yet",
            .pinMessage: "Pin",
            .unpinMessage: "Unpin",
            .pinnedLabel: "Pinned",
            .profileDeleteAccount: "Delete Account",
            .profileDeleteMessage: "This permanently deletes your account and all your data. This can't be undone.",
            .profileDeleteConfirm: "Delete",
            .profileAbout: "About",
            .aboutTitle: "About",
            .aboutVersion: "Version",
            .chatsAddFriend: "Add Friend",
            .chatsScan: "Scan",
            .chatSelect: "Select", .chatSelectedLabel: "Selected",
        ],
        .chinese: [
            .tabChats: "聊天", .tabContacts: "通讯录", .tabDiscover: "发现", .tabMe: "我",
            .chatsTitle: "聊天", .chatsUnread: "条未读消息", .chatsCaughtUp: "消息已全部读完",
            .chatsSearch: "搜索聊天", .chatsPinned: "置顶", .chatsMessages: "消息",
            .chatsEmpty: "未找到聊天", .chatsNewGroup: "发起群聊",
            .convPin: "置顶", .convUnpin: "取消置顶", .convMute: "消息免打扰",
            .convUnmute: "取消免打扰", .convDelete: "删除该聊天",
            .chatDetailActiveNow: "在线", .chatDetailOffline: "离线",
            .chatDetailToday: "今天", .chatDetailMessagePlaceholder: "输入消息…",
            .chatDetailGroupMembers: "人",
            .chatYouPrefix: "你：",
            .chatThreadEmpty: "打个招呼吧 👋",
            .chatStartError: "无法打开聊天，请重试。",
            .chatSendError: "发送失败，请重试。",
            .chatImagePreview: "[图片]",
            .chatFilePreview: "[文件]",
            .chatAttachPhoto: "照片",
            .chatAttachFile: "文件",
            .chatFileTooLarge: "文件过大（最大 25 MB）。",
            .chatFileError: "无法添加该文件，请重试。",
            .chatVoice: "[语音]",
            .chatHoldToTalk: "按住说话",
            .chatRecording: "正在录音…松开发送",
            .chatVoicePermissionDenied: "麦克风权限已关闭。请在设置中开启后再发送语音消息。",
            .chatRead: "已读",
            .chatDelivered: "已送达",
            .chatReply: "回复",
            .chatCopy: "复制",
            .chatYou: "你",
            .chatVideoPreview: "[视频]",
            .chatForward: "转发",
            .chatDelete: "删除",
            .chatRecall: "撤回",
            .chatRecallFailed: "撤回失败。你可能不是发送者，或已超过2分钟时限。",
            .chatRecallExpired: "已超过2分钟，无法撤回。",
            .chatRecallAlreadyRecalled: "这条消息已被撤回。",
            .chatRecallForbidden: "你只能撤回自己发送的消息。",
            .chatRecallError: "撤回失败，请重试。",
            .chatClearHistory: "清空聊天记录",
            .chatDeleteConversation: "删除此会话？仅对你移除。",
            .chatClearHistoryConfirm: "确定清空全部聊天记录？此操作仅对你生效，其他人不受影响。",
            .chatMessageRecalled: "消息已撤回",
            .forwardTitle: "转发到…",
            .forwardSend: "发送",
            .forwardFriends: "好友",
            .forwardGroups: "群聊",
            .forwardSearch: "搜索…",
            .forwardNoTargets: "暂无可转发的会话",
            .forwardError: "转发失败，请重试。",
            .groupSettingsTitle: "群聊信息",
            .groupSettingsMembers: "群成员",
            .groupSettingsAddMembers: "添加成员",
            .groupSettingsName: "群聊名称",
            .groupSettingsNamePlaceholder: "群聊名称",
            .groupSettingsSave: "保存",
            .groupSettingsOwner: "群主",
            .groupSettingsRemove: "移除",
            .groupSettingsRemoveConfirm: "将该成员移出群聊？",
            .groupSettingsRenameError: "群聊重命名失败，请重试。",
            .groupSettingsAddError: "添加成员失败，请重试。",
            .groupSettingsRemoveError: "移除成员失败，请重试。",
            .groupSettingsNoFriendsToAdd: "你的好友都已在群里了",
            .groupSettingsChangePhoto: "更换群头像",
            .groupSettingsMute: "消息免打扰",
            .groupSettingsLeave: "退出群聊",
            .groupSettingsLeaveConfirm: "确定退出该群聊？退出后将不再接收群消息。",
            .groupSettingsDissolve: "解散群聊",
            .groupSettingsDissolveConfirm: "确定解散该群聊？群聊将对所有人永久删除，此操作不可撤销。",
            .contactsTitle: "通讯录", .contactsSubtitle: "位创作者与合作伙伴", .contactsSearch: "搜索联系人",
            .contactsInvite: "邀请", .contactsTopTalent: "顶尖网红", .contactsBrands: "品牌",
            .contactsNewFriends: "新的朋友", .contactsFriendRequests: "好友申请",
            .contactsAddFriend: "添加好友",
            .talentEmpty: "暂时还没有创作者。",
            .brandsEmpty: "暂时没有可用的品牌。",
            .brandsNoCampaigns: "该品牌目前没有开放的活动。",
            .brandsSearch: "搜索品牌",
            .brandsNoMatches: "没有匹配的品牌。",
            .talentSearch: "搜索创作者",
            .talentOptInHint: "在「隐私与安全」中开启「可被发现」即可显示在此目录中。",
            .contactsRemark: "备注", .contactsSetRemark: "设置备注",
            .addFriendSearchPlaceholder: "搜索邮箱或用户名",
            .addFriendHint: "通过邮箱或用户名找到对方，然后发送好友申请。",
            .addFriendNoResults: "未找到用户",
            .addFriendSearching: "搜索中…",
            .addFriendAdd: "添加",
            .addFriendRequested: "已申请",
            .addFriendFriends: "已是好友",
            .addFriendSent: "好友申请已发送！",
            .addFriendAlreadyFriends: "你们已经是好友了",
            .addFriendIncoming: "对方已向你发送申请，请在「新的朋友」中处理",
            .addFriendError: "出错了，请重试。",
            .friendAcceptedTitle: "新好友",
            .friendAcceptedMessage: "通过了你的好友申请",
            .friendRequestAccept: "接受", .friendRequestDecline: "拒绝",
            .friendRequestMessage: "你好！我想加你为好友。",
            .friendRequestAdded: "已添加好友！", .friendRequestDeclined: "已拒绝",
            .friendRequestError: "操作失败，请重试。",
            .contactDetailFollowers: "粉丝", .contactDetailPlatform: "平台",
            .contactDetailStatus: "状态", .contactDetailOnline: "在线", .contactDetailAway: "离开",
            .contactDetailMessage: "发消息", .contactDetailDetails: "详细资料",
            .contactDetailHandle: "账号", .contactDetailRole: "身份", .contactDetailAudience: "受众",
            .contactDetailRemoveFriend: "删除好友",
            .contactDetailRemoveFriendMsg: "你们将从彼此的通讯录中互相移除，此操作不可撤销。",
            .contactDetailRemoveFriendError: "删除好友失败，请重试。",
            .createGroupTitle: "发起群聊", .createGroupSelect: "选择成员",
            .createGroupCreate: "创建群聊", .createGroupSearch: "搜索联系人…",
            .createGroupSelected: "已选",
            .createGroupNamePlaceholder: "群聊名称（选填）",
            .createGroupNoFriends: "还没有好友",
            .createGroupNoFriendsHint: "先去添加好友，再发起群聊",
            .createGroupError: "创建群聊失败，请重试。",
            .discoverTitle: "发现", .discoverSubtitle: "为你的网红阵容精选品牌与活动",
            .discoverFeatured: "精选", .discoverViewBrief: "查看简介", .discoverTopBrands: "热门品牌",
            .discoverOpenCampaigns: "开放活动", .discoverActive: "个进行中",
            .discoverDue: "截止", .discoverSpotsLeft: "个名额",
            .filterAll: "全部", .filterBeauty: "美妆", .filterFashion: "时尚", .filterWellness: "健康", .filterTech: "科技",
            .campaignDetailBudget: "预算", .campaignDetailDeadline: "截止日",
            .campaignDetailSpots: "名额", .campaignDetailApply: "立即申请", .campaignDetailApplied: "已申请 ✓",
            .campaignDetailAbout: "活动简介", .campaignDetailDeliverables: "交付物",
            .campaignDetailEstimatedPayout: "预估报酬",
            .editProfileTitle: "编辑资料", .editProfileName: "姓名",
            .editProfileBio: "简介", .editProfileLocation: "所在地", .editProfileSave: "保存",
            .editProfileLocationPlaceholder: "点击定位图标自动获取", .editProfileAutoLocate: "自动定位", .editProfileLocating: "定位中…",
            .editProfileChangePhoto: "更换头像", .editProfilePhotoUpdated: "头像已更新！",
            .privacyTitle: "隐私与安全",
            .privacyBlockedAccounts: "已屏蔽账户", .privacyBlockedAccountsSub: "管理你屏蔽的账户",
            .privacyVisibility: "资料可见性", .privacyVisibilitySub: "控制谁可以查看你的资料",
            .privacyActivityStatus: "活动状态", .privacyActivityStatusSub: "显示你的在线状态",
            .privacyDataSharing: "可被发现", .privacyDataSharingSub: "在「顶尖网红」目录中显示",
            .profileEdit: "编辑资料", .profileReach: "触达", .profileEngagement: "互动率", .profileDeals: "已成交",
            .profileOpenDeals: "接受新合作", .profileOpenDealsSub: "品牌可以看到你的空档",
            .profilePreferences: "偏好设置", .profileNotifications: "推送通知",
            .profilePrivacy: "隐私与安全", .profileLanguage: "语言",
            .profileSupport: "支持", .profileHelp: "帮助与常见问题", .profileContact: "联系客服", .profileRate: "给应用评分",
            .faqTitle: "帮助与常见问题",
            .supportFormTitle: "联系客服",
            .supportSubjectField: "主题",
            .supportMessageField: "我们能帮您什么？",
            .supportSendButton: "发送",
            .supportSentMsg: "谢谢——我们已收到您的消息，会通过邮件回复您。",
            .supportErrorMsg: "消息发送失败，请重试。",
            .supportEmptyMsg: "请填写主题和消息内容。",
            .profileSignOut: "退出登录",
            .settingsTitle: "设置", .settingsLanguage: "语言",
            .settingsLanguageFooter: "选择你偏好的语言，将应用于整个 App。",
            .settingsDone: "完成",
            .settingsAppearance: "外观", .settingsAppearanceFooter: "在浅色与深色模式之间切换。",
            .themeSystem: "跟随本机", .themeLight: "浅色", .themeDark: "深色",
            .authTagline: "创作者与品牌的连接之地",
            .authEmailPlaceholder: "邮箱",
            .authPasswordPlaceholder: "密码",
            .authConfirmPasswordPlaceholder: "确认密码",
            .authPasswordMismatch: "两次密码不一致",
            .authSignUpButton: "创建账号",
            .authSignInButton: "登录",
            .authNoAccount: "还没有账号？注册",
            .authHaveAccount: "已有账号？登录",
            .authVerificationSentTitle: "链接已发送",
            .authVerificationSentMessage: "验证链接已发送到你的邮箱。请查看收件箱并点击链接来激活你的账号。",
            .authVerificationSentOk: "好的",
            .authVerifyTitle: "验证你的邮箱",
            .authVerifySubtitle: "请输入我们发送到以下邮箱的 6 位验证码",
            .authVerifyButton: "验证",
            .authResendCode: "重新发送验证码",
            .authResendIn: "重新发送",
            .authChangeEmail: "更换邮箱",
            .authCodeResent: "新验证码已发送",
            .authInviteOnly: "仅限受邀用户 · 如需账号请联系管理员",
            .authErrRateLimit: "尝试次数过多，请等待约一分钟后再试。",
            .authErrGeneric: "出错了，请重试。",
            .authForgotPassword: "忘记密码？",
            .authResetSentTitle: "重置链接已发送",
            .authResetSentMessage: "如果该邮箱存在账号，我们已发送密码重置链接，请查收邮件。",
            .authErrInvalidEmail: "请输入有效的邮箱地址",
            .authErrPasswordShort: "密码至少需要 8 位",
            .authErrPasswordRequired: "请输入密码",
            .authCheckEmailTitle: "查看你的邮箱",
            .authCheckEmailMessage: "我们已发送确认链接至",
            .authBackToSignIn: "返回登录",
            .setPwSuccess: "密码已更新，请使用新密码登录。",
            .forcePwTitle: "设置新密码",
            .forcePwSubtitle: "为了账号安全，请先修改初始密码再继续使用。",
            .forcePwSubtitleOptional: "为你的账号设置一个新密码。",
            .forcePwNew: "新密码",
            .forcePwConfirm: "确认新密码",
            .forcePwSave: "保存并进入",
            .forcePwTooShort: "密码至少需要 8 位",
            .forcePwSameAsInitial: "新密码不能与初始密码相同",
            .forcePwChangePassword: "修改密码",
            .adminTitle: "后端管理",
            .adminBadge: "管理员",
            .adminAllUsers: "全部用户",
            .adminDeactivate: "注销",
            .adminDelete: "删除",
            .adminDeactivateConfirm: "确定要注销此用户吗？他们将无法登录。",
            .adminDeleteConfirm: "确定要永久删除此用户吗？此操作不可撤销。",
            .adminCancel: "取消",
            .adminNoUsers: "暂无用户",
            .adminStatusActive: "正常",
            .adminStatusDeactivated: "已注销",
            .adminInvite: "邀请用户",
            .adminInviteTitle: "邀请新用户",
            .adminInviteSubtitle: "输入对方邮箱，我们会发送注册激活链接。初始密码为 11111111。",
            .adminInviteEmailPlaceholder: "用户邮箱",
            .adminInviteSend: "发送邀请",
            .adminInviteSent: "邀请已发送！请提醒对方查收邮件。",
            .adminInviteErrInvalid: "邮箱格式不正确",
            .adminInviteErrExists: "该邮箱已注册",
            .adminInviteErrEmail: "邮件服务尚未配置，请联系开发者",
            .adminInviteErrSend: "邮件发送失败（发件域名或地址被拒），请稍后重试",
            .adminInviteErrGeneric: "邀请发送失败，请重试。",
            .reportTitle: "举报",
            .reportSubtitle: "请告诉我们问题所在。举报内容将保密，并在 24 小时内处理。",
            .reportReasonSpam: "垃圾信息或诈骗",
            .reportReasonHarass: "骚扰或欺凌",
            .reportReasonHate: "仇恨言论或标志",
            .reportReasonSexual: "裸露或色情内容",
            .reportReasonViolence: "暴力或威胁",
            .reportReasonOther: "其他问题",
            .reportSubmit: "提交举报",
            .reportThanksTitle: "举报已收到",
            .reportThanksMessage: "感谢你帮助维护 Wefluens Connect 的安全。我们会在 24 小时内审核每一条举报，并移除违反社区准则的内容或用户。",
            .reportAlsoBlock: "同时屏蔽该用户",
            .reportError: "举报提交失败，请重试。",
            .blockAction: "屏蔽",
            .blockConfirm: "确定屏蔽该用户？对方将无法联系你，你也不会再看到其内容。",
            .blockError: "屏蔽失败，请重试。",
            .unblockAction: "解除屏蔽",
            .unblockConfirm: "解除屏蔽该用户？对方将可以再次联系你。",
            .blockedEmptyTitle: "暂无屏蔽账户",
            .blockedEmptySub: "被你屏蔽的用户将无法联系你或查看你的内容，并会显示在这里。",
            .legalTerms: "使用条款",
            .legalGuidelines: "社区准则",
            .legalSafety: "安全与条款",
            .authAgreePrefix: "我同意 Wefluens Connect 的",
            .favoritesTitle: "收藏",
            .favoriteAction: "收藏",
            .favoritesEmpty: "还没有收藏",
            .pinMessage: "置顶",
            .unpinMessage: "取消置顶",
            .pinnedLabel: "群公告",
            .profileDeleteAccount: "删除账号",
            .profileDeleteMessage: "这将永久删除你的账号和所有数据,无法恢复。",
            .profileDeleteConfirm: "删除",
            .profileAbout: "关于",
            .aboutTitle: "关于",
            .aboutVersion: "版本",
            .chatsAddFriend: "添加好友",
            .chatsScan: "扫一扫",
            .chatSelect: "多选", .chatSelectedLabel: "已选",
        ],
        .spanish: [
            .tabChats: "Chats", .tabContacts: "Contactos", .tabDiscover: "Descubrir", .tabMe: "Yo",
            .chatsTitle: "Chats", .chatsUnread: "mensajes sin leer", .chatsCaughtUp: "Estás al día",
            .chatsSearch: "Buscar conversaciones", .chatsPinned: "Fijados", .chatsMessages: "Mensajes",
            .chatsEmpty: "No se encontraron conversaciones", .chatsNewGroup: "Nuevo Grupo",
            .convPin: "Fijar arriba", .convUnpin: "Quitar fijado", .convMute: "Silenciar",
            .convUnmute: "Reactivar", .convDelete: "Eliminar chat",
            .chatDetailActiveNow: "Activo ahora", .chatDetailOffline: "Desconectado",
            .chatDetailToday: "Hoy", .chatDetailMessagePlaceholder: "Mensaje…",
            .chatDetailGroupMembers: "miembros",
            .chatYouPrefix: "Tú: ",
            .chatThreadEmpty: "Saluda 👋",
            .chatStartError: "No se pudo abrir el chat. Inténtalo de nuevo.",
            .chatSendError: "No se pudo enviar. Inténtalo de nuevo.",
            .chatImagePreview: "[Foto]",
            .chatFilePreview: "[Archivo]",
            .chatAttachPhoto: "Foto",
            .chatAttachFile: "Archivo",
            .chatFileTooLarge: "Archivo demasiado grande (máx. 25 MB).",
            .chatFileError: "No se pudo adjuntar el archivo. Inténtalo de nuevo.",
            .chatVoice: "[Voz]",
            .chatHoldToTalk: "Mantén para hablar",
            .chatRecording: "Grabando… suelta para enviar",
            .chatVoicePermissionDenied: "El acceso al micrófono está desactivado. Actívalo en Ajustes para enviar mensajes de voz.",
            .chatRead: "Leído",
            .chatDelivered: "Entregado",
            .chatReply: "Responder",
            .chatCopy: "Copiar",
            .chatYou: "Tú",
            .chatVideoPreview: "[Video]",
            .chatForward: "Reenviar",
            .chatDelete: "Eliminar",
            .chatRecall: "Retirar",
            .chatRecallFailed: "No se pudo retirar. Es posible que no seas el remitente o que hayan pasado más de 2 minutos.",
            .chatRecallExpired: "La ventana de 2 minutos para retirar ha expirado.",
            .chatRecallAlreadyRecalled: "Este mensaje ya ha sido retirado.",
            .chatRecallForbidden: "Solo puedes retirar tus propios mensajes.",
            .chatRecallError: "No se pudo retirar. Inténtalo de nuevo.",
            .chatClearHistory: "Vaciar historial",
            .chatDeleteConversation: "¿Eliminar esta conversación? Solo se quitará para ti.",
            .chatClearHistoryConfirm: "¿Vaciar todo el historial del chat? Solo te afecta a ti; los demás conservan sus mensajes.",
            .chatMessageRecalled: "Mensaje retirado",
            .forwardTitle: "Reenviar a…",
            .forwardSend: "Enviar",
            .forwardFriends: "Amigos",
            .forwardGroups: "Grupos",
            .forwardSearch: "Buscar…",
            .forwardNoTargets: "No hay conversaciones disponibles",
            .forwardError: "No se pudo reenviar. Inténtalo de nuevo.",
            .groupSettingsTitle: "Información del grupo",
            .groupSettingsMembers: "Miembros",
            .groupSettingsAddMembers: "Agregar miembros",
            .groupSettingsName: "Nombre del grupo",
            .groupSettingsNamePlaceholder: "Nombre del grupo",
            .groupSettingsSave: "Guardar",
            .groupSettingsOwner: "Propietario",
            .groupSettingsRemove: "Eliminar",
            .groupSettingsRemoveConfirm: "¿Eliminar a este miembro del grupo?",
            .groupSettingsRenameError: "No se pudo renombrar el grupo. Inténtalo de nuevo.",
            .groupSettingsAddError: "No se pudieron agregar miembros. Inténtalo de nuevo.",
            .groupSettingsRemoveError: "No se pudo eliminar a este miembro. Inténtalo de nuevo.",
            .groupSettingsNoFriendsToAdd: "Todos tus amigos ya están en este grupo",
            .groupSettingsChangePhoto: "Cambiar foto del grupo",
            .groupSettingsMute: "Silenciar notificaciones",
            .groupSettingsLeave: "Salir del grupo",
            .groupSettingsLeaveConfirm: "¿Salir de este grupo? Dejarás de recibir sus mensajes.",
            .groupSettingsDissolve: "Disolver grupo",
            .groupSettingsDissolveConfirm: "¿Disolver este grupo? Se eliminará permanentemente para todos. No se puede deshacer.",
            .contactsTitle: "Contactos", .contactsSubtitle: "creadores y socios", .contactsSearch: "Buscar contactos",
            .contactsInvite: "Invitar", .contactsTopTalent: "Top Talento", .contactsBrands: "Marcas",
            .contactsNewFriends: "Nuevos Amigos", .contactsFriendRequests: "Solicitud de Amistad",
            .contactsAddFriend: "Agregar amigo",
            .talentEmpty: "Todavía no hay creadores aquí.",
            .brandsEmpty: "Todavía no hay marcas disponibles.",
            .brandsNoCampaigns: "Esta marca no tiene campañas abiertas por ahora.",
            .brandsSearch: "Buscar marcas",
            .brandsNoMatches: "Ninguna marca coincide con tu búsqueda.",
            .talentSearch: "Buscar creadores",
            .talentOptInHint: "Activa «Visible» en Privacidad y seguridad para aparecer en este directorio.",
            .contactsRemark: "Nota", .contactsSetRemark: "Poner nota",
            .addFriendSearchPlaceholder: "Busca por correo o @usuario",
            .addFriendHint: "Encuentra personas por su correo o usuario y envía una solicitud de amistad.",
            .addFriendNoResults: "No se encontraron usuarios",
            .addFriendSearching: "Buscando…",
            .addFriendAdd: "Agregar",
            .addFriendRequested: "Solicitado",
            .addFriendFriends: "Amigos",
            .addFriendSent: "¡Solicitud enviada!",
            .addFriendAlreadyFriends: "Ya son amigos",
            .addFriendIncoming: "Ya te envió una solicitud — revisa Nuevos Amigos",
            .addFriendError: "Algo salió mal. Inténtalo de nuevo.",
            .friendAcceptedTitle: "Nuevo amigo",
            .friendAcceptedMessage: "aceptó tu solicitud de amistad",
            .friendRequestAccept: "Aceptar", .friendRequestDecline: "Rechazar",
            .friendRequestMessage: "¡Hola! Me gustaría agregarte como amigo.",
            .friendRequestAdded: "¡Amigo agregado!", .friendRequestDeclined: "Rechazada",
            .friendRequestError: "No se pudo completar. Inténtalo de nuevo.",
            .contactDetailFollowers: "Seguidores", .contactDetailPlatform: "Plataforma",
            .contactDetailStatus: "Estado", .contactDetailOnline: "En línea", .contactDetailAway: "Ausente",
            .contactDetailMessage: "Mensaje", .contactDetailDetails: "Detalles",
            .contactDetailHandle: "Usuario", .contactDetailRole: "Rol", .contactDetailAudience: "Audiencia",
            .contactDetailRemoveFriend: "Eliminar amigo",
            .contactDetailRemoveFriendMsg: "Ambos se eliminarán de los contactos del otro. No se puede deshacer.",
            .contactDetailRemoveFriendError: "No se pudo eliminar. Inténtalo de nuevo.",
            .createGroupTitle: "Nuevo Grupo", .createGroupSelect: "Seleccionar Miembros",
            .createGroupCreate: "Crear Grupo", .createGroupSearch: "Buscar contactos…",
            .createGroupSelected: "seleccionados",
            .createGroupNamePlaceholder: "Nombre del grupo (opcional)",
            .createGroupNoFriends: "Aún no tienes amigos",
            .createGroupNoFriendsHint: "Agrega amigos primero para crear un grupo",
            .createGroupError: "No se pudo crear el grupo. Inténtalo de nuevo.",
            .discoverTitle: "Descubrir", .discoverSubtitle: "Marcas y campañas para tu roster",
            .discoverFeatured: "DESTACADO", .discoverViewBrief: "Ver brief", .discoverTopBrands: "Marcas Top",
            .discoverOpenCampaigns: "Campañas Abiertas", .discoverActive: "activas",
            .discoverDue: "Entrega", .discoverSpotsLeft: "cupos",
            .filterAll: "Todo", .filterBeauty: "Belleza", .filterFashion: "Moda", .filterWellness: "Bienestar", .filterTech: "Tecnología",
            .campaignDetailBudget: "Presupuesto", .campaignDetailDeadline: "Fecha límite",
            .campaignDetailSpots: "Cupos", .campaignDetailApply: "Aplicar", .campaignDetailApplied: "Aplicado ✓",
            .campaignDetailAbout: "Sobre esta campaña", .campaignDetailDeliverables: "Entregables",
            .campaignDetailEstimatedPayout: "Pago estimado",
            .editProfileTitle: "Editar Perfil", .editProfileName: "Nombre completo",
            .editProfileBio: "Bio", .editProfileLocation: "Ubicación", .editProfileSave: "Guardar Cambios",
            .editProfileLocationPlaceholder: "Toca el pin para auto-ubicar", .editProfileAutoLocate: "Auto-ubicar", .editProfileLocating: "Ubicando…",
            .editProfileChangePhoto: "Cambiar Foto", .editProfilePhotoUpdated: "¡Foto actualizada!",
            .privacyTitle: "Privacidad y Seguridad",
            .privacyBlockedAccounts: "Cuentas Bloqueadas", .privacyBlockedAccountsSub: "Gestionar cuentas bloqueadas",
            .privacyVisibility: "Visibilidad del Perfil", .privacyVisibilitySub: "Controlar quién ve tu perfil",
            .privacyActivityStatus: "Estado de Actividad", .privacyActivityStatusSub: "Mostrar cuando estás activo",
            .privacyDataSharing: "Visible", .privacyDataSharingSub: "Aparecer en el directorio Top Talento",
            .profileEdit: "Editar Perfil", .profileReach: "Alcance", .profileEngagement: "Interacción", .profileDeals: "Tratos cerrados",
            .profileOpenDeals: "Abierto a nuevos tratos", .profileOpenDealsSub: "Las marcas ven que estás disponible",
            .profilePreferences: "Preferencias", .profileNotifications: "Notificaciones",
            .profilePrivacy: "Privacidad y Seguridad", .profileLanguage: "Idioma",
            .profileSupport: "Soporte", .profileHelp: "Ayuda y FAQ", .profileContact: "Contactar soporte", .profileRate: "Valorar la App",
            .faqTitle: "Ayuda y FAQ",
            .supportFormTitle: "Contactar soporte",
            .supportSubjectField: "Asunto",
            .supportMessageField: "¿Cómo podemos ayudarte?",
            .supportSendButton: "Enviar",
            .supportSentMsg: "Gracias: recibimos tu mensaje y te responderemos por correo.",
            .supportErrorMsg: "No se pudo enviar tu mensaje. Inténtalo de nuevo.",
            .supportEmptyMsg: "Añade un asunto y un mensaje.",
            .profileSignOut: "Cerrar Sesión",
            .settingsTitle: "Ajustes", .settingsLanguage: "Idioma",
            .settingsLanguageFooter: "Elige tu idioma preferido. Se aplica en toda la app.",
            .settingsDone: "Hecho",
            .settingsAppearance: "Apariencia", .settingsAppearanceFooter: "Cambia entre modo claro y oscuro.",
            .themeSystem: "Sistema", .themeLight: "Claro", .themeDark: "Oscuro",
            .authTagline: "Donde los creadores y las marcas se conectan",
            .authEmailPlaceholder: "Correo",
            .authPasswordPlaceholder: "Contraseña",
            .authConfirmPasswordPlaceholder: "Confirmar Contraseña",
            .authPasswordMismatch: "Las contraseñas no coinciden",
            .authSignUpButton: "Crear Cuenta",
            .authSignInButton: "Iniciar Sesión",
            .authNoAccount: "¿No tienes cuenta? Regístrate",
            .authHaveAccount: "¿Ya tienes cuenta? Inicia sesión",
            .authVerificationSentTitle: "Enlace Enviado",
            .authVerificationSentMessage: "Se ha enviado un enlace de verificación a tu correo. Revisa tu bandeja de entrada y haz clic en el enlace para activar tu cuenta.",
            .authVerificationSentOk: "OK",
            .authVerifyTitle: "Verifica tu correo",
            .authVerifySubtitle: "Ingresa el código de 6 dígitos que enviamos a",
            .authVerifyButton: "Verificar",
            .authResendCode: "Reenviar código",
            .authResendIn: "Reenviar en",
            .authChangeEmail: "Cambiar correo",
            .authCodeResent: "Se ha enviado un nuevo código",
            .authInviteOnly: "Solo por invitación — pide acceso a tu administrador",
            .authErrRateLimit: "Demasiados intentos. Espera alrededor de un minuto e inténtalo de nuevo.",
            .authErrGeneric: "Algo salió mal. Inténtalo de nuevo.",
            .authForgotPassword: "¿Olvidaste tu contraseña?",
            .authResetSentTitle: "Enlace de restablecimiento enviado",
            .authResetSentMessage: "Si existe una cuenta con ese correo, hemos enviado un enlace para restablecer la contraseña. Revisa tu bandeja de entrada.",
            .authErrInvalidEmail: "Introduce un correo válido",
            .authErrPasswordShort: "La contraseña debe tener al menos 8 caracteres",
            .authErrPasswordRequired: "Introduce tu contraseña",
            .authCheckEmailTitle: "Revisa tu correo",
            .authCheckEmailMessage: "Enviamos un enlace de confirmación a",
            .authBackToSignIn: "Volver a iniciar sesión",
            .setPwSuccess: "Tu contraseña se ha actualizado. Inicia sesión con tu nueva contraseña.",
            .forcePwTitle: "Establece una nueva contraseña",
            .forcePwSubtitle: "Por tu seguridad, cambia la contraseña inicial antes de continuar.",
            .forcePwSubtitleOptional: "Elige una nueva contraseña para tu cuenta.",
            .forcePwNew: "Nueva contraseña",
            .forcePwConfirm: "Confirmar nueva contraseña",
            .forcePwSave: "Guardar y Continuar",
            .forcePwTooShort: "La contraseña debe tener al menos 8 caracteres",
            .forcePwSameAsInitial: "Elige una contraseña distinta de la inicial",
            .forcePwChangePassword: "Cambiar Contraseña",
            .adminTitle: "Gestión de Backend",
            .adminBadge: "ADMIN",
            .adminAllUsers: "Todos los Usuarios",
            .adminDeactivate: "Desactivar",
            .adminDelete: "Eliminar",
            .adminDeactivateConfirm: "¿Desactivar este usuario? No podrá iniciar sesión.",
            .adminDeleteConfirm: "¿Eliminar permanentemente este usuario? No se puede deshacer.",
            .adminCancel: "Cancelar",
            .adminNoUsers: "No se encontraron usuarios",
            .adminStatusActive: "Activo",
            .adminStatusDeactivated: "Desactivado",
            .adminInvite: "Invitar a un Usuario",
            .adminInviteTitle: "Invitar a un nuevo usuario",
            .adminInviteSubtitle: "Ingresa su correo — enviaremos un enlace de activación. La contraseña inicial es 11111111.",
            .adminInviteEmailPlaceholder: "Correo del usuario",
            .adminInviteSend: "Enviar Invitación",
            .adminInviteSent: "¡Invitación enviada! Pídele que revise su correo.",
            .adminInviteErrInvalid: "Ese correo no parece válido",
            .adminInviteErrExists: "Ese correo ya está registrado",
            .adminInviteErrEmail: "El servicio de correo no está configurado — contacta al desarrollador",
            .adminInviteErrSend: "No se pudo enviar el correo (dominio o dirección del remitente rechazada). Inténtalo de nuevo.",
            .adminInviteErrGeneric: "No se pudo enviar la invitación. Inténtalo de nuevo.",
            .reportTitle: "Reportar",
            .reportSubtitle: "Cuéntanos qué ocurre. Los reportes son confidenciales y se revisan en 24 horas.",
            .reportReasonSpam: "Spam o estafa",
            .reportReasonHarass: "Acoso o intimidación",
            .reportReasonHate: "Discurso o símbolos de odio",
            .reportReasonSexual: "Desnudez o contenido sexual",
            .reportReasonViolence: "Violencia o amenazas",
            .reportReasonOther: "Otro motivo",
            .reportSubmit: "Enviar reporte",
            .reportThanksTitle: "Reporte recibido",
            .reportThanksMessage: "Gracias por ayudar a mantener seguro Wefluens Connect. Revisamos cada reporte en un plazo de 24 horas y eliminamos el contenido o los usuarios que infrinjan nuestras normas.",
            .reportAlsoBlock: "También bloquear a este usuario",
            .reportError: "No se pudo enviar tu reporte. Inténtalo de nuevo.",
            .blockAction: "Bloquear",
            .blockConfirm: "¿Bloquear a este usuario? No podrá contactarte y no verás su contenido.",
            .blockError: "No se pudo bloquear a este usuario. Inténtalo de nuevo.",
            .unblockAction: "Desbloquear",
            .unblockConfirm: "¿Desbloquear a este usuario? Podrá contactarte de nuevo.",
            .blockedEmptyTitle: "Sin cuentas bloqueadas",
            .blockedEmptySub: "Las personas que bloquees no podrán contactarte ni ver tu contenido. Aparecerán aquí.",
            .legalTerms: "Términos de Uso",
            .legalGuidelines: "Normas de la Comunidad",
            .legalSafety: "Seguridad y Términos",
            .authAgreePrefix: "Acepto los",
            .favoritesTitle: "Favoritos",
            .favoriteAction: "Guardar",
            .favoritesEmpty: "Sin favoritos",
            .pinMessage: "Fijar",
            .unpinMessage: "Quitar",
            .pinnedLabel: "Fijado",
            .profileDeleteAccount: "Eliminar cuenta",
            .profileDeleteMessage: "Esto elimina permanentemente tu cuenta y todos tus datos. No se puede deshacer.",
            .profileDeleteConfirm: "Eliminar",
            .profileAbout: "Acerca de",
            .aboutTitle: "Acerca de",
            .aboutVersion: "Versión",
            .chatsAddFriend: "Agregar amigo",
            .chatsScan: "Escanear",
            .chatSelect: "Seleccionar", .chatSelectedLabel: "Seleccionados",
        ],
    ]
}
