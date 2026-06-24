//
//  GroupChatViewModel.swift
//  WeConnect
//
//  Drives a single group thread: loads history (with each sender's profile),
//  sends via `send_group_message`, marks the group read, and subscribes to live
//  inserts via Supabase Realtime (RLS scopes delivery to members). Text-only.
//

import Foundation
import Supabase

@Observable
@MainActor
final class GroupChatViewModel {
    let route: GroupChatRoute
    private let data: AppDataService

    var messages: [GroupChatMessage] = []
    var isLoading = true
    var sendFailed = false
    /// When non-nil, a recall error alert is shown with this specific localized
    /// message (resolved in the view via `l10n.t(recallError!)`).
    var recallError: L10n?
    var isSendingImage = false
    var isSendingVideo = false
    var isSendingFile = false
    var isSendingVoice = false
    /// The message the user is quoting in their next send (nil = normal message).
    var replyingTo: GroupChatMessage?
    /// Set when a tap-to-jump (quote / pinned banner) targets a message that isn't
    /// in the currently loaded thread, so the view can surface a "can't find" notice.
    var jumpMissing = false

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?

    init(route: GroupChatRoute, data: AppDataService) {
        self.route = route
        self.data = data
    }

    /// Loads history, marks the group read, refreshes the inbox, then subscribes
    /// to live inserts so other members' messages appear in real time.
    func start() async {
        // Show the last cached view instantly (秒开 / survives a brief offline blip),
        // then refresh from the server.
        if let cached = MessageCache.loadGroup(route.groupId), !cached.isEmpty {
            messages = cached
            isLoading = false
        }
        await reload(allowEmpty: false)
        isLoading = false
        await data.markGroupRead(groupId: route.groupId)
        await data.loadConversations()
        await subscribe()
    }

    /// Re-reads the group and re-caches it. `allowEmpty` is false only for the
    /// initial load, so a transient empty fetch (offline) doesn't wipe the cached
    /// view; mutations (delete / clear / recall) keep the default `true` so an
    /// emptied thread correctly clears.
    func reload(allowEmpty: Bool = true) async {
        let fresh = await data.loadGroupMessages(groupId: route.groupId)
        if allowEmpty || !fresh.isEmpty {
            messages = fresh
        }
        if !fresh.isEmpty {
            MessageCache.saveGroup(route.groupId, fresh)
        }
    }

