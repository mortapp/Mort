//
//  HostedDTOs.swift
//  MORT iOS V8
//
//  Wire models for the real hosted MORT Supabase contracts. Keep these
//  separate from the original Rork handoff DTOs so migrations are explicit
//  and reviewable.
//

import Foundation

nonisolated struct HostedProfileDTO: Codable, Sendable {
    let id: String
    let role: String?
    let displayName: String?
    let city: String?
    let state: String?
    let createdAt: Date?
    let updatedAt: Date?
    let username: String?
    let guardianSetupStatus: String?
    let verificationStatus: String?
    let bio: String?
    let preferredJobCategories: [String]?
    let approximateArea: String?

    func toDomain() -> MortUser {
        let cleanUsername = username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let handle = cleanUsername.map { "@\($0)" } ?? ""

        let display = displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDisplay = (display?.isEmpty == false) ? display! : handle

        let area: String? = {
            if let approximateArea {
                let value = approximateArea.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            let cityValue = city?.trimmingCharacters(in: .whitespacesAndNewlines)
            let stateValue = state?.trimmingCharacters(in: .whitespacesAndNewlines)
            switch (cityValue, stateValue) {
            case let (.some(city), .some(state)) where !city.isEmpty && !state.isEmpty:
                return "\(city), \(state)"
            case let (.some(city), _) where !city.isEmpty:
                return city
            case let (_, .some(state)) where !state.isEmpty:
                return state
            default:
                return nil
            }
        }()

        let initials = safeDisplay
            .split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map(String.init)
            .joined()
            .uppercased()

        let memberSince = createdAt.map {
            String(Calendar(identifier: .gregorian).component(.year, from: $0))
        } ?? ""

        return MortUser(
            id: id,
            handle: handle,
            displayName: safeDisplay,
            // Unknown / legacy roles fail toward the least-privileged client UX.
            // The backend remains authoritative for every permitted action.
            role: role.flatMap(MortRole.init(rawValue:)) ?? .teen,
            area: area,
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

nonisolated struct HostedProfileUpdateResponseDTO: Codable, Sendable {
    let ok: Bool
    let replayed: Bool?
    let code: String?
    let profile: HostedProfileDTO?
}


nonisolated struct HostedAccountDeletionResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
}



// MARK: - Hosted marketplace feed

nonisolated enum HostedWireContractError: Error, Sendable {
    case unexpectedJobState(String)
    case invalidJobPay
}

nonisolated struct HostedJobCursorDTO: Codable, Sendable {
    let value: String
    let id: String

    var opaqueValue: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init(value: String, id: String) {
        self.value = value
        self.id = id
    }

    init?(opaqueValue: String) {
        guard !opaqueValue.isEmpty else { return nil }
        var base64 = opaqueValue
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard
            let data = Data(base64Encoded: base64),
            let decoded = try? JSONDecoder().decode(Self.self, from: data),
            UUID(uuidString: decoded.id) != nil,
            !decoded.value.isEmpty
        else { return nil }
        self = decoded
    }
}

nonisolated struct HostedJobFeedPageDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let items: [HostedJobFeedItemDTO]
    let hasMore: Bool
    let nextCursor: HostedJobCursorDTO?
    let distanceCalculated: Bool?
    let locationPrecision: String?

    private enum CodingKeys: String, CodingKey {
        case ok, code, items, hasMore, nextCursor, distanceCalculated, locationPrecision
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        ok = try box.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        code = try box.decodeIfPresent(String.self, forKey: .code)
        items = try box.decodeIfPresent([HostedJobFeedItemDTO].self, forKey: .items) ?? []
        hasMore = try box.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        nextCursor = try box.decodeIfPresent(HostedJobCursorDTO.self, forKey: .nextCursor)
        distanceCalculated = try box.decodeIfPresent(Bool.self, forKey: .distanceCalculated)
        locationPrecision = try box.decodeIfPresent(String.self, forKey: .locationPrecision)
    }
}

nonisolated struct HostedJobFeedPosterDTO: Codable, Sendable {
    let displayName: String?
    let verificationStatus: String?
    let avatarPath: String?
}

nonisolated struct HostedJobFeedItemDTO: Codable, Sendable {
    let id: String
    let posterId: String
    let title: String
    let description: String?
    let summary: String?
    let category: String
    let locationText: String?
    let city: String?
    let state: String?
    let neighborhood: String?
    let payAmountCents: Int64?
    let status: String
    let startsAt: Date?
    let createdAt: Date
    let proofExpected: Bool?
    let scheduleType: String?
    let profiles: HostedJobFeedPosterDTO?
    let distanceStatus: String?
    let matchExplanation: String?

    func toDomain() throws -> MortJob {
        guard status == "open" else {
            throw HostedWireContractError.unexpectedJobState(status)
        }
        guard let payAmountCents, payAmountCents > 0 else {
            throw HostedWireContractError.invalidJobPay
        }

        let cleanNeighborhood = neighborhood?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCity = city?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanState = state?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = locationText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let area: String = {
            if let cleanNeighborhood, !cleanNeighborhood.isEmpty { return cleanNeighborhood }
            if let cleanCity, !cleanCity.isEmpty, let cleanState, !cleanState.isEmpty {
                return "\(cleanCity), \(cleanState)"
            }
            if let cleanCity, !cleanCity.isEmpty { return cleanCity }
            if let cleanState, !cleanState.isEmpty { return cleanState }
            if let cleanLocation, !cleanLocation.isEmpty { return cleanLocation }
            return "General area"
        }()

        let scheduleText: String = {
            if let startsAt {
                return startsAt.formatted(
                    .dateTime
                        .month(.abbreviated)
                        .day()
                        .hour()
                        .minute()
                )
            }
            switch scheduleType {
            case "flexible": return "Flexible"
            case "exact": return "Scheduled time"
            default: return "Schedule in job details"
            }
        }()

        let distance: String = {
            switch distanceStatus {
            case "unavailable", nil: return "Distance unavailable"
            default:
                return distanceStatus?
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized ?? "Distance unavailable"
            }
        }()

        let detailText = {
            let description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let description, !description.isEmpty { return description }
            let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (summary?.isEmpty == false) ? summary! : "See job details."
        }()

        let display = profiles?.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return MortJob(
            id: id,
            title: title,
            category: category,
            details: detailText,
            baseCents: payAmountCents,
            distance: distance,
            area: area,
            scheduleText: scheduleText,
            posterHandle: "",
            posterDisplayName: (display?.isEmpty == false) ? display! : "MORT member",
            workerHandle: nil,
            state: .open,
            orderNumber: nil,
            applicantCount: 0,
            postedAgo: createdAt.formatted(.dateTime.month(.abbreviated).day()),
            requiresProof: proofExpected ?? false
        )
    }
}


// MARK: - Hosted Payment OS

nonisolated struct HostedJobContractDTO: Codable, Sendable {
    let id: String
    let jobId: String
    let teenId: String?
    let adultId: String?
    let status: String
    let activeVersionId: String?
}

nonisolated struct HostedPaymentJobDTO: Codable, Sendable {
    let id: String
    let title: String
}

nonisolated struct HostedPaymentCounterpartyDTO: Codable, Sendable {
    let id: String
    let username: String?
    let displayName: String?

    var safeDisplayHandle: String {
        if let username {
            let clean = username
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            if !clean.isEmpty { return "@\(clean)" }
        }
        if let displayName {
            let clean = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return "Worker"
    }
}

nonisolated struct HostedFundingQuoteResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let quoteId: String?
    let contractId: String?
    let basePayCents: Int64?
    let serviceFeeCents: Int64?
    let authoritativeTotalCents: Int64?
    let currencyCode: String?
    let fairPayDecision: String?
    let state: String?
    let createdAt: Date?
    let expiresAt: Date?
    let idempotent: Bool?
}

nonisolated struct HostedPaymentIntentResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    /// Internal MORT payment-intent row id returned by the hosted function.
    let paymentIntentId: String?
    let paymentAttemptId: String?
    let environment: String?
    let publishableKey: String?
    let paymentIntentClientSecret: String?
    let customerId: String?
    let customerEphemeralKeySecret: String?
    let basePayCents: Int64?
    let serviceFeeCents: Int64?
    let totalAmountCents: Int64?
    let currencyCode: String?

    var providerPaymentIntentId: String? {
        guard
            let secret = paymentIntentClientSecret,
            let range = secret.range(of: "_secret_")
        else { return nil }
        let providerId = String(secret[..<range.lowerBound])
        return providerId.hasPrefix("pi_") ? providerId : nil
    }
}

nonisolated struct HostedPaymentAttemptStateDTO: Codable, Sendable {
    let paymentIntentId: String
    let state: String
    let legacyStatus: String?
    let providerConfirmedAt: Date?
    let lastReconciledAt: Date?

    var paymentState: PaymentState {
        HostedPaymentStateMapper.normalized(state)
    }
}

nonisolated struct HostedJobPaymentSummaryDTO: Codable, Sendable {
    let contractId: String
    let obligationStatus: String?
    let earningsAmountCents: Int64?
    let currencyCode: String?
    let fundingStatus: String
    let serviceFeeCents: Int64?
    let totalAmountCents: Int64?
    let refundedAmountCents: Int64?
    let transferStatus: String?
    let disputeActive: Bool?
    let provider: String?
    let payoutDepositConfirmed: Bool?

    var paymentState: PaymentState {
        HostedPaymentStateMapper.legacyFundingStatus(fundingStatus)
    }
}


nonisolated struct HostedServiceFeePolicyDTO: Codable, Sendable {
    let version: String?
    let percentBasisPoints: Int
    let minimumCents: Int64
    let maximumCents: Int64
    let quoteTtlSeconds: Int?

    func toDomain() -> MortFeeConfig {
        MortFeeConfig(
            percentBasisPoints: percentBasisPoints,
            minimumCents: minimumCents,
            maximumCents: maximumCents
        )
    }
}

nonisolated struct HostedTipPolicyDTO: Codable, Sendable {
    let version: String?
    let minimumCents: Int64
    let maximumCents: Int64
    let lateTipWindowSeconds: Int?
    let teenShareBasisPoints: Int?
    let mortFeeBasisPoints: Int?
    let excludedFromFairPay: Bool?

    func toDomain() throws -> TipConfig {
        guard
            minimumCents > 0,
            maximumCents >= minimumCents,
            teenShareBasisPoints == 10_000,
            mortFeeBasisPoints == 0,
            excludedFromFairPay == true
        else {
            throw MortError.serverUnavailable
        }
        return TipConfig(minimumCents: minimumCents, maximumCents: maximumCents)
    }
}

nonisolated struct HostedFinancialPolicyConfigDTO: Codable, Sendable {
    let ok: Bool
    let environment: String
    let currencyCode: String
    let serviceFee: HostedServiceFeePolicyDTO?
    let tip: HostedTipPolicyDTO?
}

nonisolated struct HostedJobSettlementDTO: Codable, Sendable {
    let ok: Bool
    let settlementId: String
    let contractId: String
    let jobId: String
    let orderNumber: String?
    let fundedBaseCents: Int64
    let compensatedBaseCents: Int64
    let baseRefundCents: Int64
    let serviceFeeCents: Int64
    let serviceFeeRefundCents: Int64
    let feeRetainedCents: Int64
    let adultRefundCents: Int64
    let currencyCode: String
    let outcomeCode: String
    let decisionReasonCode: String
    let finalizedAt: Date?
    let explanation: String

    func toDomain() throws -> SettlementResult {
        guard
            fundedBaseCents >= 0,
            compensatedBaseCents >= 0,
            baseRefundCents >= 0,
            compensatedBaseCents + baseRefundCents == fundedBaseCents,
            serviceFeeCents >= 0,
            serviceFeeRefundCents >= 0,
            serviceFeeRefundCents <= serviceFeeCents,
            feeRetainedCents == serviceFeeCents - serviceFeeRefundCents,
            adultRefundCents == baseRefundCents + serviceFeeRefundCents
        else {
            throw MortError.serverUnavailable
        }

        let outcome: SettlementResult.Outcome
        if adultRefundCents == 0 {
            outcome = .settledInFull
        } else if compensatedBaseCents == 0 {
            outcome = .settledWithRefund
        } else {
            outcome = .settledWithРartialRefund
        }

        return SettlementResult(
            jobId: jobId,
            orderNumber: orderNumber ?? "—",
            fundedBaseCents: fundedBaseCents,
            compensatedBaseCents: compensatedBaseCents,
            feeRetainedCents: feeRetainedCents,
            feeRefundedCents: serviceFeeRefundCents,
            adultRefundCents: adultRefundCents,
            outcome: outcome,
            explanation: explanation
        )
    }
}

nonisolated struct HostedTipPaymentIntentResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let tipAttemptId: String?
    let providerPaymentIntentId: String?
    let normalizedState: String?
    let environment: String?
    let publishableKey: String?
    let paymentIntentClientSecret: String?
    let customerId: String?
    let amountCents: Int64?
    let teenAmountCents: Int64?
    let mortFeeCents: Int64?
    let currencyCode: String?
}

