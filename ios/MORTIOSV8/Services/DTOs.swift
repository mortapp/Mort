//
//  DTOs.swift
//  MORT iOS V8 — Services / wire models
//
//  Backend transfer objects and their domain mappings.
//
//  All DTOs are `nonisolated` so `JSONDecoder` can build them off the main
//  actor. Money always arrives as integer cents.
//
//  INTEGRATION: field names use snake_case via the decoder's key strategy.
//  Confirm each one against the real MORT schema before writing code.
//

import Foundation

// MARK: - Profile

nonisolated struct ProfileDTO: Codable, Sendable {
    let id: String
    let handle: String
    let displayName: String?
    let role: String
    let area: String?
    let rating: Double?
    let completedJobs: Int?
    let verifications: [String]?
    let memberSince: String?
    let bio: String?
    let guardianLinked: Bool?

    func toDomain() -> MortUser {
        let name = displayName ?? ""
        let initials = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
        return MortUser(
            id: id,
            handle: handle,
            displayName: name,
            role: MortRole(rawValue: role) ?? .teen,
            area: area,
            avatarInitials: initials.isEmpty ? "?" : initials,
            rating: rating,
            completedJobs: completedJobs ?? 0,
            verifications: verifications ?? [],
            memberSince: memberSince ?? "",
            bio: bio,
            guardianLinked: guardianLinked ?? false
        )
    }
}

nonisolated struct ReviewDTO: Codable, Sendable {
    let id: String
    let authorHandle: String
    let authorDisplayName: String
    let rating: Int
    let body: String
    let jobTitle: String
    let createdAt: Date

    func toDomain() -> MortReview {
        MortReview(
            id: id,
            authorHandle: authorHandle,
            authorDisplayName: authorDisplayName,
            rating: rating,
            body: body,
            jobTitle: jobTitle,
            createdAt: createdAt
        )
    }
}


// MARK: - Hosted profile contract

nonisolated struct HostedProfileDTO: Codable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let role: String?
    let city: String?
    let state: String?
    let approximateArea: String?
    let verificationStatus: String?
    let guardianSetupStatus: String?
    let createdAt: Date?
    let bio: String?

    func toDomain() -> MortUser {
        let name = displayName ?? ""
        let initials = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        let handle: String = {
            guard let username, !username.isEmpty else { return "" }
            return username.hasPrefix("@") ? username : "@\(username)"
        }()

        let fallbackArea = [city, state]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
        let resolvedArea = approximateArea?.isEmpty == false
            ? approximateArea
            : (fallbackArea.isEmpty ? nil : fallbackArea)

        let memberSince = createdAt?.formatted(
            .dateTime.month(.abbreviated).year()
        ) ?? ""

        return MortUser(
            id: id,
            handle: handle,
            displayName: name,
            role: MortRole(rawValue: role ?? "") ?? .teen,
            area: resolvedArea,
            avatarInitials: initials.isEmpty ? "?" : initials,
            rating: nil,
            completedJobs: 0,
            verifications: verificationStatus == "approved" ? ["Identity verified"] : [],
            memberSince: memberSince,
            bio: bio,
            guardianLinked: guardianSetupStatus == "linked"
        )
    }
}

nonisolated struct HostedProfileMutationResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let profile: HostedProfileDTO?
}

nonisolated struct HostedAccountDeletionResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
}

// MARK: - Jobs

nonisolated struct JobDTO: Codable, Sendable {
    let id: String
    let title: String
    let category: String
    let details: String
    let baseCents: Int64
    let distance: String?
    let area: String?
    let scheduleText: String?
    let posterHandle: String
    let posterDisplayName: String?
    let workerHandle: String?
    let state: String
    let orderNumber: String?
    let applicantCount: Int?
    let postedAgo: String?
    let requiresProof: Bool?

    func toDomain() -> MortJob {
        MortJob(
            id: id,
            title: title,
            category: category,
            details: details,
            baseCents: baseCents,
            distance: distance ?? "",
            area: area ?? "",
            scheduleText: scheduleText ?? "",
            posterHandle: posterHandle,
            posterDisplayName: posterDisplayName ?? posterHandle,
            workerHandle: workerHandle,
            state: MortJobState(rawValue: state) ?? .open,
            orderNumber: orderNumber,
            applicantCount: applicantCount ?? 0,
            postedAgo: postedAgo ?? "",
            requiresProof: requiresProof ?? false
        )
    }
}

