//
//  SafetyModels.swift
//  MORT iOS V8 — Models
//
//  Safety UI must never FAKE an emergency action. Emergency dispatch, guardian
//  notification delivery, and escalation results are all backend/native
//  capabilities; the UI shows honest pending/unavailable states instead.
//

import Foundation

nonisolated enum CheckInState: String, Codable, Sendable {
    case notStarted
    case dueSoon
    case overdue
    case confirmed
    case skipped

    var label: String {
        switch self {
        case .notStarted: "NOT STARTED"
        case .dueSoon: "CHECK-IN DUE SOON"
        case .overdue: "CHECK-IN OVERDUE"
        case .confirmed: "CHECKED IN"
        case .skipped: "CHECK-IN SKIPPED"
        }
    }

    var tone: MortTone {
        switch self {
        case .notStarted: .neutral
        case .dueSoon: .info
        case .overdue: .danger
        case .confirmed: .success
        case .skipped: .warning
        }
    }

    var symbol: String {
        switch self {
        case .notStarted: "circle.dashed"
        case .dueSoon: "bell"
        case .overdue: "bell.badge"
        case .confirmed: "checkmark.circle"
        case .skipped: "bell.slash"
        }
    }
}

nonisolated struct SafetyCheckIn: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let jobId: String
    let jobTitle: String
    let state: CheckInState
    let dueAt: Date?
    let confirmedAt: Date?

    var dueText: String {
        guard let dueAt else { return "No check-in scheduled" }
        let f = DateFormatter()
        f.timeStyle = .short
        return "Due \(f.string(from: dueAt))"
    }
}

/// Whether a native/backend safety capability is actually available.
/// Unavailable capabilities are shown honestly — never simulated.
nonisolated enum SafetyCapabilityState: String, Codable, Sendable {
    case available
    case permissionNeeded
    case unavailable
    case offline

    var notice: String? {
        switch self {
        case .available: nil
        case .permissionNeeded: "MORT needs permission before this can work."
        case .unavailable: "This isn't available on this device yet."
        case .offline: "You're offline. This needs a connection to work."
        }
    }
}

nonisolated struct SafetyContact: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let relationship: String
    /// Never a raw phone number in the UI — masked by the server.
    let contactMask: String
    let isGuardian: Bool
    let isNotifiedOnJobs: Bool
}

nonisolated enum SafetyReportCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case unsafeBehavior
    case harassment
    case paymentProblem
    case noShow
    case unsafeLocation
    case somethingElse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unsafeBehavior: "Someone acted unsafely"
        case .harassment: "Harassment or abuse"
        case .paymentProblem: "A payment problem"
        case .noShow: "Someone didn't show up"
        case .unsafeLocation: "The location felt unsafe"
        case .somethingElse: "Something else"
        }
    }
}
