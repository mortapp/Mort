//
//  MockServices.swift
//  MORT
//
//  Demo implementations of every service protocol, backed by MockStore.
//  Each type has a TODO for its Supabase replacement.
//

import Foundation

private func simulateLatency() async {
    try? await Task.sleep(for: .milliseconds(280))
}

// MARK: - Auth

final class MockAuthService: AuthServiceProtocol {
    private(set) var currentUserId: String?

    // TODO: Supabase — use supabase.auth.signIn / signUp / signOut.
    func signIn(email: String, password: String) async throws -> String {
        await simulateLatency()
        guard email.contains("@"), password.count >= 6 else {
            throw MortError.invalidInput("Enter a valid email and a password of at least 6 characters.")
        }
        let id = "u_\(UUID().uuidString.prefix(6))"
        currentUserId = id
        MockStore.shared.currentUserId = id
        return id
    }

    func signUp(email: String, password: String) async throws -> String {
        await simulateLatency()
        guard email.contains("@"), password.count >= 6 else {
            throw MortError.invalidInput("Enter a valid email and a password of at least 6 characters.")
        }
        let id = "new_\(UUID().uuidString.prefix(6))"
        currentUserId = id
        MockStore.shared.currentUserId = id
        return id
    }

    func signOut() async {
        await simulateLatency()
        currentUserId = nil
        MockStore.shared.currentUserId = nil
    }

    func sendVerificationEmail(to email: String) async throws {
        await simulateLatency()
        // TODO: Supabase sends this automatically on signUp.
    }
}

// MARK: - Profile

final class MockProfileService: ProfileServiceProtocol {
    // TODO: Supabase — query/insert/update the `profiles` table.
    func fetchProfile(id: String) async throws -> UserProfile? {
        await simulateLatency()
        return MockStore.shared.profiles.first { $0.id == id }
    }

    func createProfile(_ profile: UserProfile) async throws -> UserProfile {
        await simulateLatency()
        var store = MockStore.shared
        store.profiles.removeAll { $0.id == profile.id }
        store.profiles.append(profile)
        return profile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        await simulateLatency()
        var updated = profile
        updated.updatedAt = Date()
        let store = MockStore.shared
        if let idx = store.profiles.firstIndex(where: { $0.id == profile.id }) {
            store.profiles[idx] = updated
        } else {
            store.profiles.append(updated)
        }
        return updated
    }

    func isUsernameAvailable(_ usernameLower: String) async throws -> Bool {
        await simulateLatency()
        return !MockStore.shared.profiles.contains { $0.usernameLower == usernameLower }
    }
}

// MARK: - Jobs