nonisolated struct JobPageDTO: Codable, Sendable {
    let jobs: [JobDTO]
    let nextCursor: String?
}

nonisolated struct ApplicationDTO: Codable, Sendable {
    let id: String
    let jobId: String
    let jobTitle: String
    let applicantHandle: String
    let applicantDisplayName: String?
    let applicantRating: Double?
    let applicantCompletedJobs: Int?
    let message: String
    let state: String
    let submittedAgo: String?

    func toDomain() -> MortApplication {
        MortApplication(
            id: id,
            jobId: jobId,
            jobTitle: jobTitle,
            applicantHandle: applicantHandle,
            applicantDisplayName: applicantDisplayName ?? applicantHandle,
            applicantRating: applicantRating,
            applicantCompletedJobs: applicantCompletedJobs ?? 0,
            message: message,
            state: MortApplication.State(rawValue: state) ?? .submitted,
            submittedAgo: submittedAgo ?? ""
        )
    }
}


/// Hosted application row used by PostgREST and submit_job_application.
nonisolated struct HostedApplicationDTO: Codable, Sendable {
    nonisolated struct JobSummary: Codable, Sendable {
        let title: String?
    }

    nonisolated struct ApplicantSummary: Codable, Sendable {
        let username: String?
        let displayName: String?
    }

    let id: String
    let jobId: String
    let teenId: String?
    let status: String
    let note: String?
    let createdAt: Date?
    let updatedAt: Date?
    let jobs: JobSummary?
    let applicant: ApplicantSummary?

    func toDomain() -> MortApplication {
        let username = applicant?.username ?? ""
        let handle = username.isEmpty
            ? ""
            : (username.hasPrefix("@") ? username : "@\(username)")
        let displayName = applicant?.displayName ?? handle

        let mappedState: MortApplication.State = switch status {
        case "viewed":
            .viewed
        case "accepted", "in_progress", "proof_submitted",
             "completion_pending_release", "completed", "disputed":
            .accepted
        case "rejected", "guardian_rejected":
            .declined
        case "withdrawn":
            .withdrawn
        case "canceled":
            .expired
        default:
            .submitted
        }

        let submittedAgo: String = {
            guard let createdAt else { return "" }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: createdAt, relativeTo: Date())
        }()

        return MortApplication(
            id: id,
            jobId: jobId,
            jobTitle: jobs?.title ?? "",
            applicantHandle: handle,
            applicantDisplayName: displayName,
            applicantRating: nil,
            applicantCompletedJobs: 0,
            message: note ?? "",
            state: mappedState,
            submittedAgo: submittedAgo
        )
    }
}

nonisolated struct HostedApplicationSubmitResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let application: HostedApplicationDTO?
}

nonisolated struct HostedApplicationTransitionResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
}


/// Minimal participant-visible application reference used for job execution.
nonisolated struct HostedExecutionApplicationRefDTO: Codable, Sendable {
    let id: String
    let status: String
    let updatedAt: Date?
}

nonisolated struct HostedStartPinResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let startPin: String?
    let expiresAt: Date?
}

nonisolated struct HostedStartConfirmationResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
}

nonisolated struct PinDTO: Codable, Sendable {
    let pin: String
}

