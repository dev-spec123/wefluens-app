//
//  ChatThreadViewModel.swift
//  Wefluens
//
//  Drives a single 1:1 chat thread: loads history, sends via `send_dm`,
//  marks the thread read, and subscribes to live inserts via Supabase Realtime.
//

import Foundation
import Supabase

@Observable
@MainActor
final class ChatThreadViewModel {
    let route: DMChatRoute
    private let data: AppDataService

    var messages: [ChatMessage] = []
    var isLoading = true
    var sendFailed = false
    var isSendingImage = false
    var isSendingFile = false

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?

    init(route: DMChatRoute, data: AppDataService) {
        self.route = route
        self.data = data
    }

    /// Loads history, marks the thread read, refreshes the inbox, then subscribes
    /// to live inserts so the other person's replies appear in real time.
    func start() async {
        await reload()
        isLoading = false
        await data.markThreadRead(threadId: route.threadId)
        await data.loadConversations()
        await subscribe()
    }

    func reload() async {
        messages = await data.loadThreadMessages(threadId: route.threadId)
    }

    /// Sends a message through the friend-validated `send_dm` function. The list
    /// is re-read from the database — never a fake local-only append.
    func send(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            try await data.sendMessage(to: route.otherUserId, body: clean)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_dm failed: \(error)")
        }
    }

    /// Uploads a picked photo to the private `chat-media` bucket and sends it as an
    /// image message via `send_dm_media` (friends-only). Re-reads from the DB on
    /// success; surfaces a real error on failure (never a silent no-op).
    func sendImage(_ imageData: Data) async {
        guard !isSendingImage else { return }
        isSendingImage = true
        defer { isSendingImage = false }
        do {
            let upload = try await data.uploadChatImage(threadId: route.threadId, imageData: imageData)
            try await data.sendImageMessage(
                to: route.otherUserId,
                imagePath: upload.path,
                caption: "",
                width: upload.width,
                height: upload.height
            )
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_dm_media failed: \(error)")
        }
    }

    /// Uploads a picked document to the private `chat-media` bucket and sends it as a
    /// file message via the generic `send_dm_attachment` (friends-only). Re-reads
    /// from the DB on success; surfaces a real error on failure (never a silent no-op).
    func sendFile(data: Data, fileName: String, mimeType: String) async {
        guard !isSendingFile else { return }
        isSendingFile = true
        defer { isSendingFile = false }
        do {
            let upload = try await self.data.uploadChatFile(
                threadId: route.threadId,
                data: data,
                fileName: fileName,
                mimeType: mimeType
            )
            try await self.data.sendFileMessage(to: route.otherUserId, upload: upload)
            await reload()
        } catch {
            sendFailed = true
            print("⚠️ send_dm_attachment (file) failed: \(error)")
        }
    }

    /// Subscribes to changes on `dm_messages`. RLS only delivers rows where I'm a
    /// participant. On an INSERT we re-read this thread and mark it read (cheap,
    /// avoids client-side dedup). On an UPDATE we re-read only — this is how my
    /// view flips "Delivered" → "Read" the moment the other person opens the
    /// thread and `mark_thread_read` stamps `read_at` on my sent messages.
    /// (Re-reading on UPDATE never writes, so there is no feedback loop.)
    private func subscribe() async {
        let ch = supabase.channel("dm-thread-\(route.threadId.uuidString)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "dm_messages")
        let updates = ch.postgresChange(UpdateAction.self, schema: "public", table: "dm_messages")
        listenTask = Task { [weak self] in
            for await _ in inserts {
                guard let self else { return }
                await self.reload()
                await self.data.markThreadRead(threadId: self.route.threadId)
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
