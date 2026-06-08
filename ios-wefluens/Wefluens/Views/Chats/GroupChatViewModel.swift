//
//  GroupChatViewModel.swift
//  Wefluens
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
    var isSendingImage = false
    var isSendingFile = false

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(route: GroupChatRoute, data: AppDataService) {
        self.route = route
        self.data = data
    }

    /// Loads history, marks the group read, refreshes the inbox, then subscribes
    /// to live inserts so other members' messages appear in real time.
    func start() async {
        await reload()
        isLoading = false
        await data.markGroupRead(groupId: route.groupId)
        await data.loadConversations()
        await subscribe()
    }

    func reload() async {
        messages = await data.loadGroupMessages(groupId: route.groupId)
    }

    /// Sends a group message through the member-validated `send_group_message`
    /// function. The list is re-read from the database — never a fake local append.
    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await data.sendGroupMessage(groupId: route.groupId, body: clean)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_group_message failed: \(error)")
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

    /// Subscribes to inserts on `group_messages`. RLS only delivers rows for groups
    /// I'm a member of. On a new message we re-read this group and mark it read so
    /// the unread badge stays correct (cheap; avoids client-side dedup).
    private func subscribe() async {
        let ch = supabase.channel("group-thread-\(route.groupId.uuidString)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "group_messages")
        listenTask = Task { [weak self] in
            for await _ in inserts {
                guard let self else { return }
                await self.reload()
                await self.data.markGroupRead(groupId: self.route.groupId)
                await self.data.loadConversations()
            }
        }
        await ch.subscribe()
        channel = ch
    }

    /// Tears down the realtime subscription. Call from the view's `onDisappear`.
    func stop() async {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            await channel.unsubscribe()
            await supabase.removeChannel(channel)
        }
        channel = nil
    }
}