nonisolated struct FairPayPolicyDTO: Codable, Sendable {
    let recommendedLowCents: Int64
    let recommendedHighCents: Int64
    let hardMinimumCents: Int64
    let jobTypeLabel: String

    func toDomain() -> FairPayPolicy {
        FairPayPolicy(
            recommendedLowCents: recommendedLowCents,
            recommendedHighCents: recommendedHighCents,
            hardMinimumCents: hardMinimumCents,
            jobTypeLabel: jobTypeLabel
        )
    }
}

// MARK: - Payments

nonisolated struct QuoteDTO: Codable, Sendable {
    let jobId: String
    let jobTitle: String
    let workerHandle: String
    let orderNumber: String
    let baseCents: Int64
    let feeCents: Int64
    let totalCents: Int64
    let feeExplanation: String?
    let expiresAt: Date
    let method: MethodDTO?

    func toDomain() -> PaymentQuote {
        PaymentQuote(
            jobId: jobId,
            jobTitle: jobTitle,
            workerHandle: workerHandle,
            orderNumber: orderNumber,
            baseCents: baseCents,
            feeCents: feeCents,
            totalCents: totalCents,
            feeExplanation: feeExplanation ?? "",
            expiresAt: expiresAt,
            method: method?.toDomain()
        )
    }
}

nonisolated struct MethodDTO: Codable, Sendable {
    let id: String
    let label: String
    let mask: String
    let symbol: String?
    let isDefault: Bool?
    let isUsable: Bool?

    func toDomain() -> PaymentMethodRef {
        PaymentMethodRef(
            id: id,
            label: label,
            mask: mask,
            symbol: symbol ?? "creditcard",
            isDefault: isDefault ?? false,
            isUsable: isUsable ?? true
        )
    }
}

/// Provider intent material. The client secret is held in memory only and is
/// never persisted or logged.
nonisolated struct IntentDTO: Codable, Sendable {
    let clientSecret: String
    let publishableKey: String
    let customerEphemeralKeySecret: String?
    let customerId: String?
    let applePayMerchantId: String?
    /// Optional backend-side terminal state (e.g. duplicate blocked).
    let state: String?
}

nonisolated struct PaymentStatusDTO: Codable, Sendable {
    let state: String
    let reason: String?
}

nonisolated struct FeeConfigDTO: Codable, Sendable {
    let percentBasisPoints: Int
    let minimumCents: Int64
    let maximumCents: Int64

    func toDomain() -> MortFeeConfig {
        MortFeeConfig(
            percentBasisPoints: percentBasisPoints,
            minimumCents: minimumCents,
            maximumCents: maximumCents
        )
    }
}

nonisolated struct TipConfigDTO: Codable, Sendable {
    let minimumCents: Int64
    let maximumCents: Int64

    func toDomain() -> TipConfig {
        TipConfig(minimumCents: minimumCents, maximumCents: maximumCents)
    }
}

nonisolated struct SettlementDTO: Codable, Sendable {
    let jobId: String
    let orderNumber: String
    let fundedBaseCents: Int64
    let compensatedBaseCents: Int64
    let feeRetainedCents: Int64
    let feeRefundedCents: Int64
    let adultRefundCents: Int64
    let outcome: String
    let explanation: String

    func toDomain() -> SettlementResult {
        SettlementResult(
            jobId: jobId,
            orderNumber: orderNumber,
            fundedBaseCents: fundedBaseCents,
            compensatedBaseCents: compensatedBaseCents,
            feeRetainedCents: feeRetainedCents,
            feeRefundedCents: feeRefundedCents,
            adultRefundCents: adultRefundCents,
            outcome: SettlementResult.Outcome(rawValue: outcome) ?? .processing,
            explanation: explanation
        )
    }
}

// MARK: - Receipts

nonisolated struct ReceiptRowDTO: Codable, Sendable {
    let id: String
    let label: String
    let value: String

    func toDomain() -> ReceiptRow {
        ReceiptRow(id: id, label: label, value: value)
    }
}

