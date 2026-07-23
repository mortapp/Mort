import Foundation
import Supabase

protocol SupportRepositoryProtocol: Sendable {
    func createTicket(subject: String, message: String) async throws -> UUID
    func listMine() async throws -> [SupportTicket]
}

final class SupportRepository: SupabaseRepository, SupportRepositoryProtocol {
    func createTicket(subject: String, message: String) async throws -> UUID {
        struct Params: Encodable { let p_subject: String; let p_message: String }
        return try await translated {
            _ = try await currentUserID()
            let result: TicketRPCResult = try await client.rpc("create_support_ticket", params: Params(
                p_subject: subject.trimmed, p_message: message.trimmed
            )).execute().value
            guard result.ok, let id = result.ticket?.id else {
                throw MortError.backend(code: result.code ?? "unknown_permission_failure", message: "The support ticket could not be created.")
            }
            return id
        }
    }

    func listMine() async throws -> [SupportTicket] {
        try await translated {
            try await client.from("support_tickets").select("id,subject,status,created_at,updated_at")
                .eq("requester_id", value: try await currentUserID()).order("created_at", ascending: false).limit(25).execute().value
        }
    }
}

