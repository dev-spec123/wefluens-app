//
//  Localization.swift
//  Wefluens
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

    // ChatDetail
    case chatDetailActiveNow, chatDetailOffline, chatDetailToday, chatDetailMessagePlaceholder
    case chatDetailGroupMembers
    case chatYouPrefix, chatThreadEmpty, chatStartError, chatSendError, chatImagePreview

    // Contacts
    case contactsTitle, contactsSubtitle, contactsSearch, contactsInvite, contactsTopTalent, contactsBrands
    case contactsNewFriends, contactsFriendRequests, contactsAddFriend

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
    case createGroupSelected

    // Discover
    case discoverTitle, discoverSubtitle, discoverFeatured, discoverViewBrief, discoverTopBrands, discoverOpenCampaigns, discoverActive
    case discoverDue, discoverSpotsLeft
    case filterAll, filterBeauty, filterFashion, filterWellness, filterTech

    // CampaignDetail
    case campaignDetailBudget, campaignDetailDeadline, campaignDetailSpots
    case campaignDetailApply, campaignDetailAbout, campaignDetailDeliverables
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

    // Settings
    case settingsTitle, settingsLanguage, settingsLanguageFooter, settingsDone
    case settingsAppearance, settingsAppearanceFooter

    // Theme
    case themeLight, themeDark

    // Auth
    case authTagline, authEmailPlaceholder, authPasswordPlaceholder
    case authConfirmPasswordPlaceholder, authPasswordMismatch
    case authSignUpButton, authSignInButton, authNoAccount, authHaveAccount
    case authVerificationSentTitle, authVerificationSentMessage, authVerificationSentOk
    case authVerifyTitle, authVerifySubtitle, authVerifyButton
    case authResendCode, authResendIn, authChangeEmail, authCodeResent
    case authInviteOnly

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
            .chatDetailActiveNow: "Active now", .chatDetailOffline: "Offline",
            .chatDetailToday: "Today", .chatDetailMessagePlaceholder: "Message…",
            .chatDetailGroupMembers: "members",
            .chatYouPrefix: "You: ",
            .chatThreadEmpty: "Say hello 👋",
            .chatStartError: "Couldn't open the chat. Please try again.",
            .chatSendError: "Couldn't send. Please try again.",
            .chatImagePreview: "[Photo]",
            .contactsTitle: "Contacts", .contactsSubtitle: "creators & partners", .contactsSearch: "Search contacts",
            .contactsInvite: "Invite", .contactsTopTalent: "Top Talent", .contactsBrands: "Brands",
            .contactsNewFriends: "New Friends", .contactsFriendRequests: "Friend Request",
            .contactsAddFriend: "Add Friend",
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
            .discoverTitle: "Discover", .discoverSubtitle: "Brands & campaigns for your roster",
            .discoverFeatured: "FEATURED", .discoverViewBrief: "View brief", .discoverTopBrands: "Top Brands",
            .discoverOpenCampaigns: "Open Campaigns", .discoverActive: "active",
            .discoverDue: "Due", .discoverSpotsLeft: "spots left",
            .filterAll: "All", .filterBeauty: "Beauty", .filterFashion: "Fashion", .filterWellness: "Wellness", .filterTech: "Tech",
            .campaignDetailBudget: "Budget", .campaignDetailDeadline: "Deadline",
            .campaignDetailSpots: "Spots", .campaignDetailApply: "Apply now",
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
            .privacyDataSharing: "Data Sharing", .privacyDataSharingSub: "Control how your data is used",
            .profileEdit: "Edit Profile", .profileReach: "Reach", .profileEngagement: "Engagement", .profileDeals: "Deals closed",
            .profileOpenDeals: "Open to new deals", .profileOpenDealsSub: "Brands can see you're available",
            .profilePreferences: "Preferences", .profileNotifications: "Push Notifications",
            .profilePrivacy: "Privacy & Security", .profileLanguage: "Language",
            .profileSupport: "Support", .profileHelp: "Help Center", .profileContact: "Contact Wefluens", .profileRate: "Rate the App",
            .profileSignOut: "Sign Out",
            .settingsTitle: "Settings", .settingsLanguage: "Language",
            .settingsLanguageFooter: "Choose your preferred language. It applies across the whole app.",
            .settingsDone: "Done",
            .settingsAppearance: "Appearance", .settingsAppearanceFooter: "Switch between light and dark mode.",
            .themeLight: "Light", .themeDark: "Dark",
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
        ],
        .chinese: [
            .tabChats: "聊天", .tabContacts: "通讯录", .tabDiscover: "发现", .tabMe: "我",
            .chatsTitle: "聊天", .chatsUnread: "条未读消息", .chatsCaughtUp: "消息已全部读完",
            .chatsSearch: "搜索聊天", .chatsPinned: "置顶", .chatsMessages: "消息",
            .chatsEmpty: "未找到聊天", .chatsNewGroup: "发起群聊",
            .chatDetailActiveNow: "在线", .chatDetailOffline: "离线",
            .chatDetailToday: "今天", .chatDetailMessagePlaceholder: "输入消息…",
            .chatDetailGroupMembers: "人",
            .chatYouPrefix: "你：",
            .chatThreadEmpty: "打个招呼吧 👋",
            .chatStartError: "无法打开聊天，请重试。",
            .chatSendError: "发送失败，请重试。",
            .chatImagePreview: "[图片]",
            .contactsTitle: "通讯录", .contactsSubtitle: "位创作者与合作伙伴", .contactsSearch: "搜索联系人",
            .contactsInvite: "邀请", .contactsTopTalent: "顶尖网红", .contactsBrands: "品牌",
            .contactsNewFriends: "新的朋友", .contactsFriendRequests: "好友申请",
            .contactsAddFriend: "添加好友",
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
            .discoverTitle: "发现", .discoverSubtitle: "为你的网红阵容精选品牌与活动",
            .discoverFeatured: "精选", .discoverViewBrief: "查看简介", .discoverTopBrands: "热门品牌",
            .discoverOpenCampaigns: "开放活动", .discoverActive: "个进行中",
            .discoverDue: "截止", .discoverSpotsLeft: "个名额",
            .filterAll: "全部", .filterBeauty: "美妆", .filterFashion: "时尚", .filterWellness: "健康", .filterTech: "科技",
            .campaignDetailBudget: "预算", .campaignDetailDeadline: "截止日",
            .campaignDetailSpots: "名额", .campaignDetailApply: "立即申请",
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
            .privacyDataSharing: "数据共享", .privacyDataSharingSub: "管理你的数据使用方式",
            .profileEdit: "编辑资料", .profileReach: "触达", .profileEngagement: "互动率", .profileDeals: "已成交",
            .profileOpenDeals: "接受新合作", .profileOpenDealsSub: "品牌可以看到你的空档",
            .profilePreferences: "偏好设置", .profileNotifications: "推送通知",
            .profilePrivacy: "隐私与安全", .profileLanguage: "语言",
            .profileSupport: "支持", .profileHelp: "帮助中心", .profileContact: "联系 Wefluens", .profileRate: "给应用评分",
            .profileSignOut: "退出登录",
            .settingsTitle: "设置", .settingsLanguage: "语言",
            .settingsLanguageFooter: "选择你偏好的语言，将应用于整个 App。",
            .settingsDone: "完成",
            .settingsAppearance: "外观", .settingsAppearanceFooter: "在浅色与深色模式之间切换。",
            .themeLight: "浅色", .themeDark: "深色",
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
        ],
        .spanish: [
            .tabChats: "Chats", .tabContacts: "Contactos", .tabDiscover: "Descubrir", .tabMe: "Yo",
            .chatsTitle: "Chats", .chatsUnread: "mensajes sin leer", .chatsCaughtUp: "Estás al día",
            .chatsSearch: "Buscar conversaciones", .chatsPinned: "Fijados", .chatsMessages: "Mensajes",
            .chatsEmpty: "No se encontraron conversaciones", .chatsNewGroup: "Nuevo Grupo",
            .chatDetailActiveNow: "Activo ahora", .chatDetailOffline: "Desconectado",
            .chatDetailToday: "Hoy", .chatDetailMessagePlaceholder: "Mensaje…",
            .chatDetailGroupMembers: "miembros",
            .chatYouPrefix: "Tú: ",
            .chatThreadEmpty: "Saluda 👋",
            .chatStartError: "No se pudo abrir el chat. Inténtalo de nuevo.",
            .chatSendError: "No se pudo enviar. Inténtalo de nuevo.",
            .chatImagePreview: "[Foto]",
            .contactsTitle: "Contactos", .contactsSubtitle: "creadores y socios", .contactsSearch: "Buscar contactos",
            .contactsInvite: "Invitar", .contactsTopTalent: "Top Talento", .contactsBrands: "Marcas",
            .contactsNewFriends: "Nuevos Amigos", .contactsFriendRequests: "Solicitud de Amistad",
            .contactsAddFriend: "Agregar amigo",
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
            .discoverTitle: "Descubrir", .discoverSubtitle: "Marcas y campañas para tu roster",
            .discoverFeatured: "DESTACADO", .discoverViewBrief: "Ver brief", .discoverTopBrands: "Marcas Top",
            .discoverOpenCampaigns: "Campañas Abiertas", .discoverActive: "activas",
            .discoverDue: "Entrega", .discoverSpotsLeft: "cupos",
            .filterAll: "Todo", .filterBeauty: "Belleza", .filterFashion: "Moda", .filterWellness: "Bienestar", .filterTech: "Tecnología",
            .campaignDetailBudget: "Presupuesto", .campaignDetailDeadline: "Fecha límite",
            .campaignDetailSpots: "Cupos", .campaignDetailApply: "Aplicar",
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
            .privacyDataSharing: "Compartir Datos", .privacyDataSharingSub: "Controlar cómo se usan tus datos",
            .profileEdit: "Editar Perfil", .profileReach: "Alcance", .profileEngagement: "Interacción", .profileDeals: "Tratos cerrados",
            .profileOpenDeals: "Abierto a nuevos tratos", .profileOpenDealsSub: "Las marcas ven que estás disponible",
            .profilePreferences: "Preferencias", .profileNotifications: "Notificaciones",
            .profilePrivacy: "Privacidad y Seguridad", .profileLanguage: "Idioma",
            .profileSupport: "Soporte", .profileHelp: "Centro de Ayuda", .profileContact: "Contactar a Wefluens", .profileRate: "Valorar la App",
            .profileSignOut: "Cerrar Sesión",
            .settingsTitle: "Ajustes", .settingsLanguage: "Idioma",
            .settingsLanguageFooter: "Elige tu idioma preferido. Se aplica en toda la app.",
            .settingsDone: "Hecho",
            .settingsAppearance: "Apariencia", .settingsAppearanceFooter: "Cambia entre modo claro y oscuro.",
            .themeLight: "Claro", .themeDark: "Oscuro",
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
        ],
    ]
}