nonisolated struct ReceiptLineDTO: Codable, Sendable {
    let id: String
    let label: String
    let amountCents: Int64?
    let emphasis: String
    let note: String?

    func toDomain() -> ReceiptLine {
        ReceiptLine(
            id: id,
            label: label,
            amountCents: amountCents,
            emphasis: ReceiptLine.Emphasis(rawValue: emphasis) ?? .normal,
            note: note
        )
    }
}

nonisolated struct ReceiptLinkDTO: Codable, Sendable {
    let id: String
    let title: String
    let rows: [ReceiptRowDTO]
    let status: String

    func toDomain() -> ReceiptLink {
        ReceiptLink(
            id: id,
            title: title,
            rows: rows.map { $0.toDomain() },
            status: status
        )
    }
}

nonisolated struct ReceiptDTO: Codable, Sendable {
    let id: String
    let type: String
    let orderNumber: String
    let issuedAt: Date
    let identityRows: [ReceiptRowDTO]
    let serviceTitle: String
    let serviceLines: [String]
    let lines: [ReceiptLineDTO]
    let statusTone: String
    let statusLabel: String
    let statusSub: String?
    let methodLabel: String?
    let methodMask: String?
    let referenceRows: [ReceiptRowDTO]
    let links: [ReceiptLinkDTO]?
    let privacyNote: String?
    let notATaxDocumentNote: String?

    func toDomain() -> Receipt {
        Receipt(
            id: id,
            type: ReceiptType(rawValue: type) ?? .adultJobPayment,
            orderNumber: orderNumber,
            issuedAt: issuedAt,
            identityRows: identityRows.map { $0.toDomain() },
            serviceTitle: serviceTitle,
            serviceLines: serviceLines,
            lines: lines.map { $0.toDomain() },
            statusTone: MortTone(rawValue: statusTone) ?? .neutral,
            statusLabel: statusLabel,
            statusSub: statusSub,
            methodLabel: methodLabel,
            methodMask: methodMask,
            referenceRows: referenceRows.map { $0.toDomain() },
            links: links?.map { $0.toDomain() } ?? [],
            privacyNote: privacyNote ?? "",
            notATaxDocumentNote: notATaxDocumentNote
        )
    }
}

nonisolated struct ReceiptPageDTO: Codable, Sendable {
    let receipts: [ReceiptDTO]
    let nextCursor: String?
}

// MARK: - Payouts

nonisolated struct PayoutDTO: Codable, Sendable {
    let id: String
    let stage: String
    let amountCents: Int64
    let relatedReceiptNumber: String?
    let updatedAt: Date
    let destinationMask: String?
    let expectedText: String?

    func toDomain() -> PayoutStatus {
        PayoutStatus(
            id: id,
            stage: PayoutStage(rawValue: stage) ?? .setupRequired,
            amountCents: amountCents,
            relatedReceiptNumber: relatedReceiptNumber,
            updatedAt: updatedAt,
            destinationMask: destinationMask,
            expectedText: expectedText
        )
    }
}

nonisolated struct PayoutStageDTO: Codable, Sendable {
    let stage: String
}

nonisolated struct OnboardingLinkDTO: Codable, Sendable {
    let url: String
}

// MARK: - History

nonisolated struct HistoryRecordDTO: Codable, Sendable {
    let id: String
    let kind: String
    let title: String
    let counterpartyHandle: String
    let amountCents: Int64
    let occurredAt: Date
    let statusLabel: String
    let statusTone: String
    let statusSymbol: String?
    let receiptNumber: String?
    let orderNumber: String?
    let noReceiptIssued: Bool?
    let jobId: String?

    func toDomain() -> HistoryRecord {
        let kindValue = HistoryKind(rawValue: kind) ?? .job
        return HistoryRecord(
            id: id,
            kind: kindValue,
            title: title,
            counterpartyHandle: counterpartyHandle,
            amountCents: amountCents,
            occurredAt: occurredAt,
            statusLabel: statusLabel,
            statusTone: MortTone(rawValue: statusTone) ?? .neutral,
            statusSymbol: statusSymbol ?? kindValue.symbol,
            receiptNumber: receiptNumber,
            orderNumber: orderNumber,
            noReceiptIssued: noReceiptIssued ?? false,
            jobId: jobId
        )
    }
}

