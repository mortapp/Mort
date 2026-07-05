//
//  AbuseModels.swift
//  MORT
//
//  Models and protocol for abuse protection and moderation logging.
//

import Foundation

enum AbuseSeverity: String, Codable {
    case low
    case medium
    case high
}

struct RateLimitEvent: Codable, Identifiable {
    let id: String
    let actorId: String
    let action: String
    let createdAt: Date
}

struct ModerationEvent: Codable, Identifiable {
    let id: String
    let actorId: String?
    let action: String
    /// A small redacted hash of the content to allow de-duplication without
    /// storing the raw text.
    let contentHash: String?
    let severity: AbuseSeverity
    let createdAt: Date
}

// Abuse protection protocol used by UI flows to preflight potentially risky
// actions (messages, job posts, applications, reports, etc.). The mock and
// live implementations may record moderation and rate-limit events.
protocol AbuseProtectionServiceProtocol {
    /// Check whether an action should proceed. Returns true to allow.
    func preflightCheck(action: String, actorId: String?, text: String?) async throws -> Bool

    /// Record a moderation event.
    func recordModerationEvent(_ event: ModerationEvent) async

    /// Recent rate-limit events for an actor.
    func recentRateLimitEvents(for actorId: String) async -> [RateLimitEvent]
}
