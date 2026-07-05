//
//  MockAbuseProtectionService.swift
//  MORT
//
//  Simple mock implementation used during demo mode. Records events in
//  MockStore and enforces a tiny rate-limit for quick testing.
//

import Foundation

final class MockAbuseProtectionService: AbuseProtectionServiceProtocol {
    private let rateLimitWindow: TimeInterval = 60 // seconds
    private let maxEventsPerWindow = 6

    func preflightCheck(action: String, actorId: String?, text: String?) async throws -> Bool {
        // Record a rate-limit event
        if let actor = actorId {
            let event = RateLimitEvent(id: UUID().uuidString, actorId: actor, action: action, createdAt: Date())
            MockStore.shared.rateLimitEvents.insert(event, at: 0)
        }

        // Simple rate-limit enforcement: deny if too many events in window
        if let actor = actorId {
            let recent = MockStore.shared.rateLimitEvents.filter { $0.actorId == actor && $0.createdAt > Date().addingTimeInterval(-rateLimitWindow) }
            if recent.count > maxEventsPerWindow {
                // Record a moderation event for audit
                let med = ModerationEvent(id: UUID().uuidString, actorId: actor, action: "rate_limited:\(action)", contentHash: nil, severity: .medium, createdAt: Date())
                MockStore.shared.moderationEvents.insert(med, at: 0)
                return false
            }
        }

        // Run a basic content safety check if we have text
        if let t = text {
            let scan = SafetyScanner.scan(t)
            if scan.isBlocked {
                let med = ModerationEvent(id: UUID().uuidString, actorId: actorId, action: "blocked_content:")
                MockStore.shared.moderationEvents.insert(med, at: 0)
                throw MortError.blockedContent
            }
            if !scan.isSafe {
                let med = ModerationEvent(id: UUID().uuidString, actorId: actorId, action: "flagged_content:", contentHash: String(t.hashValue), severity: .low, createdAt: Date())
                MockStore.shared.moderationEvents.insert(med, at: 0)
            }
        }

        return true
    }

    func recordModerationEvent(_ event: ModerationEvent) async {
        MockStore.shared.moderationEvents.insert(event, at: 0)
    }

    func recentRateLimitEvents(for actorId: String) async -> [RateLimitEvent] {
        return MockStore.shared.rateLimitEvents.filter { $0.actorId == actorId }
    }
}