nonisolated struct HistoryPageDTO: Codable, Sendable {
    let records: [HistoryRecordDTO]
    let nextCursor: String?
}

nonisolated struct YearsDTO: Codable, Sendable {
    let years: [Int]
}

nonisolated struct ExportStateDTO: Codable, Sendable {
    let state: String
}

nonisolated struct ExportFileDTO: Codable, Sendable {
    let url: String
}

// MARK: - Messaging

nonisolated struct ConversationDTO: Codable, Sendable {
    let id: String
    let counterpartyHandle: String
    let counterpartyDisplayName: String?
    let preview: String
    let updatedAt: Date
    let unreadCount: Int?
    let jobTitle: String
    let jobId: String
    let restriction: String?

    func toDomain() -> MortConversation {
        let name = counterpartyDisplayName ?? counterpartyHandle
        let initials = name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()
        return MortConversation(
            id: id,
            counterpartyHandle: counterpartyHandle,
            counterpartyDisplayName: name,
            counterpartyInitials: initials.isEmpty ? "?" : initials,
            preview: preview,
            updatedAt: updatedAt,
            unreadCount: unreadCount ?? 0,
            jobTitle: jobTitle,
            jobId: jobId,
            restriction: ConversationRestriction(rawValue: restriction ?? "none") ?? .none
        )
    }
}

nonisolated struct MessageDTO: Codable, Sendable {
    let id: String
    let conversationId: String
    let authorHandle: String
    let authorDisplayName: String?
    let body: String
    let sentAt: Date
    let fromMe: Bool
    let delivery: String?
    let attachmentName: String?

    func toDomain() -> MortMessage {
        MortMessage(
            id: id,
            conversationId: conversationId,
            authorHandle: authorHandle,
            authorDisplayName: authorDisplayName ?? authorHandle,
            body: body,
            sentAt: sentAt,
            fromMe: fromMe,
            delivery: MessageDelivery(rawValue: delivery ?? "sent") ?? .sent,
            attachmentName: attachmentName
        )
    }
}

nonisolated struct MessagePageDTO: Codable, Sendable {
    let messages: [MessageDTO]
    let nextCursor: String?
}


// MARK: - Hosted messaging contract

nonisolated struct HostedMessageThreadPageDTO: Codable, Sendable {
    nonisolated struct Cursor: Codable, Sendable {
        let updatedAt: Date
        let id: String
    }

    let items: [HostedMessageThreadDTO]
    let hasMore: Bool
    let nextCursor: Cursor?
}

nonisolated struct HostedMessageThreadDTO: Codable, Sendable {
    let id: String
    let jobId: String?
    let lifecycleStatus: String
    let updatedAt: Date
    let jobTitle: String?
    let counterpartyId: String?
    let counterpartyDisplayName: String?
    let lastMessagePreview: String?
    let lastMessageAt: Date?
    let unreadCount: Int
}

nonisolated struct HostedThreadMessagesPageDTO: Codable, Sendable {
    nonisolated struct Cursor: Codable, Sendable {
        let createdAt: Date
        let id: String
    }

    let items: [HostedMessageRowDTO]
    let hasMore: Bool
    let lifecycleStatus: String?
    let thread: HostedMessageThreadDTO?
    let nextCursor: Cursor?
}

nonisolated struct HostedMessageRowDTO: Codable, Sendable {
    let id: String
    let threadId: String
    let senderId: String
    let body: String
    let scannerStatus: String?
    let createdAt: Date

    func toDomain(
        currentUserId: String,
        counterpartyHandle: String,
        counterpartyDisplayName: String
    ) -> MortMessage {
        let fromMe = senderId == currentUserId
        let visibleBody = scannerStatus == "blocked" ? "Blocked by MORT safety scanner." : body
        return MortMessage(
            id: id,
            conversationId: threadId,
            authorHandle: fromMe ? "" : counterpartyHandle,
            authorDisplayName: fromMe ? "You" : counterpartyDisplayName,
            body: visibleBody,
            sentAt: createdAt,
            fromMe: fromMe,
            delivery: .sent,
            attachmentName: nil
        )
    }
}

