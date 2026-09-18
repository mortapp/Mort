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
    let createdAt: Date
    let updatedAt: Date
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
        let handle = cleanUsername.map { "@\($0)" } ?? "@member"

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

        let year = Calendar(identifier: .gregorian).component(.year, from: createdAt)

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
            verifications: [],
            memberSince: String(year),
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
