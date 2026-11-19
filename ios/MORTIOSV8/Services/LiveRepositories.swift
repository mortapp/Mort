egory, detail: String, jobId: String?) async throws {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            throw MortError.rejected("Add a little more detail before submitting the safety report.")
        }
        if let jobId, UUID(uuidString: jobId) == nil { throw MortError.notFound }
        guard jobId != nil else {
            throw MortError.rejected("Choose the related job before submitting this safety report.")
        }

        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.submitSafetyReport,
            args: [
                "p_target_user_id": SupabaseJSONNull(),
                "p_target_job_id": jobId!,
                "p_target_message_id": SupabaseJSONNull(),
                "p_target_review_id": SupabaseJSONNull(),
                "p_application_id": SupabaseJSONNull(),
                "p_category": Self.backendCategory(category),
                "p_severity": "moderate",
                "p_immediate_danger": false,
                "p_details": trimmed,
                "p_occurred_at": Date().ISO8601Format(),
                "p_location_type": SupabaseJSONNull(),
                "p_desired_outcome": "review_and_follow_up",
                "p_confidential_safety_feedback": false,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not submit that safety report.")
        }
    }

    func raiseEmergencyAlert(jobId: String?) async throws {
        // The hosted urgent Safety Ping creates a critical safety incident but
        // explicitly does NOT claim physical intervention was dispatched.
        guard let jobId, UUID(uuidString: jobId) != nil else {
            throw MortError.notConfigured("Urgent safety ping without an active job")
        }
        let response: HostedSafetyPingResponseDTO = try await client.rpc(
            MortBackendContract.RPC.createSafetyPing,
            args: [
                "p_status": "needs_help",
                "p_note": "Urgent safety help requested from the MORT iOS Safety Center.",
                "p_job_id": jobId,
                "p_immediate_danger": true,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not send the urgent safety ping.")
        }
    }

    private static func backendCategory(_ category: SafetyReportCategory) -> String {
        switch category {
        case .unsafeBehavior: return "unsafe_job_conditions"
        case .harassment: return "harassment"
        case .paymentProblem: return "nonpayment"
        case .noShow: return "other_urgent_concern"
        case .unsafeLocation: return "unexpected_location"
        case .somethingElse: return "other_urgent_concern"
        }
    }

    func capabilityState() async -> SafetyCapabilityState {
        guard await client.storedSession() != nil else { return .unavailable }
        return .available
    }
}

nonisolated final class LiveSupportRepository: SupportRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func cases() async throws -> [SupportCase] {
        let rows: [HostedSupportTicketDTO] = try await client.rpc(
            MortBackendContract.RPC.listSupportTickets
        )
        return rows.map { $0.toDomain() }
    }

    func openCase(
        topicId: String,
        subject: String,
        detail: String,
        reference: String?
    ) async throws -> SupportCase {
        let response: HostedSupportCreateResponseDTO = try await client.rpc(
            MortBackendContract.RPC.createSupportTicket,
            args: [
                "p_subject": subject,
                "p_message": detail,
            ]
        )
        guard response.ok, let ticket = response.ticket else {
            throw MortError.rejected(response.code ?? "Support could not open that conversation.")
        }
        return ticket.toDomain()
    }

    func messages(caseId: String) async throws -> [MortMessage] {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let thread: HostedSupportThreadDTO = try await client.rpc(
            MortBackendContract.RPC.supportThread,
            args: ["p_ticket_id": caseId]
        )
        guard thread.ok else {
            throw MortError.rejected(thread.code ?? "That support conversation is unavailable.")
        }
        return (thread.messages ?? []).map { $0.toDomain() }
    }

    func reply(caseId: String, body: String) async throws -> MortMessage {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MortError.rejected("Write a reply before sending.")
        }

        let response: HostedSupportReplyResponseDTO = try await client.rpc(
            MortBackendContract.RPC.postSupportTicketMessage,
            args: [
                "p_ticket_id": caseId,
                "p_message": trimmed,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok, let message = response.message else {
            throw MortError.rejected(response.code ?? "That support reply could not be sent.")
        }
        return message.toDomain()
    }

    func requestHuman(caseId: String) async throws {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.requestSupportHumanReview,
            args: ["p_ticket_id": caseId]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "Human review could not be requested.")
        }
    }
}

