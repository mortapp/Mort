//
//  Enums.swift
//  MORT
//
//  Core enumerations shared across the app.
//

import Foundation

/// The role a user operates as inside MORT.
enum UserRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case teen
    case adult
    case business
    case guardian
    case admin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teen: return "Teen"
        case .adult: return "Adult"
        case .business: return "Business"
        case .guardian: return "Parent / Guardian"
        case .admin: return "Admin"
        }
    }

    var subtitle: String {
        switch self {
        case .teen: return "Find safe local hustles (ages 13–17)"
        case .adult: return "Post and manage safe local jobs"
        case .business: return "Post jobs as a local business"
        case .guardian: return "Monitor and support a linked teen"
        case .admin: return "Moderate the MORT community"
        }
    }

    var systemImage: String {
        switch self {
        case .teen: return "figure.walk.motion"
        case .adult: return "person.fill"
        case .business: return "building.2.fill"
        case .guardian: return "shield.lefthalf.filled"
        case .admin: return "checkmark.seal.fill"
        }
    }

    /// Roles a person of the given age group is allowed to self-select.
    static func selectable(for ageGroup: AgeGroup) -> [UserRole] {
        switch ageGroup {
        case .under13: return []
        case .teen: return [.teen]
        case .adult: return [.adult, .business, .guardian]
        }
    }
}

/// Age bracket derived from date of birth.
enum AgeGroup: String, Codable, Sendable {
    case under13
    case teen      // 13–17
    case adult     // 18+

    static func from(birthDate: Date, now: Date = Date()) -> AgeGroup {
        let years = Calendar.current.dateComponents([.year], from: birthDate, to: now).year ?? 0
        if years < 13 { return .under13 }
        if years < 18 { return .teen }
        return .adult
    }
}

/// How a teen safely travels to jobs.
enum TransportationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case walking
    case bike
    case parentRide
    case publicTransit
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walking: return "Walking"
        case .bike: return "Bike"
        case .parentRide: return "Parent ride"
        case .publicTransit: return "Public transit"
        case .other: return "Other safe transportation"
        }
    }

    var systemImage: String {
        switch self {
        case .walking: return "figure.walk"
        case .bike: return "bicycle"
        case .parentRide: return "car.fill"
        case .publicTransit: return "bus.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// Lifecycle state of a posted job.
enum JobStatus: String, Codable, Sendable {
    case open
    case inProgress
    case completed
    case closed

    var label: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .closed: return "Closed"
        }
    }
}

/// State of a teen's application to a job.
enum ApplicationStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
    case withdrawn

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .withdrawn: return "Withdrawn"
        }
    }
}

/// Job categories surfaced in the feed.
enum JobCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case yardWork
    case petCare
    case cleaning
    case tech
    case tutoring
    case moving
    case errands
    case creative
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yardWork: return "Yard work"
        case .petCare: return "Pet care"
        case .cleaning: return "Cleaning"
        case .tech: return "Tech help"
        case .tutoring: return "Tutoring"
        case .moving: return "Moving"
        case .errands: return "Errands"
        case .creative: return "Creative"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .yardWork: return "leaf.fill"
        case .petCare: return "pawprint.fill"
        case .cleaning: return "sparkles"
        case .tech: return "desktopcomputer"
        case .tutoring: return "book.fill"
        case .moving: return "shippingbox.fill"
        case .errands: return "bag.fill"
        case .creative: return "paintbrush.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

/// Categories of notifications.
enum NotificationKind: String, Codable, Sendable {
    case job
    case application
    case message
    case safety
    case account

    var systemImage: String {
        switch self {
        case .job: return "briefcase.fill"
        case .application: return "person.badge.clock.fill"
        case .message: return "bubble.left.fill"
        case .safety: return "shield.fill"
        case .account: return "gearshape.fill"
        }
    }
}

/// What a report targets.
enum ReportTargetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case user
    case job
    case message

    var id: String { rawValue }
    var label: String {
        switch self {
        case .user: return "User"
        case .job: return "Job"
        case .message: return "Message"
        }
    }
}

/// Resolution state of a report / moderation item.
enum ReportStatus: String, Codable, Sendable {
    case open
    case reviewing
    case resolved
    case dismissed

    var label: String {
        switch self {
        case .open: return "Open"
        case .reviewing: return "Reviewing"
        case .resolved: return "Resolved"
        case .dismissed: return "Dismissed"
        }
    }
}

/// Severity used by the safety scanner.
enum SafetySeverity: String, Codable, Sendable {
    case safe
    case warn
    case block

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .warn: return "Warning"
        case .block: return "Blocked"
        }
    }
}

/// Status of a teen safety check-in.
enum CheckInStatus: String, Codable, Sendable {
    case safe
    case enRoute
    case needsHelp
    case unknown

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .enRoute: return "En route"
        case .needsHelp: return "Needs help"
        case .unknown: return "No recent check-in"
        }
    }
}
