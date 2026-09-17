//
//  MortJob.swift
//  MORT iOS V8 — Models
//
//  The job lifecycle. All state transitions are backend-authoritative; the
//  client renders the state it is given.
//

import Foundation

/// Job lifecycle state. The UI never advances this on its own.
nonisolated enum MortJobState: String, Codable, Sendable, CaseIterable {
    case draft
    case open
    case applied
    case accepted
    /// Pre-work platform funding confirmed: the job is FUNDED and startable.
    /// This does NOT mean the teen has been paid.
    case funded
    case scheduled
    case inProgress
    case awaitingCompletion
    case completed
    case settled
    case cancelled
    case disputed

    var label: String {
        switch self {
        case .draft: "Draft"
        case .open: "Open"
        case .applied: "Applied"
        case .accepted: "Accepted"
        case .funded: "Funded"
        case .scheduled: "Scheduled"
        case .inProgress: "In progress"
        case .awaitingCompletion: "Awaiting confirmation"
        case .completed: "Completed"
        case .settled: "Settled"
        case .cancelled: "Cancelled"
        case .disputed: "Disputed"
        }
    }

    var tone: MortTone {
        switch self {
        case .draft, .open, .applied: .info
        case .accepted, .funded, .scheduled, .inProgress, .awaitingCompletion: .warning
        case .completed, .settled: .success
        case .cancelled: .neutral
        case .disputed: .danger
        }
    }

    var symbol: String {
        switch self {
        case .draft: "square.and.pencil"
        case .open: "dot.radiowaves.left.and.right"
        case .applied: "paperplane"
        case .accepted: "checkmark.seal"
        case .funded: "lock.shield"
        case .scheduled: "calendar"
        case .inProgress: "figure.walk.motion"
        case .awaitingCompletion: "hourglass"
        case .completed: "checkmark.circle"
        case .settled: "checkmark.circle.fill"
        case .cancelled: "slash.circle"
        case .disputed: "exclamationmark.triangle"
        }
    }
}

nonisolated struct MortJob: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let category: String
    /// Full description; may be several lines. Layouts must not clip it.
    let details: String
    /// Base pay offered, integer cents. Authoritative value from the backend.
    let baseCents: Int64
    /// Approximate distance text, e.g. "0.6 mi".
    let distance: String
    /// Approximate area, never an exact address.
    let area: String
    let scheduleText: String
    let posterHandle: String
    let posterDisplayName: String
    let workerHandle: String?
    let state: MortJobState
    /// Display order number, 4 digits, e.g. "0042".
    let orderNumber: String?
    let applicantCount: Int
    let postedAgo: String
    /// True when the poster requires proof/evidence at completion.
    let requiresProof: Bool

    var basePay: Money { Money(cents: baseCents) }
}

/// An application a teen submitted to a job.
nonisolated struct MortApplication: Identifiable, Codable, Hashable, Sendable {
    nonisolated enum State: String, Codable, Sendable {
        case submitted, viewed, shortlisted, accepted, declined, withdrawn, expired

        var label: String {
            switch self {
            case .submitted: "Submitted"
            case .viewed: "Viewed"
            case .shortlisted: "Shortlisted"
            case .accepted: "Accepted"
            case .declined: "Not selected"
            case .withdrawn: "Withdrawn"
            case .expired: "Expired"
            }
        }

        var tone: MortTone {
            switch self {
            case .submitted, .viewed: .info
            case .shortlisted: .warning
            case .accepted: .success
            case .declined, .expired: .neutral
            case .withdrawn: .neutral
            }
        }

        var symbol: String {
            switch self {
            case .submitted: "paperplane"
            case .viewed: "eye"
            case .shortlisted: "star"
            case .accepted: "checkmark.seal"
            case .declined: "xmark.circle"
            case .withdrawn: "arrow.uturn.backward"
            case .expired: "clock.badge.xmark"
            }
        }
    }

    let id: String
    let jobId: String
    let jobTitle: String
    let applicantHandle: String
    let applicantDisplayName: String
    let applicantRating: Double?
    let applicantCompletedJobs: Int
    let message: String
    let state: State
    let submittedAgo: String
}
