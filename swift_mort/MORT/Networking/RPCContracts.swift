import Foundation

struct EmptyRPCParameters: Encodable, Sendable {}

struct GenericRPCResult: Codable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let linkID: UUID?
    let inviteCode: String?
    let availableCredits: Int?

    enum CodingKeys: String, CodingKey {
        case ok, code, message
        case linkID = "link_id"
        case inviteCode = "invite_code"
        case availableCredits = "available_credits"
    }

    func requireSuccess(defaultMessage: String) throws -> GenericRPCResult {
        guard ok else { throw MortError.backend(code: code ?? "unknown_permission_failure", message: message ?? defaultMessage) }
        return self
    }
}

struct JobRPCResult: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let job: Job?

    func requiredJob() throws -> Job {
        guard ok else { throw MortError.backend(code: code ?? "unknown_permission_failure", message: message) }
        guard let job else { throw MortError.invalidResponse }
        return job
    }
}

struct ApplicationRPCResult: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let application: MortApplication?

    func requiredApplication() throws -> MortApplication {
        guard ok else { throw MortError.backend(code: code ?? "unknown_permission_failure", message: message) }
        guard let application else { throw MortError.invalidResponse }
        return application
    }
}

struct UsernameChangeRPCResult: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let username: String?
}

struct TicketRPCResult: Decodable, Sendable {
    struct Ticket: Decodable, Sendable { let id: UUID }
    let ok: Bool
    let code: String?
    let ticket: Ticket?
}

struct ProofRPCResult: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
}

struct ProofReviewRPCResult: Decodable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let proof: ProofUpload?

    func requiredProof() throws -> ProofUpload {
        guard ok else {
            throw MortError.backend(code: code ?? "unknown_permission_failure", message: message)
        }
        guard let proof else { throw MortError.invalidResponse }
        return proof
    }
}
