//
//  MortUser.swift
//  MORT iOS V8 — Models
//
//  Privacy rule: the app displays username / display name only. Never legal
//  name, phone number, exact address, or personal email in any shared surface.
//

import Foundation

/// A person as the app is allowed to display them.
nonisolated struct MortUser: Identifiable, Codable, Hashable, Sendable {
    let id: String
    /// Public handle, e.g. "@michael". The only identity shown on receipts.
    let handle: String
    /// Display name, e.g. "Michael R." — initial-only surname by policy.
    let displayName: String
    let role: MortRole
    /// Approximate area only, e.g. "Northside" — never an exact address.
    let area: String?
    let avatarInitials: String
    /// Backend-computed reputation. The client never calculates this.
    let rating: Double?
    let completedJobs: Int
    /// Backend-verified badges only. Never fabricated client-side.
    let verifications: [String]
    let memberSince: String
    let bio: String?
    /// Guardian link state for teen accounts.
    let guardianLinked: Bool

    var ratingText: String {
        guard let rating, completedJobs > 0 else { return "No ratings yet" }
        return String(format: "%.1f", rating)
    }
}

/// The authenticated session's own profile plus editable onboarding answers.
nonisolated struct MortProfileDraft: Codable, Sendable, Equatable {
    var displayName: String = ""
    var area: String = ""
    var ageGroup: String = ""
    var categories: [String] = []
    var bio: String = ""
    var guardianEmailInvite: String = ""

    var isTeenComplete: Bool {
        !displayName.isEmpty && !area.isEmpty && !ageGroup.isEmpty && !categories.isEmpty
    }

    var isAdultComplete: Bool {
        !displayName.isEmpty && !area.isEmpty
    }
}
