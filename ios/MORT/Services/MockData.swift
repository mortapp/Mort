//
//  MockData.swift
//  MORT
//
//  In-memory demo data store backing the mock services. Replace with Supabase
//  queries when the live client is wired in.
//

import Foundation

/// Shared mutable demo data. Acts as a stand-in "database" for the mock services.
final class MockStore {
    static let shared = MockStore()

    var profiles: [UserProfile]
    var jobs: [Job]
    var applications: [JobApplication]
    var conversations: [Conversation]
    var messages: [Message]
    var notifications: [NotificationItem]
    var reports: [Report]
    var moderationEvents: [ModerationEvent]
    var blocked: [String: [UserProfile]]
    var rateLimitEvents: [RateLimitEvent]
    var currentUserId: String?
    var guardianLinks: [GuardianLink]
    var trustedContacts: [String: [TrustedContact]]
    var pings: [SafetyPing]
    var adminActions: [AdminAction]

    private init() {
        let now = Date()

        let adultPoster = UserProfile(id: "u_adult", username: "marcus_t", displayName: "Marcus T.", bio: "Neighbor who needs a hand around the house.", role: .adult, ageGroup: .adult, trustScore: 72)
        let business = UserProfile(id: "u_biz", username: "greenleaf_cafe", displayName: "Greenleaf Café", bio: "Local café hiring for small tasks.", role: .business, ageGroup: .adult, trustScore: 80)
        let teen = UserProfile(id: "u_teen", username: "jordan", displayName: "Jordan", bio: "Hardworking, reliable, love being outside.", role: .teen, ageGroup: .teen, transportationMode: .bike, trustScore: 64)

        profiles = [adultPoster, business, teen]

        jobs = [
            Job(id: "j1", title: "Rake leaves in backyard", description: "Need help raking and bagging leaves in a fenced backyard. Should take about 2 hours.", category: .yardWork, posterId: "u_adult", posterName: "Marcus T.", locationLabel: "Maple Heights", estimatedPayText: "$25–35", scheduledAt: Calendar.current.date(byAdding: .day, value: 1, to: now), requirements: "Bring water. Gloves provided.", safetyNotes: "Daytime only. Adult home the whole time.", status: .open, createdAt: now.addingTimeInterval(-3600)),
            Job(id: "j2", title: "Walk friendly golden retriever", description: "Looking for someone to walk Biscuit around the block a few afternoons.", category: .petCare, posterId: "u_biz", posterName: "Greenleaf Café", locationLabel: "Downtown", estimatedPayText: "$15 / walk", scheduledAt: Calendar.current.date(byAdding: .day, value: 2, to: now), requirements: "Comfortable with medium dogs.", safetyNotes: "Public route. Meet at the café.", status: .open, createdAt: now.addingTimeInterval(-7200)),
            Job(id: "j3", title: "Help set up a new laptop", description: "Need help moving files and setting up a new laptop. Tech-savvy teen welcome.", category: .tech, posterId: "u_adult", posterName: "Marcus T.", locationLabel: "Maple Heights", estimatedPayText: "$20", scheduledAt: Calendar.current.date(byAdding: .day, value: 3, to: now), requirements: "Know your way around Windows.", safetyNotes: "Daytime. Family present.", status: .open, createdAt: now.addingTimeInterval(-10000)),
        ]

        applications = [
            JobApplication(id: "a1", jobId: "j1", jobTitle: "Rake leaves in backyard", applicantId: "u_teen", applicantName: "Jordan", message: "I'd love to help! I'm available tomorrow afternoon.", status: .pending, createdAt: now.addingTimeInterval(-1800)),
        ]

        conversations = [
            Conversation(id: "c1", otherUserId: "u_adult", otherUserName: "Marcus T.", jobTitle: "Rake leaves in backyard", lastMessage: "Sounds great, see you tomorrow!", lastMessageAt: now.addingTimeInterval(-600), unreadCount: 1),
        ]

        messages = [
            Message(id: "m1", conversationId: "c1", senderId: "u_adult", text: "Hi Jordan, thanks for applying!", sentAt: now.addingTimeInterval(-1200)),
            Message(id: "m2", conversationId: "c1", senderId: "u_teen", text: "Happy to help. What time works?", sentAt: now.addingTimeInterval(-900)),
            Message(id: "m3", conversationId: "c1", senderId: "u_adult", text: "Sounds great, see you tomorrow!", sentAt: now.addingTimeInterval(-600)),
        ]

        notifications = [
            NotificationItem(id: "n1", kind: .application, title: "Application update", body: "Your application for ‘Rake leaves in backyard’ is pending.", createdAt: now.addingTimeInterval(-1700)),
            NotificationItem(id: "n2", kind: .message, title: "New message", body: "Marcus T. sent you a message.", createdAt: now.addingTimeInterval(-600)),
            NotificationItem(id: "n3", kind: .safety, title: "Safety reminder", body: "Remember to check in when you arrive at a job.", createdAt: now.addingTimeInterval(-300)),
        ]

        reports = [
            Report(id: "r1", targetType: .job, targetId: "j9", targetLabel: "Late-night moving gig", reporterId: "u_teen", reporterName: "Jordan", reason: "Job scheduled very late at night.", status: .open, createdAt: now.addingTimeInterval(-5000)),
        ]

        blocked = [:]

        guardianLinks = [
            GuardianLink(id: "g1", teenId: "u_teen", teenName: "Jordan", guardianId: "u_guardian", guardianName: "Parent", linkedAt: now.addingTimeInterval(-86400)),
        ]

        trustedContacts = [
            "u_teen": [TrustedContact(name: "Mom", relationship: "Parent"), TrustedContact(name: "Coach Riley", relationship: "Mentor")],
        ]

        pings = [
            SafetyPing(id: "p1", teenId: "u_teen", teenName: "Jordan", status: .safe, note: "Arrived safely at the café.", createdAt: now.addingTimeInterval(-2400)),
        ]

        adminActions = [
            AdminAction(id: "act1", adminName: "Admin", action: "Resolved report", target: "Late-night moving gig", createdAt: now.addingTimeInterval(-4000)),
        ]
        moderationEvents = []
        rateLimitEvents = []
        currentUserId = nil
    }
}