nonisolated struct HostedTipAttemptStateDTO: Codable, Sendable {
    let tipAttemptId: String
    let settlementId: String
    let jobId: String
    let amountCents: Int64
    let teenAmountCents: Int64
    let mortFeeCents: Int64
    let currencyCode: String
    let state: String
    let updatedAt: Date

    var paymentState: PaymentState {
        HostedPaymentStateMapper.normalized(state)
    }
}

nonisolated enum HostedPaymentStateMapper {
    static func normalized(_ raw: String) -> PaymentState {
        switch raw.uppercased() {
        case "READY": .ready
        case "PROCESSING": .processing
        case "REQUIRES_ACTION": .requiresAction
        case "PENDING": .pending
        case "SUCCEEDED": .funded
        case "DECLINED": .declined
        case "CANCELLED": .cancelled
        case "PROVIDER_UNAVAILABLE": .providerUnavailable
        case "DUPLICATE_BLOCKED": .duplicateBlocked
        case "FAILED", "UNKNOWN": .unknown
        default: .unknown
        }
    }

    static func legacyFundingStatus(_ raw: String) -> PaymentState {
        switch raw.lowercased() {
        case "funded", "transfer_pending", "transferred", "refund_pending",
             "partially_refunded", "refunded", "closed":
            .funded
        case "requires_action":
            .requiresAction
        case "processing":
            .processing
        case "requires_payment_method", "unfunded":
            .ready
        case "canceled":
            .cancelled
        case "funding_failed", "disputed", "chargeback":
            .unknown
        default:
            .unknown
        }
    }
}


