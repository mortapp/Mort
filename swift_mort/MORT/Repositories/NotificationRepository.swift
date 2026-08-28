import Foundation
import Supabase

protocol NotificationRepositoryProtocol: Sendable {
    func listMine() async throws -> [MortNotification]
    func markRead(id: UUID) async throws
    func markAllRead() async throws
}

final class NotificationRepository: SupabaseRepository, NotificationRepositoryProtocol {
    func listMine() async throws -> [MortNotification] {
        try await translated {
            try await client.from("notifications").select().eq("recipient_id", value: try await currentUserID())
                .order("created_at", ascending: false).limit(60).execute().value
        }
    }

    func markRead(id: UUID) async throws {
        try await translated {
            try await client.from("notifications").update(["read_at": Date().iso8601String]).eq("id", value: id).execute()
        }
    }

    func markAllRead() async throws {
        try await translated {
            try await client.from("notifications").update(["read_at": Date().iso8601String])
                .eq("recipient_id", value: try await currentUserID()).is("read_at", value: nil).execute()
        }
    }
}