    /// Sends a group message through the member-validated `send_group_message`
    /// function. The list is re-read from the database — never a fake local append.
    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let reply = replyingTo?.id
        do {
            try await data.sendGroupMessage(groupId: route.groupId, body: clean, replyTo: reply)
            replyingTo = nil
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_message failed: \(error)")
        }
    }

    /// Clears the active quoted-reply context (the × on the composer bar).
    func cancelReply() {
        replyingTo = nil
    }

    /// Soft-deletes a single group message for me only (A).
    func deleteMessage(_ messageId: UUID) async {
        do {
            try await data.deleteMessageForMe(messageId: messageId, kind: "group")
            await reload()
        } catch {
            print("⚠️ delete_message_for_me (group) failed: \(error)")
        }
    }

    /// Recalls a group message for everyone (B). Only my own, within 2 minutes.
    /// Parses the server error to show a specific user-facing message instead of
    /// the old catch-all 「撤回失败」 alert.
    func recallMessage(_ messageId: UUID) async {
        do {
            try await data.recallMessage(messageId: messageId, kind: "group")
            // Optimistic: mark the local copy as recalled immediately so the bubble
            // flips to the placeholder without waiting for a full reload.
            if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                let old = messages[idx]
                messages[idx] = GroupChatMessage(
                    id: old.id, text: "", sender: old.sender, senderId: old.senderId,
                    senderName: old.senderName, senderColors: old.senderColors,
                    senderAvatarUrl: old.senderAvatarUrl, time: old.time,
                    kind: old.kind, imagePath: nil, imageWidth: nil, imageHeight: nil,
                    fileName: nil, fileSize: nil, fileMime: nil,
                    isRecalled: true,
                    createdAt: old.createdAt
                )
            }
            await reload()
        } catch {
            let msg = "\(error)"
            print("⚠️ recall_message (group) failed: \(msg)")
            recallError = recallErrorMessage(from: msg)
        }
    }

    /// Maps a server `raise exception` message to a localization key.
    /// Unknown / network errors fall back to the generic 「撤回失败，请重试」.
    private func recallErrorMessage(from raw: String) -> L10n {
        let uppercased = raw.uppercased()
        if uppercased.contains("EXPIRED") { return .chatRecallExpired }
        if uppercased.contains("ALREADY_RECALLED") { return .chatRecallAlreadyRecalled }
        if uppercased.contains("FORBIDDEN") { return .chatRecallForbidden }
        return .chatRecallError
    }

    /// Clears the entire group thread for me only (C).
    func clearHistory() async {
        do {
            try await data.clearGroupHistory(groupId: route.groupId)
            await reload()
        } catch {
            print("⚠️ clear_group_history failed: \(error)")
        }
    }

    /// Uploads a picked photo to the private `chat-media` bucket and sends it as a
    /// group image via `send_group_attachment` (member-validated). Re-reads from the
    /// DB on success; surfaces a real error on failure (never a silent no-op).
    func sendImage(_ imageData: Data) async {
        guard !isSendingImage else { return }
        isSendingImage = true
        defer { isSendingImage = false }
        do {
            let upload = try await data.uploadGroupImage(groupId: route.groupId, imageData: imageData)
            try await data.sendGroupImageMessage(
                groupId: route.groupId,
                imagePath: upload.path,
                caption: "",
                width: upload.width,
                height: upload.height
            )
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_attachment (image) failed: \(error)")
        }
    }

    /// Uploads a picked video to the private `chat-media` bucket and sends it as a
    /// group video via `send_group_attachment` (p_type "video"). Re-reads on success.
    func sendVideo(_ videoData: Data) async {
        guard !isSendingVideo else { return }
        isSendingVideo = true
        defer { isSendingVideo = false }
        do {
            let upload = try await data.uploadGroupFile(
                groupId: route.groupId,
                data: videoData,
                fileName: "video.mp4",
                mimeType: "video/mp4"
            )
            try await data.sendGroupVideoMessage(groupId: route.groupId, upload: upload)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_attachment (video) failed: \(error)")
        }
    }

    /// Uploads a picked document to the private `chat-media` bucket and sends it as a
    /// group file via `send_group_attachment` (member-validated). Re-reads from the DB
    /// on success; surfaces a real error on failure (never a silent no-op).
    func sendFile(data fileData: Data, fileName: String, mimeType: String) async {
        guard !isSendingFile else { return }
        isSendingFile = true
        defer { isSendingFile = false }
        do {
            let upload = try await data.uploadGroupFile(
                groupId: route.groupId,
                data: fileData,
                fileName: fileName,
                mimeType: mimeType
            )
            try await data.sendGroupFileMessage(groupId: route.groupId, upload: upload)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_attachment (file) failed: \(error)")
        }
    }

    /// Uploads a recorded voice clip to the private `chat-media` bucket and sends it
    /// as a group audio message via `send_group_attachment` (member-validated).
    /// Re-reads from the DB on success; surfaces a real error on failure.
    func sendVoice(_ audioData: Data) async {
        guard !isSendingVoice else { return }
        isSendingVoice = true
        defer { isSendingVoice = false }
        do {
            try await data.sendGroupVoice(groupId: route.groupId, data: audioData)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_attachment (audio) failed: \(error)")
        }
    }

    /// Subscribes to inserts AND updates on `group_messages`. RLS only delivers rows
    /// for groups I'm a member of. Updates propagate recall (recalled_at → non-null)
    /// so all members see "Message recalled" in real time.
    private func subscribe() async {
        let ch = supabase.channel("group-thread-\(route.groupId.uuidString)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "group_messages")
        let updates = ch.postgresChange(UpdateAction.self, schema: "public", table: "group_messages")
        listenTask = Task { [weak self] in
            for await _ in inserts {
                guard let self else { return }
                await self.reload()
                await self.data.markGroupRead(groupId: self.route.groupId)
                await self.data.loadConversations()
            }
        }
        updateTask = Task { [weak self] in
            for await _ in updates {
                guard let self else { return }
                await self.reload()
            }
        }
        await ch.subscribe()
        channel = ch
    }

    /// Tears down the realtime subscription. Call from the view's `onDisappear`.
    func stop() async {
        listenTask?.cancel()
        listenTask = nil
        updateTask?.cancel()
        updateTask = nil
        if let channel {
            await channel.unsubscribe()
            await supabase.removeChannel(channel)
        }
        channel = nil
    }
}