nonisolated struct HostedUsernameDTO: Codable, Sendable {
    let id: String
    let username: String?
}

nonisolated struct HostedMutationAckDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
}

// MARK: - Safety / Support / Notifications / Guardian

nonisolated struct CheckInDTO: Codable, Sendable {
    let id: String
    let jobId: String
    let jobTitle: String
    let state: String
    let dueAt: Date?
    let confirmedAt: Date?

    func toDomain() -> SafetyCheckIn {
        SafetyCheckIn(
            id: id,
            jobId: jobId,
            jobTitle: jobTitle,
            state: CheckInState(rawValue: state) ?? .notStarted,
            dueAt: dueAt,
            confirmedAt: confirmedAt
        )
    }
}

nonisolated struct SafetyContactDTO: Codable, Sendable {
    let id: String
    let displayName: String
    let relationship: String
    let contactMask: String
    let isGuardian: Bool?
    let isNotifiedOnJobs: Bool?

    func toDomain() -> SafetyContact {
        SafetyContact(
            id: id,
            displayName: displayName,
            relationship: relationship,
            contactMask: contactMask,
            isGuardian: isGuardian ?? false,
            isNotifiedOnJobs: isNotifiedOnJobs ?? false
        )
    }
}

nonisolated struct SupportCaseDTO: Codable, Sendable {
    let id: String
    let subject: String
    let state: String
    let updatedAt: Date
    let lastMessagePreview: String?
    let withHumanAgent: Bool?
    let reference: String?

    func toDomain() -> SupportCase {
        SupportCase(
            id: id,
            subject: subject,
            state: SupportCaseState(rawValue: state) ?? .open,
            updatedAt: updatedAt,
            lastMessagePreview: lastMessagePreview ?? "",
            withHumanAgent: withHumanAgent ?? false,
            reference: reference
        )
    }
}

nonisolated struct NotificationDTO: Codable, Sendable {
    let id: String
    let category: String
    let title: String
    let body: String
    let receivedAt: Date
    let isRead: Bool?
    let route: String?

    func toDomain() -> MortNotification {
        MortNotification(
            id: id,
            category: NotificationCategory(rawValue: category) ?? .system,
            title: title,
            body: body,
            receivedAt: receivedAt,
            isRead: isRead ?? false,
            route: route
        )
    }
}

nonisolated struct GuardianSummaryDTO: Codable, Sendable {
    let teenHandle: String
    let teenDisplayName: String?
    let activeJobCount: Int?
    let upcomingJobTitle: String?
    let lastCheckInState: String?
    let lastCheckInText: String?
    let earningsThisMonthCents: Int64?
    let payoutStage: String?
    let safetyAlertsCount: Int?
    let restrictedNotice: String?

    func toDomain() -> GuardianSummary {
        GuardianSummary(
            teenHandle: teenHandle,
            teenDisplayName: teenDisplayName ?? teenHandle,
            activeJobCount: activeJobCount ?? 0,
            upcomingJobTitle: upcomingJobTitle,
            lastCheckInState: CheckInState(rawValue: lastCheckInState ?? "notStarted") ?? .notStarted,
            lastCheckInText: lastCheckInText ?? "",
            earningsThisMonthCents: earningsThisMonthCents ?? 0,
            payoutStage: PayoutStage(rawValue: payoutStage ?? "setupRequired") ?? .setupRequired,
            safetyAlertsCount: safetyAlertsCount ?? 0,
            restrictedNotice: restrictedNotice
                ?? "Message contents, exact locations and full payment details stay private to your teen."
        )
    }
}
