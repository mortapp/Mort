//
//  Models.swift
//  MORT
//
//  Core data models. Marked nonisolated so they can be decoded off the main actor.
//

import Foundation

nonisolated struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var username: String
    var usernameLower: String
    var displayName: String
    var avatarUrl: String?
    var bio: String?
    var role: UserRole
    var ageGroup: AgeGroup
    /// Stored privately; never shown to other users.
    var birthDatePrivate: Date?
    var transportationMode: TransportationMode?
    var trustScore: Int
    var termsAcceptedAt: Date?
    var termsVersion: String?
    var notificationsPermissionStatus: String?
    var createdAt: Date
    var updatedAt: Date

    var handle: String { "@\(username)" }

    init(
        id: String,
        username: String,
        displayName: String,
        avatarUrl: String? = nil,
        bio: String? = nil,
        role: UserRole,
        ageGroup: AgeGroup,
        birthDatePrivate: Date? = nil,
        transportationMode: TransportationMode? = nil,
        trustScore: Int = 50,
        termsAcceptedAt: Date? = nil,
        termsVersion: String? = nil,
        notificationsPermissionStatus: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.usernameLower = username.lowercased()
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.role = role
        self.ageGroup = ageGroup
        self.birthDatePrivate = birthDatePrivate
        self.transportationMode = transportationMode
        self.trustScore = trustScore
        self.termsAcceptedAt = termsAcceptedAt
        self.termsVersion = termsVersion
        self.notificationsPermissionStatus = notificationsPermissionStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

nonisolated struct Job: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var description: String
    var category: JobCategory
    var posterId: String
    var posterName: String
    var locationLabel: String
    var estimatedPayText: String
    var scheduledAt: Date?
    var requirements: String
    var safetyNotes: String
    var status: JobStatus
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        category: JobCategory,
        posterId: String,
        posterName: String,
        locationLabel: String,
        estimatedPayText: String,
        scheduledAt: Date? = nil,
        requirements: String = "",
        safetyNotes: String = "",
        status: JobStatus = .open,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.posterId = posterId
        self.posterName = posterName
        self.locationLabel = locationLabel
        self.estimatedPayText = estimatedPayText
        self.scheduledAt = scheduledAt
        self.requirements = requirements
        self.safetyNotes = safetyNotes
        self.status = status
        self.createdAt = createdAt
    }
}

nonisolated struct JobApplication: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var jobId: String
    var jobTitle: String
    var applicantId: String
    var applicantName: String
    var message: String
    var status: ApplicationStatus
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        jobId: String,
        jobTitle: String,
        applicantId: String,
        applicantName: String,
        message: String = "",
        status: ApplicationStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.jobId = jobId
        self.jobTitle = jobTitle
        self.applicantId = applicantId
        self.applicantName = applicantName
        self.message = message
        self.status = status
        self.createdAt = createdAt
    }
}

nonisolated struct Conversation: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var otherUserId: String
    var otherUserName: String
    var jobTitle: String?
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCount: Int

    init(
        id: String = UUID().uuidString,
        otherUserId: String,
        otherUserName: String,
        jobTitle: String? = nil,
        lastMessage: String = "",
        lastMessageAt: Date = Date(),
        unreadCount: Int = 0
    ) {
        self.id = id
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.jobTitle = jobTitle
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
    }
}

nonisolated struct Message: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var sentAt: Date
    var flagged: Bool

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        text: String,
        sentAt: Date = Date(),
        flagged: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.sentAt = sentAt
        self.flagged = flagged
    }
}

nonisolated struct NotificationItem: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var kind: NotificationKind
    var title: String
    var body: String
    var createdAt: Date
    var read: Bool

    init(
        id: String = UUID().uuidString,
        kind: NotificationKind,
        title: String,
        body: String,
        createdAt: Date = Date(),
        read: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.read = read
    }
}

nonisolated struct Report: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var targetType: ReportTargetType
    var targetId: String
    var targetLabel: String
    var reporterId: String
    var reporterName: String
    var reason: String
    var status: ReportStatus
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        targetType: ReportTargetType,
        targetId: String,
        targetLabel: String,
        reporterId: String,
        reporterName: String,
        reason: String,
        status: ReportStatus = .open,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.targetType = targetType
        self.targetId = targetId
        self.targetLabel = targetLabel
        self.reporterId = reporterId
        self.reporterName = reporterName
        self.reason = reason
        self.status = status
        self.createdAt = createdAt
    }
}

/// A single match found by the safety scanner.
nonisolated struct SafetyMatch: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var category: String
    var snippet: String

    init(id: String = UUID().uuidString, category: String, snippet: String) {
        self.id = id
        self.category = category
        self.snippet = snippet
    }
}

/// Result of running text through the safety scanner.
nonisolated struct SafetyScanResult: Codable, Hashable, Sendable {
    var severity: SafetySeverity
    var matches: [SafetyMatch]
    var message: String

    var isSafe: Bool { severity == .safe }
    var isBlocked: Bool { severity == .block }

    static let safe = SafetyScanResult(severity: .safe, matches: [], message: "")
}

/// A guardian-to-teen link.
nonisolated struct GuardianLink: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var teenId: String
    var teenName: String
    var guardianId: String
    var guardianName: String
    var linkedAt: Date

    init(
        id: String = UUID().uuidString,
        teenId: String,
        teenName: String,
        guardianId: String,
        guardianName: String,
        linkedAt: Date = Date()
    ) {
        self.id = id
        self.teenId = teenId
        self.teenName = teenName
        self.guardianId = guardianId
        self.guardianName = guardianName
        self.linkedAt = linkedAt
    }
}

/// A trusted contact a teen can ping.
nonisolated struct TrustedContact: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var relationship: String

    init(id: String = UUID().uuidString, name: String, relationship: String) {
        self.id = id
        self.name = name
        self.relationship = relationship
    }
}

/// A teen safety check-in / ping.
nonisolated struct SafetyPing: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var teenId: String
    var teenName: String
    var status: CheckInStatus
    var note: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        teenId: String,
        teenName: String,
        status: CheckInStatus,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teenId = teenId
        self.teenName = teenName
        self.status = status
        self.note = note
        self.createdAt = createdAt
    }
}

/// An admin moderation action record.
nonisolated struct AdminAction: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var adminName: String
    var action: String
    var target: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        adminName: String,
        action: String,
        target: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.adminName = adminName
        self.action = action
        self.target = target
        self.createdAt = createdAt
    }
}
