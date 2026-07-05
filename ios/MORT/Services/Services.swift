//
//  Services.swift
//  MORT
//
//  Service protocols. Screens depend on these protocols, never on concrete
//  implementations, so the mock layer can be swapped for a live Supabase layer.
//

import Foundation

enum MortError: LocalizedError {
    case notFound
    case invalidInput(String)
    case blockedContent
    case underage

    var errorDescription: String? {
        switch self {
        case .notFound: return "We couldn't find what you were looking for."
        case .invalidInput(let m): return m
        case .blockedContent: return mortSafetyWarning
        case .underage: return "MORT is only available for users 13 and older."
        }
    }
}

protocol AuthServiceProtocol {
    var currentUserId: String? { get }
    func signIn(email: String, password: String) async throws -> String
    func signUp(email: String, password: String) async throws -> String
    func signOut() async
    func sendVerificationEmail(to email: String) async throws
}

protocol ProfileServiceProtocol {
    func fetchProfile(id: String) async throws -> UserProfile?
    func createProfile(_ profile: UserProfile) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func isUsernameAvailable(_ usernameLower: String) async throws -> Bool
}

protocol JobServiceProtocol {
    func fetchJobs() async throws -> [Job]
    func fetchJobs(postedBy posterId: String) async throws -> [Job]
    func fetchJob(id: String) async throws -> Job?
    func createJob(_ job: Job) async throws -> Job
    func applications(forApplicant applicantId: String) async throws -> [JobApplication]
    func applications(forJob jobId: String) async throws -> [JobApplication]
    func applications(forJob jobId: String, visibleTo requesterId: String) async throws -> [JobApplication]
    func apply(to job: Job, applicant: UserProfile, message: String) async throws -> JobApplication
    func setApplicationStatus(_ application: JobApplication, status: ApplicationStatus) async throws
    func startJob(jobId: String, requesterId: String) async throws
    func completeJob(jobId: String, applicationId: String, requesterId: String) async throws
}

protocol MessageServiceProtocol {
    func fetchConversations(for userId: String) async throws -> [Conversation]
    func fetchMessages(conversationId: String) async throws -> [Message]
    func sendMessage(conversationId: String, senderId: String, text: String) async throws -> Message
}

protocol NotificationServiceProtocol {
    func fetch(for userId: String) async throws -> [NotificationItem]
    func markRead(_ id: String) async throws
}

protocol ReportServiceProtocol {
    func submit(_ report: Report) async throws
    func fetchAll() async throws -> [Report]
    func setStatus(_ report: Report, status: ReportStatus) async throws
    func blockedUsers(for userId: String) async throws -> [UserProfile]
    func block(userId: String, named name: String) async throws
    func unblock(userId: String) async throws
}

protocol SafetyServiceProtocol {
    func scan(_ text: String) -> SafetyScanResult
    func scanSchedule(_ date: Date?) -> SafetyScanResult
    func guardianLinks(forTeen teenId: String) async throws -> [GuardianLink]
    func linkedTeens(forGuardian guardianId: String) async throws -> [GuardianLink]
    func trustedContacts(for teenId: String) async throws -> [TrustedContact]
    func addTrustedContact(_ contact: TrustedContact, for teenId: String) async throws
    func recentPings(forGuardian guardianId: String) async throws -> [SafetyPing]
    func checkIn(_ ping: SafetyPing) async throws
}

protocol AdminServiceProtocol {
    func allUsers() async throws -> [UserProfile]
    func allJobs() async throws -> [Job]
    func flaggedMessages() async throws -> [Message]
    func actionLog() async throws -> [AdminAction]
    func logAction(_ action: AdminAction) async throws
}

protocol StorageServiceProtocol {
    /// Returns a (possibly mock) URL for an uploaded avatar.
    func uploadAvatar(data: Data, userId: String) async throws -> String
}