nonisolated final class LiveNotificationRepository: NotificationRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func notifications() async throws -> [MortNotification] {
        let rows: [HostedNotificationDTO] = try await client.get(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "100"),
            ]
        )
        return rows.map { $0.toDomain() }
    }

    func markRead(id: String) async throws {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        let rows: [HostedNotificationDTO] = try await client.patch(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "read_at", value: "is.null"),
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
            ],
            body: ["read_at": Date().ISO8601Format()]
        )
        // A zero-row update is valid when the notification was already read.
        if rows.isEmpty {
            let existing: [HostedNotificationDTO] = try await client.get(
                path: "/rest/v1/notifications",
                query: [
                    URLQueryItem(name: "id", value: "eq.\(id)"),
                    URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
                    URLQueryItem(name: "limit", value: "1"),
                ]
            )
            guard existing.first != nil else { throw MortError.notFound }
        }
    }

    func markAllRead() async throws {
        let _: [HostedNotificationDTO] = try await client.patch(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "read_at", value: "is.null"),
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
            ],
            body: ["read_at": Date().ISO8601Format()]
        )
    }

    func registerPushToken(_ token: String) async throws {
        // Hosted push registration currently requires an FCM registration
        // token even on iOS. This protocol receives the native APNs token, so
        // forwarding it would falsely register the wrong provider material.
        throw MortError.notConfigured("iOS push provider bridge")
    }
}

nonisolated final class LiveGuardianRepository: GuardianRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func linkedTeens() async throws -> [MortUser] {
        let links: [HostedGuardianConnectionDTO] = try await client.get(
            path: "/rest/v1/guardian_connections",
            query: [
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "select", value: "id,teen_id,guardian_id,status"),
                URLQueryItem(name: "order", value: "accepted_at.desc"),
            ]
        )
        let teenIds = Array(Set(links.map(\.teenId)))
        guard !teenIds.isEmpty else { return [] }

        let rows: [HostedProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "in.(\(teenIds.joined(separator: ",")))"),
                URLQueryItem(
                    name: "select",
                    value: "id,username,display_name,role,city,state,approximate_area,verification_status,guardian_setup_status,created_at,updated_at,bio"
                ),
            ]
        )
        let order = Dictionary(uniqueKeysWithValues: teenIds.enumerated().map { ($0.element, $0.offset) })
        return rows
            .sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
            .map { $0.toDomain() }
    }

    func teenSummary(teenId: String) async throws -> GuardianSummary {
        guard UUID(uuidString: teenId) != nil else { throw MortError.notFound }
        let dto: HostedGuardianTeenSummaryDTO? = try await client.rpc(
            MortBackendContract.RPC.guardianTeenSummary,
            args: ["p_teen_id": teenId]
        )
        guard let dto, dto.ok else { throw MortError.notFound }
        return dto.toDomain()
    }

    func inviteTeen(email: String) async throws {
        // Hosted invite creation is teen-initiated. A guardian cannot create a
        // link for a teen by email, so this legacy UI path fails closed.
        throw MortError.notConfigured("Guardian-initiated email invite")
    }

    func acceptLink(code: String) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            throw MortError.rejected("Enter the guardian link code from the teen account.")
        }
        let response: HostedGuardianLinkResponseDTO = try await client.rpc(
            MortBackendContract.RPC.acceptGuardianInvite,
            args: ["p_invite_code": trimmed]
        )
        guard response.ok else {
            throw MortError.rejected(
                response.message ?? response.code ?? "That guardian link code could not be accepted."
            )
        }
    }

    func unlink(teenId: String) async throws {
        guard UUID(uuidString: teenId) != nil else { throw MortError.notFound }
        let rows: [HostedGuardianConnectionDTO] = try await client.get(
            path: "/rest/v1/guardian_connections",
            query: [
                URLQueryItem(name: "teen_id", value: "eq.\(teenId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "select", value: "id,teen_id,guardian_id,status"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let link = rows.first else { throw MortError.notFound }
        let response: HostedGuardianLinkResponseDTO = try await client.rpc(
            MortBackendContract.RPC.unlinkGuardian,
            args: ["p_link_id": link.id]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "That Guardian Mode link could not be removed.")
        }
    }
}