final class MockJobService: JobServiceProtocol {
    // TODO: Supabase — query/insert into `jobs` and `job_applications`.
    func fetchJobs() async throws -> [Job] {
        await simulateLatency()
        return MockStore.shared.jobs
            .filter { $0.status == .open }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchJobs(postedBy posterId: String) async throws -> [Job] {
        await simulateLatency()
        return MockStore.shared.jobs
            .filter { $0.posterId == posterId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchJob(id: String) async throws -> Job? {
        await simulateLatency()
        return MockStore.shared.jobs.first { $0.id == id }
    }

    func createJob(_ job: Job) async throws -> Job {
        await simulateLatency()
        MockStore.shared.jobs.insert(job, at: 0)
        return job
    }

    func applications(forApplicant applicantId: String) async throws -> [JobApplication] {
        await simulateLatency()
        return MockStore.shared.applications
            .filter { $0.applicantId == applicantId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func applications(forJob jobId: String) async throws -> [JobApplication] {
        try await applications(forJob: jobId, visibleTo: "")
    }

    func applications(forJob jobId: String, visibleTo requesterId: String) async throws -> [JobApplication] {
        await simulateLatency()
        let store = MockStore.shared
        let requester = store.profiles.first { $0.id == requesterId }
        return store.applications
            .filter { $0.jobId == jobId }
            .filter { application in
                guard !requesterId.isEmpty else { return false }
                if requester?.role == .admin { return true }
                if application.applicantId == requesterId { return true }
                if let job = store.jobs.first(where: { $0.id == jobId }), job.posterId == requesterId { return true }
                return store.guardianLinks.contains { $0.guardianId == requesterId && $0.teenId == application.applicantId }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func apply(to job: Job, applicant: UserProfile, message: String) async throws -> JobApplication {
        await simulateLatency()
        let store = MockStore.shared
        if store.applications.contains(where: { $0.jobId == job.id && $0.applicantId == applicant.id }) {
            throw MortError.invalidInput("You already applied to this job.")
        }
        let app = JobApplication(jobId: job.id, jobTitle: job.title, applicantId: applicant.id, applicantName: applicant.displayName, message: message)
        store.applications.insert(app, at: 0)
        return app
    }

    func setApplicationStatus(_ application: JobApplication, status: ApplicationStatus) async throws {
        await simulateLatency()
        let store = MockStore.shared
        if let idx = store.applications.firstIndex(where: { $0.id == application.id }) {
            store.applications[idx].status = status
        }
    }

    func startJob(jobId: String, requesterId: String) async throws {
        await simulateLatency()
        let store = MockStore.shared
        guard let jobIdx = store.jobs.firstIndex(where: { $0.id == jobId }) else { throw MortError.notFound }
        let isPoster = store.jobs[jobIdx].posterId == requesterId
        let isAcceptedApplicant = store.applications.contains {
            $0.jobId == jobId && $0.applicantId == requesterId && $0.status == .accepted
        }
        guard isPoster || isAcceptedApplicant else {
            throw MortError.invalidInput("You are not allowed to start this job.")
        }
        store.jobs[jobIdx].status = .inProgress
    }

    func completeJob(jobId: String, applicationId: String, requesterId: String) async throws {
        await simulateLatency()
        let store = MockStore.shared
        guard let appIdx = store.applications.firstIndex(where: { $0.id == applicationId }) else { throw MortError.notFound }
        guard store.applications[appIdx].jobId == jobId else {
            throw MortError.invalidInput("Application does not belong to this job.")
        }
        guard let jobIdx = store.jobs.firstIndex(where: { $0.id == jobId }) else { throw MortError.notFound }
        let app = store.applications[appIdx]
        let isPoster = store.jobs[jobIdx].posterId == requesterId
        let isAcceptedApplicant = app.applicantId == requesterId && app.status == .accepted
        guard isPoster || isAcceptedApplicant else {
            throw MortError.invalidInput("You are not allowed to complete this job.")
        }
        store.jobs[jobIdx].status = .completed
    }
}

// MARK: - Messages

final class MockMessageService: MessageServiceProtocol {
    // TODO: Supabase — `conversations` + `messages`, realtime subscription for live chat.
    func fetchConversations(for userId: String) async throws -> [Conversation] {
        await simulateLatency()
        return MockStore.shared.conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    func fetchMessages(conversationId: String) async throws -> [Message] {
        await simulateLatency()
        return MockStore.shared.messages
            .filter { $0.conversationId == conversationId }
            .sorted { $0.sentAt < $1.sentAt }
    }

    func sendMessage(conversationId: String, senderId: String, text: String) async throws -> Message {
        await simulateLatency()
        let scan = SafetyScanner.scan(text)
        if scan.isBlocked {
            throw MortError.blockedContent
        }
        let message = Message(conversationId: conversationId, senderId: senderId, text: text, flagged: !scan.isSafe)
        let store = MockStore.shared
        store.messages.append(message)
        if let idx = store.conversations.firstIndex(where: { $0.id == conversationId }) {
            store.conversations[idx].lastMessage = text
            store.conversations[idx].lastMessageAt = message.sentAt
        }
        return message
    }
}

// MARK: - Notifications

final class MockNotificationService: NotificationServiceProtocol {
    // TODO: Supabase — `notification_events` + push registration.
    func fetch(for userId: String) async throws -> [NotificationItem] {
        await simulateLatency()
        return MockStore.shared.notifications.sorted { $0.createdAt > $1.createdAt }
    }

    func markRead(_ id: String) async throws {
        let store = MockStore.shared
        if let idx = store.notifications.firstIndex(where: { $0.id == id }) {
            store.notifications[idx].read = true
        }
    }
}

// MARK: - Reports

final class MockReportService: ReportServiceProtocol {
    // TODO: Supabase — `reports` + `blocked_users`.
    func submit(_ report: Report) async throws {
        await simulateLatency()
        MockStore.shared.reports.insert(report, at: 0)
    }

    func fetchAll() async throws -> [Report] {
        await simulateLatency()
        return MockStore.shared.reports.sorted { $0.createdAt > $1.createdAt }
    }

    func setStatus(_ report: Report, status: ReportStatus) async throws {
        await simulateLatency()
        let store = MockStore.shared
        if let idx = store.reports.firstIndex(where: { $0.id == report.id }) {
            store.reports[idx].status = status
        }
    }

    func blockedUsers(for userId: String) async throws -> [UserProfile] {
        await simulateLatency()
        return MockStore.shared.blocked[userId] ?? []
    }

    func block(userId: String, named name: String) async throws {
        await simulateLatency()
        let store = MockStore.shared
        guard let me = store.currentUserId else { throw MortError.invalidInput("Not signed in") }
        var list = store.blocked[me] ?? []
        guard !list.contains(where: { $0.id == userId }) else { return }
        let profile = store.profiles.first { $0.id == userId }
            ?? UserProfile(id: userId, username: name.lowercased(), displayName: name, role: .adult, ageGroup: .adult)
        list.append(profile)
        store.blocked[me] = list
    }

    func unblock(userId: String) async throws {
        await simulateLatency()
        let store = MockStore.shared
        guard let me = store.currentUserId else { throw MortError.invalidInput("Not signed in") }
        store.blocked[me]?.removeAll { $0.id == userId }
    }
}

// MARK: - Safety

final class MockSafetyService: SafetyServiceProtocol {
    func scan(_ text: String) -> SafetyScanResult { SafetyScanner.scan(text) }
    func scanSchedule(_ date: Date?) -> SafetyScanResult { SafetyScanner.scanSchedule(date) }

    // TODO: Supabase — `guardian_links`, `trusted_circle_contacts`, `safety_pings`.
    func guardianLinks(forTeen teenId: String) async throws -> [GuardianLink] {
        await simulateLatency()
        return MockStore.shared.guardianLinks.filter { $0.teenId == teenId }
    }

    func linkedTeens(forGuardian guardianId: String) async throws -> [GuardianLink] {
        await simulateLatency()
        // Demo-only fallback for mock builds. Never copy this fallback into live Supabase services.
        return MockStore.shared.guardianLinks
    }

    func trustedContacts(for teenId: String) async throws -> [TrustedContact] {
        await simulateLatency()
        return MockStore.shared.trustedContacts[teenId] ?? []
    }

    func addTrustedContact(_ contact: TrustedContact, for teenId: String) async throws {
        await simulateLatency()
        let store = MockStore.shared
        var list = store.trustedContacts[teenId] ?? []
        list.append(contact)
        store.trustedContacts[teenId] = list
    }

    func recentPings(forGuardian guardianId: String) async throws -> [SafetyPing] {
        await simulateLatency()
        return MockStore.shared.pings.sorted { $0.createdAt > $1.createdAt }
    }

    func checkIn(_ ping: SafetyPing) async throws {
        await simulateLatency()
        MockStore.shared.pings.insert(ping, at: 0)
    }
}

// MARK: - Admin

final class MockAdminService: AdminServiceProtocol {
    // TODO: Supabase — admin-only queries gated by RLS / role claim.
    func allUsers() async throws -> [UserProfile] {
        await simulateLatency()
        return MockStore.shared.profiles
    }

    func allJobs() async throws -> [Job] {
        await simulateLatency()
        return MockStore.shared.jobs
    }

    func flaggedMessages() async throws -> [Message] {
        await simulateLatency()
        return MockStore.shared.messages.filter { $0.flagged }
    }

    func actionLog() async throws -> [AdminAction] {
        await simulateLatency()
        return MockStore.shared.adminActions.sorted { $0.createdAt > $1.createdAt }
    }

    func logAction(_ action: AdminAction) async throws {
        await simulateLatency()
        MockStore.shared.adminActions.insert(action, at: 0)
    }
}

// MARK: - Storage

final class MockStorageService: StorageServiceProtocol {
    // TODO: Supabase Storage — upload to the `profile-avatars` bucket and return a public URL.
    func uploadAvatar(data: Data, userId: String) async throws -> String {
        await simulateLatency()
        return "mock://profile-avatars/\(userId).jpg"
    }
}
