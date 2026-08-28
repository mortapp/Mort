import Foundation
import Supabase

protocol MessageRepositoryProtocol: Sendable {
    func listThreads() async throws -> [MessageThread]
    func listMessages(threadID: UUID, before: String?, limit: Int) async throws -> [MortMessage]
    func send(threadID: UUID, body: String) async throws -> MortMessage
    func markRead(threadID: UUID) async throws
    func changes(threadID: UUID) -> AsyncStream<Void>
}

final class MessageRepository: SupabaseRepository, MessageRepositoryProtocol {
    func listThreads() async throws -> [MessageThread] {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_message_threads").execute().value
        }
    }

    func listMessages(threadID: UUID, before: String? = nil, limit: Int = 50) async throws -> [MortMessage] {
        try await translated {
            var query = client.from("messages").select().eq("thread_id", value: threadID)
            if let before { query = query.lt("created_at", value: before) }
            let rows: [MortMessage] = try await query.order("created_at", ascending: false).limit(limit).execute().value
            return Array(rows.reversed())
        }
    }

    func send(threadID: UUID, body: String) async throws -> MortMessage {
        struct Params: Encodable { let p_thread_id: UUID; let p_body: String }
        let clean = body.trimmed
        guard !clean.isEmpty else { throw MortError.invalidInput("Write a message first.") }
        return try await translated {
            try await client.rpc("send_safe_message", params: Params(p_thread_id: threadID, p_body: clean)).execute().value
        }
    }

    func markRead(threadID: UUID) async throws {
        struct Params: Encodable { let p_thread_id: UUID }
        try await translated {
            let result: GenericRPCResult = try await client.rpc(
                "mark_message_thread_read",
                params: Params(p_thread_id: threadID)
            ).execute().value
            _ = try result.requireSuccess(defaultMessage: "The conversation read state could not be updated.")
        }
    }

    func changes(threadID: UUID) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let channel = client.channel("messages:\(threadID.uuidString)")
                let changes = channel.postgresChange(
                    AnyAction.self,
                    schema: "public",
                    table: "messages",
                    filter: .eq("thread_id", value: threadID.uuidString)
                )
                await channel.subscribe()
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
                await channel.unsubscribe()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
