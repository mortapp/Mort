import Foundation
import Observation

enum AppRoute: Hashable {
    case jobFeed
    case jobDetail(UUID)
    case savedJobs
    case jobWizard(UUID?)
    case myJobs
    case jobManagement(UUID)
    case applications(ApplicationListMode)
    case applicationDetail(UUID, ApplicationListMode)
    case proofUpload(UUID)
    case proofReview(UUID)
    case messages
    case messageThread(UUID)
    case guardianMode
    case guardianSafetyPings
    case safetyCenter
    case safetyCircle
    case incidentHistory
    case jobSafety(UUID)
    case activeSessions
    case accountTrust
    case deviceSecurity
    case passkeys
    case schoolAffiliation
    case partnerCode
    case businessRegistry
    case digitalID
    case trustAppeal
    case trustAdmin
    case pilotEligibility
    case partnerInvitation
    case partnerAffiliation
    case discreetMode
    case supportCircle
    case futureIndependence
    case earningsGoals
    case resourceDirectory
    case pilotJobSafety
    case verificationExplanation
    case documentReviewStatus
    case documentCaptureQuality
    case livePresence
    case livePresenceAccessibility
    case teamAccessReview
    case reviewerAssignment
    case report(ReportTarget)
    case blockedUsers
    case notifications
    case profile
    case businessProfile
    case emergencyContact
    case avatar
    case reviews
    case leaveReview(jobID: UUID, subjectID: UUID)
    case activity
    case verification
    case monetization(String?)
    case customerCenter
    case support
    case adminQueue(AdminQueue)
    case settings
    case username
    case adPreferences
    case paymentPreferences
    case jobContracts
    case jobContract(UUID)
    case jobContractChange(UUID)
    case paymentStatus(UUID)
    case nonpaymentReport(UUID)
    case paymentDispute(UUID)
    case evidenceExport(UUID)
    case pushSettings
    case accountDeletion
    case legal(LegalDocument)
    case legalCenter
    case teenTermsSummary
    case legalAcceptance(LegalRequirementItem)
    case biometricSettings
    case unavailable(String, String)
}

enum ApplicationListMode: String, Hashable, Sendable {
    case teen
    case adult
    case guardian
}

enum LegalDocument: String, CaseIterable, Identifiable, Hashable, Sendable {
    case terms
    case privacy
    case communityRules
    case paymentDisclaimer
    case verificationDisclaimer
    case adDisclosure
    case subscriptionDisclosure
    case teenSafety
    case guardianGuide
    case aiTransparency

    var id: String { rawValue }
    var title: String {
        switch self {
        case .terms: "Terms"
        case .privacy: "Privacy"
        case .communityRules: "Community rules"
        case .paymentDisclaimer: "Payment disclaimer"
        case .verificationDisclaimer: "Verification disclaimer"
        case .adDisclosure: "Ad disclosure"
        case .subscriptionDisclosure: "Subscription disclosure"
        case .teenSafety: "Teen safety"
        case .guardianGuide: "Guardian guide"
        case .aiTransparency: "AI transparency"
        }
    }
}

@MainActor
@Observable
final class Router {
    var path: [AppRoute] = []

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func reset() { path.removeAll() }
}
