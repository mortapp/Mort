//
//  MortRole.swift
//  MORT iOS V8 — Models
//
//  Role drives routing, available tabs, and which financial surfaces exist.
//

import Foundation

/// The account role. Backend-authoritative: the app renders the role the
/// backend reports and never elevates itself.
enum MortRole: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Teen worker: discovers and performs jobs, earns money.
    case teen
    /// Adult poster: creates jobs, funds them, pays and tips.
    case adult
    /// Guardian: supervises a linked teen within policy limits.
    case guardian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teen: "Teen"
        case .adult: "Job poster"
        case .guardian: "Guardian"
        }
    }

    var onboardingHeadline: String {
        switch self {
        case .teen: "Find real work nearby"
        case .adult: "Get help from vetted local teens"
        case .guardian: "Stay in the loop, safely"
        }
    }
}
