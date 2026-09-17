//
//  MortRoute.swift
//  MORT iOS V8 — App / Navigation
//
//  Type-safe destinations. Every screen in the app is reachable through one of
//  these values, and every value is handled in `MortRouteDestination`.
//
//  NAVIGATION QUALITY RULES (mandatory):
//   R1  Back from a receipt restores the history list's filter, query, year
//       and scroll position. Never reset to top/ALL.
//   R2  Processing screens disable back; exiting mid-flight routes through
//       status reconciliation, never back to review.
//   R3  Success "Done" returns to the job or origin — not stacked payment
//       screens.
//   R4  Every receipt is reachable two ways (direct CTA + history row) and
//       both open the SAME document route.
//   R5  Deep states preserve job context: title, worker and order # stay
//       visible.
//

import SwiftUI

nonisolated enum MortRoute: Hashable, Sendable {
    // Jobs
    case jobDetail(String)
    case jobCreate
    case jobEdit(String)
    case jobPreview
    case jobApplicants(String)
    case jobApply(String)
    case myApplications
    case jobExecution(String)
    case jobStartPin(String)
    case jobProof(String)
    case jobCompletion(String)
    case jobCancel(String)
    case jobDispute(String)
    case settlement(String)

    // Payment OS
    case paymentReview(String)
    case paymentProcessing(String)
    case paymentResult(jobId: String, state: PaymentState)
    case paymentMethods
    case paymentMethodMissing
    case paymentRetry(String)
    case paymentStatusCheck(String)

    // Tips
    case tipSelect(jobId: String, isLate: Bool)
    case tipCustom(String)
    case tipConfirm(jobId: String, tipCents: Int64)

    // Fair pay is embedded in job creation, plus a standalone explainer
    case fairPayInfo

    // Receipts
    case receipt(String)
    case receiptUnavailable(String)
    case receiptActions(String)
    case receiptSupportReference(String)
    case payoutSeparation(String)

    // History
    case history
    case historySearch
    case annualExport
    case payoutStatus
    case payoutSetup

    // Messaging
    case conversation(String)

    // Profile / people
    case publicProfile(String)
    case myProfile
    case editProfile
    case reviews(String)

    // Guardian
    case guardianHome
    case guardianTeen(String)
    case guardianInvite

    // Safety
    case safetyCenter
    case safetyCheckIn(String)
    case safetyContacts
    case safetyReport(jobId: String?)
    case emergency(jobId: String?)

    // Support
    case supportHome
    case supportCase(String)
    case supportNewCase(topicId: String, reference: String?)

    // Financial safety / earnings
    case earnings
    case financialGuide

    // Settings
    case settings
    case notificationSettings
    case privacySettings
    case accountSettings
    case deleteAccount
    case notifications
}

/// Sheet-presented destinations (modal, not pushed).
nonisolated enum MortSheet: Hashable, Identifiable, Sendable {
    case tipSelect(jobId: String, isLate: Bool)
    case receiptActions(String)
    case paymentMethods
    case safetyReport(jobId: String?)
    case jobCancel(String)
    case guardianInvite
    case supportTopics
    case filterYear

    var id: String {
        switch self {
        case .tipSelect(let j, let late): "tip-\(j)-\(late)"
        case .receiptActions(let r): "receipt-actions-\(r)"
        case .paymentMethods: "payment-methods"
        case .safetyReport(let j): "safety-report-\(j ?? "none")"
        case .jobCancel(let j): "job-cancel-\(j)"
        case .guardianInvite: "guardian-invite"
        case .supportTopics: "support-topics"
        case .filterYear: "filter-year"
        }
    }
}

/// Full-screen covers: flows that must own the whole screen.
nonisolated enum MortFullScreen: Hashable, Identifiable, Sendable {
    /// In-flight funding. Back is disabled here (rule R2).
    case paymentProcessing(String)
    case emergency(jobId: String?)
    case jobStartPin(String)

    var id: String {
        switch self {
        case .paymentProcessing(let j): "processing-\(j)"
        case .emergency(let j): "emergency-\(j ?? "none")"
        case .jobStartPin(let j): "pin-\(j)"
        }
    }
}

/// The app's navigation coordinator. One per tab stack, plus modal state.
@Observable
@MainActor
final class MortNavigator {
    var path: [MortRoute] = []
    var sheet: MortSheet?
    var fullScreen: MortFullScreen?

    func push(_ route: MortRoute) {
        path.append(route)
    }

    func present(_ sheet: MortSheet) {
        self.sheet = sheet
    }

    func present(_ cover: MortFullScreen) {
        self.fullScreen = cover
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Rule R3: return to the origin instead of leaving payment screens
    /// stacked behind a success state.
    func popToRoot() {
        path.removeAll()
    }

    /// Pops back to a specific route if it is on the stack, else to root.
    func popTo(_ route: MortRoute) {
        if let index = path.lastIndex(of: route) {
            path.removeSubrange((index + 1)...)
        } else {
            path.removeAll()
        }
    }

    func dismissSheet() { sheet = nil }
    func dismissFullScreen() { fullScreen = nil }

    /// Handles a deep link path such as "/receipts/K-260915-04827".
    /// Returns true when the link was understood.
    @discardableResult
    func handleDeepLink(_ path: String) -> Bool {
        let parts = path.split(separator: "/").map(String.init)
        guard let first = parts.first else { return false }
        switch (first, parts.count) {
        case ("jobs", 2):
            push(.jobDetail(parts[1]))
        case ("receipts", 2):
            push(.receipt(parts[1]))
        case ("messages", 2):
            push(.conversation(parts[1]))
        case ("history", 1):
            push(.history)
        case ("history", 2) where parts[1] == "payouts":
            push(.payoutStatus)
        case ("safety", 1):
            push(.safetyCenter)
        case ("support", 1):
            push(.supportHome)
        case ("settings", 1):
            push(.settings)
        case ("notifications", 1):
            push(.notifications)
        default:
            return false
        }
        return true
    }
}
