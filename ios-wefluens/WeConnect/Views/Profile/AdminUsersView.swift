//
//  AdminUsersView.swift
//  WeConnect
//
//  Backend management — list all users, ban/unban, delete.
//  Uses the unambiguous database functions created by the fix-admin-functions migration.
//

import SwiftUI
import Supabase

struct AdminUsersView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var alertState: AdminAlertState?
    @State private var errorMessage: String?
    @State private var showInvite = false

    enum AdminAlertState: Identifiable {
        case ban(AdminUser)
        case unban(AdminUser)
        case delete(AdminUser)

        var id: String {
            switch self {
            case .ban(let u): return "ban-\(u.id)"
            case .unban(let u): return "unban-\(u.id)"
            case .delete(let u): return "delete-\(u.id)"
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(Theme.coral)
            } else if users.isEmpty {
                emptyState
            } else {
                usersList
            }
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.adminTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showInvite = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadUsers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteUserSheet { Task { await loadUsers() } }
        }
        .task { await loadUsers() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Ban this user?",
            isPresented: .init(
                get: { if case .ban = alertState { true } else { false } },
                set: { if !$0 { alertState = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ban user", role: .destructive) {
                guard case .ban(let u) = alertState else { return }
                Task { await banUser(u) }
            }
            Button("Cancel", role: .cancel) { alertState = nil }
        } message: {
            if case .ban(let u) = alertState {
                Text("\(u.name) (\(u.email)) will be blocked from signing in.")
            }
        }
        .confirmationDialog(
            "Unban this user?",
            isPresented: .init(
                get: { if case .unban = alertState { true } else { false } },
                set: { if !$0 { alertState = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unban user") {
                guard case .unban(let u) = alertState else { return }
                Task { await unbanUser(u) }
            }
            Button("Cancel", role: .cancel) { alertState = nil }
        } message: {
            if case .unban(let u) = alertState {
                Text("\(u.name) (\(u.email)) will be able to sign in again.")
            }
        }
        .confirmationDialog(
            "Permanently delete this user?",
            isPresented: .init(
                get: { if case .delete = alertState { true } else { false } },
                set: { if !$0 { alertState = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete permanently", role: .destructive) {
                guard case .delete(let u) = alertState else { return }
                Task { await deleteUser(u) }
            }
            Button("Cancel", role: .cancel) { alertState = nil }
        } message: {
            if case .delete(let u) = alertState {
                Text("\(u.name)\n\(u.email)\n\nThis action cannot be undone.")
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.adminNoUsers))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var usersList: some View {
        List {
            Section {
                Button {
                    showInvite = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.sunset)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t(.adminInvite))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink(for: colorScheme))
                            Text(l10n.t(.adminInviteSubtitle))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    }
                    .padding(12)
                    .cardStyle(cornerRadius: 16)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section(l10n.t(.adminAllUsers)) {
                ForEach(users) { user in
                    UserRow(
                        user: user,
                        l10n: l10n,
                        colorScheme: colorScheme,
                        onBan: { alertState = .ban(user) },
                        onUnban: { alertState = .unban(user) },
                        onDelete: { alertState = .delete(user) }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    @MainActor
    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            struct FetchUser: Codable, Identifiable {
                let id: UUID
                let email: String?
                let name: String?
                let isAdmin: Bool?
                let isBanned: Bool?
                let createdAt: Date?

                enum CodingKeys: String, CodingKey {
                    case id, email, name
                    case isAdmin = "is_admin"
                    case isBanned = "is_banned"
                    case createdAt = "created_at"
                }
            }

            let rows: [FetchUser] = try await supabase
                .from("profiles")
                .select("id,email,name,is_admin,is_banned,created_at")
                .order("created_at", ascending: false)
                .execute()
                .value

            users = rows.map { row in
                AdminUser(
                    id: row.id,
                    email: row.email ?? "—",
                    name: row.name ?? "—",
                    isAdmin: row.isAdmin ?? false,
                    isBanned: row.isBanned ?? false,
                    createdAt: row.createdAt
                )
            }
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func banUser(_ user: AdminUser) async {
        do {
            try await supabase.rpc(
                "admin_ban_user",
                params: AdminBanParams(target_id: user.id, ban: true)
            )
            .execute()
            await loadUsers()
        } catch {
            errorMessage = "Failed to ban user: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func unbanUser(_ user: AdminUser) async {
        do {
            try await supabase.rpc(
                "admin_ban_user",
                params: AdminBanParams(target_id: user.id, ban: false)
            )
            .execute()
            await loadUsers()
        } catch {
            errorMessage = "Failed to unban user: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteUser(_ user: AdminUser) async {
        do {
            try await supabase.rpc(
                "admin_delete_user",
                params: AdminDeleteParams(target_id: user.id)
            )
            .execute()
            await loadUsers()
        } catch {
            errorMessage = "Failed to delete user: \(error.localizedDescription)"
        }
    }
}

// MARK: - RPC Params (UUID typed — matches the fixed DB functions)

nonisolated struct AdminBanParams: Encodable, Sendable {
    let target_id: UUID
    let ban: Bool
}

nonisolated struct AdminDeleteParams: Encodable, Sendable {
    let target_id: UUID
}

// MARK: - Invite edge function

nonisolated struct InviteRequest: Encodable, Sendable {
    let email: String
}

nonisolated struct InviteResponse: Codable, Sendable {
    let ok: Bool?
    let error: String?
}

// MARK: - Models

struct AdminUser: Identifiable {
    let id: UUID
    let email: String
    let name: String
    let isAdmin: Bool
    let isBanned: Bool
    let createdAt: Date?
}

// MARK: - Subviews

private struct UserRow: View {
    let user: AdminUser
    let l10n: LocalizationManager
    let colorScheme: ColorScheme
    let onBan: () -> Void
    let onUnban: () -> Void
    let onDelete: () -> Void

    private var initials: String {
        let parts = user.name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(
                colors: user.isAdmin ? [0xFF4D6D, 0xFF9A5A] : [0x6C5CE7, 0xA29BFE],
                initials: initials,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    if user.isBanned {
                        Text("Banned")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(user.email)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            if user.isAdmin {
                Text("Admin")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.coral.opacity(0.1))
                    .clipShape(Capsule())
            }

            Menu {
                if user.isBanned {
                    Button {
                        onUnban()
                    } label: {
                        Label("Unban", systemImage: "person.badge.clock.fill")
                    }
                } else {
                    Button(role: .destructive) {
                        onBan()
                    } label: {
                        Label("Ban user", systemImage: "person.badge.minus")
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(12)
        .cardStyle(cornerRadius: 16)
    }
}

// MARK: - Invite User Sheet

private struct InviteUserSheet: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let onInvited: () -> Void

    @State private var email = ""
    @State private var isSending = false
    @State private var toast: ToastState?
    @FocusState private var emailFocused: Bool

    private struct ToastState: Equatable {
        let isSuccess: Bool
        let message: String
    }

    private var canSend: Bool {
        let t = email.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".") && !isSending
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Theme.sunset.opacity(0.15))
                            .frame(width: 84, height: 84)
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(Theme.coral)
                    }
                    .padding(.top, 12)

                    Text(l10n.t(.adminInviteTitle))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink(for: colorScheme))

                    Text(l10n.t(.adminInviteSubtitle))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                            .frame(width: 22)
                        TextField(l10n.t(.adminInviteEmailPlaceholder), text: $email)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($emailFocused)
                            .onChange(of: email) { _, _ in
                                // Clearing the field after a successful send must NOT wipe
                                // the success toast — only stale error toasts clear on edit.
                                if toast?.isSuccess == false { toast = nil }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .cardStyle(cornerRadius: 14)
                    .padding(.horizontal, 20)

                    Button {
                        Task { await send() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Text(l10n.t(.adminInviteSend))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(canSend ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.inkTertiary(for: colorScheme)))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSend)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .overlay(alignment: .top) {
                if let toast {
                    toastView(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(l10n.t(.adminInvite))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.t(.settingsDone)) { dismiss() }
                        .foregroundStyle(Theme.coral)
                }
            }
            .onAppear { emailFocused = true }
            .animation(.easeInOut(duration: 0.25), value: toast)
        }
    }

    @MainActor
    private func send() async {
        let target = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard canSend else { return }
        isSending = true
        defer { isSending = false }

        do {
            let resp: InviteResponse = try await supabase.functions.invoke(
                "invite-user",
                options: .init(body: InviteRequest(email: target))
            )
            if resp.ok == true {
                onInvited()
                email = ""   // safe now: a success toast survives the email onChange
                show(ToastState(isSuccess: true, message: l10n.t(.adminInviteSent)))
            } else {
                show(ToastState(isSuccess: false, message: message(for: resp.error)))
            }
        } catch {
            show(ToastState(isSuccess: false, message: l10n.t(.adminInviteErrGeneric)))
        }
    }

    /// Shows a green (success) or red (failure) toast with haptics, then
    /// auto-dismisses it after a short delay.
    @MainActor
    private func show(_ next: ToastState) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { toast = next }
        UINotificationFeedbackGenerator().notificationOccurred(next.isSuccess ? .success : .error)
        DispatchQueue.main.asyncAfter(deadline: .now() + (next.isSuccess ? 2.6 : 3.6)) {
            if toast == next {
                withAnimation(.easeOut(duration: 0.3)) { toast = nil }
            }
        }
    }

    private func toastView(_ t: ToastState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: t.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
            Text(t.message)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(t.isSuccess ? Color(hex: 0x2AD17E) : Color(hex: 0xFF5A5F))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.top, 10)
        .padding(.horizontal, 20)
    }

    private func message(for code: String?) -> String {
        switch code {
        case "INVALID_EMAIL": return l10n.t(.adminInviteErrInvalid)
        case "ALREADY_REGISTERED": return l10n.t(.adminInviteErrExists)
        case "EMAIL_NOT_CONFIGURED": return l10n.t(.adminInviteErrEmail)
        case "EMAIL_SEND_FAILED": return l10n.t(.adminInviteErrSend)
        default: return l10n.t(.adminInviteErrGeneric)
        }
    }
}

#Preview {
    NavigationStack {
        AdminUsersView()
            .environment(AuthManager())
            .environment(LocalizationManager())
    }
}