// MARK: - Hosted job records / mutations

nonisolated struct HostedJobRecordDTO: Codable, Sendable {
    let id: String
    let posterId: String
    let title: String
    let summary: String?
    let description: String?
    let category: String
    let locationText: String?
    let city: String?
    let state: String?
    let neighborhood: String?
    let payAmountCents: Int64?
    let status: String
    let startsAt: Date?
    let createdAt: Date
    let updatedAt: Date?
    let proofExpected: Bool?
    let scheduleType: String?
    let applicationsOpen: Bool?

    func toDomain(
        posterHandle: String = "",
        posterDisplayName: String = "MORT member"
    ) throws -> MortJob {
        guard let payAmountCents, payAmountCents > 0 || status == "draft" else {
            throw HostedWireContractError.invalidJobPay
        }

        let area: String = {
            if let neighborhood {
                let value = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            let cityValue = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stateValue = state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !cityValue.isEmpty && !stateValue.isEmpty { return "\(cityValue), \(stateValue)" }
            if !cityValue.isEmpty { return cityValue }
            if !stateValue.isEmpty { return stateValue }
            if let locationText {
                let value = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return "General area"
        }()

        let details: String = {
            if let description {
                let value = description.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            if let summary {
                let value = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
            return "See job details."
        }()

        let scheduleText: String = {
            if let startsAt {
                return startsAt.formatted(
                    .dateTime.month(.abbreviated).day().hour().minute()
                )
            }
            return scheduleType == "flexible" ? "Flexible" : "Schedule in job details"
        }()

        return MortJob(
            id: id,
            title: title,
            category: category,
            details: details,
            baseCents: max(payAmountCents, 0),
            distance: "Distance unavailable",
            area: area,
            scheduleText: scheduleText,
            posterHandle: posterHandle,
            posterDisplayName: posterDisplayName,
            workerHandle: nil,
            state: Self.domainState(status),
            orderNumber: nil,
            applicantCount: 0,
            postedAgo: createdAt.formatted(.dateTime.month(.abbreviated).day()),
            requiresProof: proofExpected ?? false
        )
    }

    private static func domainState(_ raw: String) -> MortJobState {
        switch raw {
        case "draft", "pending_review":
            return .draft
        case "open", "paused":
            return .open
        case "filled", "assigned":
            return .accepted
        case "in_progress":
            return .inProgress
        case "proof_submitted", "completion_pending_release":
            return .awaitingCompletion
        case "completed", "closed":
            return .completed
        case "canceled", "cancelled", "expired", "rejected", "removed":
            return .cancelled
        default:
            return .draft
        }
    }
}

nonisolated struct HostedJobMutationResponseDTO: Codable, Sendable {
    let ok: Bool
    let code: String?
    let created: Bool?
    let published: Bool?
    let deleted: Bool?
    let job: HostedJobRecordDTO?
}

// MARK: - Hosted immutable financial documents

nonisolated struct HostedFinancialSnapshotDTO: Codable, Sendable {
    let jobTitle: String?
    let displayUsername: String?
    let counterpartyHandle: String?
    let workerHandle: String?
    let adultHandle: String?
    let serviceDescription: String?
    let methodLabel: String?
    let methodMask: String?
    let statusSub: String?
}

nonisolated struct HostedFinancialDocumentDTO: Codable, Sendable {
    let id: String
    let documentType: String
    let receiptId: String
    let orderNumber: String
    let documentDate: String
    let amountCents: Int64
    let currencyCode: String
    let status: String
    let maskedProviderReference: String?
    let immutableSnapshot: HostedFinancialSnapshotDTO?
    let linkedDocumentRefs: [String]?
    let createdAt: Date

    var receiptType: ReceiptType {
        switch documentType.uppercased() {
        case "ADULT_JOB_PAYMENT": return .adultJobPayment
        case "TEEN_EARNINGS": return .teenEarnings
        case "STORE_PURCHASE": return .storePurchase
        case "TIP": return .lateTip
        case "FULL_REFUND": return .fullRefund
        case "PARTIAL_REFUND": return .partialRefund
        case "ADJUSTMENT": return .adjustment
        case "REVERSAL": return .reversal
        default: return .adjustment
        }
    }

    var historyKind: HistoryKind {
        switch documentType.uppercased() {
        case "ADULT_JOB_PAYMENT": return .payment
        case "TEEN_EARNINGS": return .earning
        case "STORE_PURCHASE": return .storePurchase
        case "TIP": return .tip
        case "FULL_REFUND", "PARTIAL_REFUND": return .refund
        case "REVERSAL", "ADJUSTMENT": return .adjustment
        default: return .adjustment
        }
    }

    var displayTitle: String {
        if let title = immutableSnapshot?.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return receiptType.documentTitle
    }

    var displayCounterparty: String {
        let values = [
            immutableSnapshot?.counterpartyHandle,
            immutableSnapshot?.displayUsername,
            immutableSnapshot?.workerHandle,
            immutableSnapshot?.adultHandle,
        ]
        for value in values {
            if let value {
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    return clean.hasPrefix("@") ? clean : "@\(clean)"
                }
            }
        }
        return ""
    }

    var signedHistoryAmountCents: Int64 {
        switch documentType.uppercased() {
        case "ADULT_JOB_PAYMENT", "STORE_PURCHASE":
            return -amountCents
        case "TEEN_EARNINGS", "TIP", "FULL_REFUND", "PARTIAL_REFUND", "ADJUSTMENT", "REVERSAL":
            return amountCents
        default:
            return amountCents
        }
    }

    var statusTone: MortTone {
        switch status.lowercased() {
        case "succeeded": return .success
        case "pending": return .warning
        case "failed": return .danger
        case "refunded", "reversed", "adjusted": return .info
        default: return .neutral
        }
    }

    var statusLabel: String {
        status.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    func toHistoryRecord() -> HistoryRecord {
        HistoryRecord(
            id: id,
            kind: historyKind,
            title: displayTitle,
            counterpartyHandle: displayCounterparty,
            amountCents: signedHistoryAmountCents,
            occurredAt: createdAt,
            statusLabel: statusLabel,
            statusTone: statusTone,
            statusSymbol: historyKind.symbol,
            receiptNumber: receiptId,
            orderNumber: orderNumber,
            noReceiptIssued: false,
            jobId: nil
        )
    }

    func toReceipt() -> Receipt {
        let amountLabel: String = {
            switch receiptType {
            case .adultJobPayment: return "TOTAL FUNDED"
            case .teenEarnings: return "EARNINGS CREDITED"
            case .storePurchase: return "TOTAL"
            case .lateTip: return "TIP"
            case .fullRefund, .partialRefund: return "REFUND"
            case .adjustment: return "ADJUSTMENT"
            case .reversal: return "REVERSAL"
            }
        }()

        let identityRows: [ReceiptRow] = {
            guard !displayCounterparty.isEmpty else { return [] }
            return [ReceiptRow(id: "counterparty", label: "MORT USER", value: displayCounterparty)]
        }()

        let serviceLines: [String] = {
            guard
                let description = immutableSnapshot?.serviceDescription?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !description.isEmpty
            else { return [] }
            return [description]
        }()

        let referenceRows: [ReceiptRow] = {
            guard let ref = maskedProviderReference, !ref.isEmpty else { return [] }
            return [ReceiptRow(id: "provider", label: "PROVIDER REF", value: ref)]
        }()

        let links = (linkedDocumentRefs ?? []).enumerated().map { index, ref in
            ReceiptLink(
                id: "linked-\(index)",
                title: "LINKED RECEIPT",
                rows: [ReceiptRow(id: "receipt", label: "RECEIPT", value: ref)],
                status: "Unchanged"
            )
        }

        return Receipt(
            id: receiptId,
            type: receiptType,
            orderNumber: orderNumber,
            issuedAt: createdAt,
            identityRows: identityRows,
            serviceTitle: displayTitle,
            serviceLines: serviceLines,
            lines: [
                ReceiptLine(
                    id: "amount",
                    label: amountLabel,
                    amountCents: amountCents,
                    emphasis: .total,
                    note: nil
                ),
            ],
            statusTone: statusTone,
            statusLabel: statusLabel,
            statusSub: immutableSnapshot?.statusSub,
            methodLabel: immutableSnapshot?.methodLabel,
            methodMask: immutableSnapshot?.methodMask,
            referenceRows: referenceRows,
            links: links,
            privacyNote: "MORT receipts use display identities and masked provider references only.",
            notATaxDocumentNote: receiptType == .teenEarnings
                ? "This earnings receipt is not a tax document."
                : nil
        )
    }
}

nonisolated struct HostedFinancialHistoryPageDTO: Codable, Sendable {
    let items: [HostedFinancialDocumentDTO]
    let nextCursor: Date?
}

// MARK: - Hosted Stripe payout state

nonisolated struct HostedStripeLatestPayoutDTO: Codable, Sendable {
    let status: String?
    let amountCents: Int64?
    let currencyCode: String?
    let destinationType: String?
    let destinationLast4: String?
    let arrivalAt: Date?
    let updatedAt: Date?
}

nonisolated struct HostedStripePayoutStatusDTO: Codable, Sendable {
    let status: String
    let onboardingAvailable: Bool?
    let detailsSubmitted: Bool?
    let payoutsEnabled: Bool?
    let transfersStatus: String?
    let requirementsStatus: String?
    let guardianRequirementStatus: String?
    let disabledReasonCode: String?
    let country: String?
    let defaultCurrency: String?
    let lastSynchronizedAt: Date?
    let latestPayout: HostedStripeLatestPayoutDTO?
    let provider: String?

    var stage: PayoutStage {
        if let latest = latestPayout {
            switch latest.status?.lowercased() {
            case "paid": return .payoutPaid
            case "pending", "in_transit": return .payoutPending
            case "failed", "canceled", "cancelled": return .failed
            default: break
            }
        }

        switch status.lowercased() {
        case "not_started":
            return .setupRequired
        case "pending", "in_progress":
            return detailsSubmitted == true ? .verificationPending : .onboardingIncomplete
        case "restricted", "action_required", "disconnected":
            return .restricted
        case "complete":
            return payoutsEnabled == true ? .ready : .verificationPending
        default:
            return .setupRequired
        }
    }

    func toDomain() -> PayoutStatus {
        let latest = latestPayout
        let mask = latest?.destinationLast4.map { "•••• \($0)" }
        return PayoutStatus(
            id: "stripe-payout-status",
            stage: stage,
            amountCents: latest?.amountCents ?? 0,
            relatedReceiptNumber: nil,
            updatedAt: latest?.updatedAt ?? lastSynchronizedAt ?? Date(),
            destinationMask: mask,
            expectedText: latest?.arrivalAt.map {
                "Expected \($0.formatted(.dateTime.month(.abbreviated).day()))"
            }
        )
    }
}

// MARK: - Hosted guardian summary

nonisolated struct HostedGuardianTeenSummaryDTO: Codable, Sendable {
    let ok: Bool
    let teenId: String
    let teenHandle: String
    let teenDisplayName: String
    let activeJobCount: Int
    let upcomingJobTitle: String?
    let lastCheckInState: String
    let lastCheckInText: String
    let earningsThisMonthCents: Int64
    let earningsVisible: Bool
    let payoutStage: String?
    let safetyAlertsCount: Int
    let restrictedNotice: String

    func toDomain() -> GuardianSummary {
        GuardianSummary(
            teenHandle: teenHandle,
            teenDisplayName: teenDisplayName,
            activeJobCount: activeJobCount,
            upcomingJobTitle: upcomingJobTitle,
            lastCheckInState: CheckInState(rawValue: lastCheckInState) ?? .notStarted,
            lastCheckInText: lastCheckInText,
            earningsThisMonthCents: earningsThisMonthCents,
            earningsVisible: earningsVisible,
            payoutStage: payoutStage.flatMap(PayoutStage.init(rawValue:)),
            safetyAlertsCount: safetyAlertsCount,
            restrictedNotice: restrictedNotice
        )
    }
}

// MARK: - Hosted safety circle

nonisolated struct HostedSafetyCircleMemberDTO: Codable, Sendable {
    let id: String
    let teenId: String
    let contactId: String
    let relationshipLabel: String
    let status: String
    let receiveSafetyPing: Bool
    let receiveMissedCheckin: Bool
    let receiveJobSummary: Bool
    let receiveJobStatus: Bool
    let receiveEmergencyRequest: Bool
    let viewLimitedSafetyPlan: Bool
    let receiveCompletion: Bool
    let createdAt: Date
    let acceptedAt: Date?
}

nonisolated struct HostedSafetyContactProfileDTO: Codable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let role: String?

    var display: String {
        if let displayName {
            let clean = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        if let username {
            let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return "MORT contact"
    }

    var handleOrMask: String {
        guard let username else { return "Linked MORT account" }
        let clean = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return clean.isEmpty ? "Linked MORT account" : "@\(clean)"
    }
}

// MARK: - Hosted reviews

nonisolated struct HostedReviewProfileDTO: Codable, Sendable {
    let username: String?
    let displayName: String?
}

nonisolated struct HostedReviewJobDTO: Codable, Sendable {
    let title: String
}

nonisolated struct HostedReviewDTO: Codable, Sendable {
    let id: String
    let reviewerId: String
    let subjectId: String
    let rating: Int
    let body: String?
    let moderationStatus: String
    let createdAt: Date
    let reviewer: HostedReviewProfileDTO?
    let job: HostedReviewJobDTO?

    func toDomain() -> MortReview {
        let handle: String = {
            guard let username = reviewer?.username else { return "" }
            let clean = username.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            return clean.isEmpty ? "" : "@\(clean)"
        }()
        let display = reviewer?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MortReview(
            id: id,
            authorHandle: handle,
            authorDisplayName: (display?.isEmpty == false) ? display! : (handle.isEmpty ? "MORT member" : handle),
            rating: rating,
            body: body ?? "",
            jobTitle: job?.title ?? "MORT job",
            createdAt: createdAt
        )
    }
}
