//
//  MortRouteDestination.swift
//  MORT iOS V8 — Navigation
//
//  The single resolver: EVERY `MortRoute`, `MortSheet` and `MortFullScreen`
//  value is handled here. If a route exists, its screen exists.
//

import SwiftUI

struct MortRouteDestination: View {
    let route: MortRoute
    let user: MortUser

    var body: some View {
        switch route {
        // MARK: Jobs
        case .jobDetail(let id):
            JobDetailView(jobId: id, user: user)
        case .jobCreate:
            JobCreateView()
        case .jobEdit(let id):
            JobEditView(jobId: id)
        case .jobPreview:
            JobPreviewView()
        case .jobApplicants(let id):
            JobApplicantsView(jobId: id)
        case .jobApply(let id):
            JobApplyView(jobId: id)
        case .myApplications:
            MyApplicationsView()
        case .jobExecution(let id):
            JobExecutionView(jobId: id, user: user)
        case .jobStartPin(let id):
            JobStartPinView(jobId: id, user: user)
        case .jobProof(let id):
            JobProofView(jobId: id)
        case .jobCompletion(let id):
            JobCompletionView(jobId: id, user: user)
        case .jobCancel(let id):
            JobCancelView(jobId: id)
        case .jobDispute(let id):
            JobDisputeView(jobId: id)
        case .settlement(let id):
            SettlementView(jobId: id, user: user)

        // MARK: Payment OS
        case .paymentReview(let id):
            PaymentReviewView(jobId: id)
        case .paymentProcessing(let id):
            PaymentProcessingView(jobId: id)
        case .paymentResult(let jobId, let state):
            PaymentResultView(jobId: jobId, state: state)
        case .paymentMethods:
            PaymentMethodPickerView()
        case .paymentMethodMissing:
            PaymentMethodMissingView()
        case .paymentRetry(let id):
            PaymentRetryView(jobId: id)
        case .paymentStatusCheck(let id):
            PaymentStatusCheckView(jobId: id)

        // MARK: Tips
        case .tipSelect(let jobId, let isLate):
            TipSelectView(jobId: jobId, isLate: isLate)
        case .tipCustom(let jobId):
            TipCustomView(jobId: jobId)
        case .tipConfirm(let jobId, let cents):
            TipConfirmView(jobId: jobId, tipCents: cents)

        case .fairPayInfo:
            FairPayInfoView()

        // MARK: Receipts
        case .receipt(let number):
            ReceiptView(receiptNumber: number)
        case .receiptUnavailable(let number):
            ReceiptUnavailableView(receiptNumber: number)
        case .receiptActions(let number):
            ReceiptActionsView(receiptNumber: number)
        case .receiptSupportReference(let number):
            ReceiptSupportReferenceView(receiptNumber: number)
        case .payoutSeparation(let number):
            PayoutSeparationView(receiptNumber: number)

        // MARK: History
        case .history:
            HistoryView(user: user)
        case .historySearch:
            HistorySearchView(user: user)
        case .annualExport:
            AnnualExportView()
        case .payoutStatus:
            PayoutStatusView()
        case .payoutSetup:
            PayoutSetupView()

        // MARK: Messaging
        case .conversation(let id):
            ConversationView(conversationId: id)

        // MARK: Profile
        case .publicProfile(let id):
            PublicProfileView(userId: id)
        case .myProfile:
            ProfileHomeView(user: user)
        case .editProfile:
            EditProfileView(user: user)
        case .reviews(let id):
            ReviewsView(userId: id)

        // MARK: Guardian
        case .guardianHome:
            GuardianHomeView(user: user)
        case .guardianTeen(let id):
            GuardianTeenDetailView(teenId: id)
        case .guardianInvite:
            GuardianInviteView()

        // MARK: Safety
        case .safetyCenter:
            SafetyCenterView(user: user)
        case .safetyCheckIn(let id):
            SafetyCheckInView(jobId: id)
        case .safetyContacts:
            SafetyContactsView()
        case .safetyReport(let jobId):
            SafetyReportView(jobId: jobId)
        case .emergency(let jobId):
            EmergencyView(jobId: jobId)

        // MARK: Support
        case .supportHome:
            SupportHomeView()
        case .supportCase(let id):
            SupportCaseView(caseId: id)
        case .supportNewCase(let topicId, let reference):
            SupportNewCaseView(topicId: topicId, reference: reference)

        // MARK: Financial
        case .earnings:
            EarningsView(user: user)
        case .financialGuide:
            FinancialGuideView()

        // MARK: Settings
        case .settings:
            SettingsView(user: user)
        case .notificationSettings:
            NotificationSettingsView()
        case .privacySettings:
            PrivacySettingsView()
        case .accountSettings:
            AccountSettingsView(user: user)
        case .deleteAccount:
            DeleteAccountView()
        case .notifications:
            NotificationsView()
        }
    }
}

struct MortSheetDestination: View {
    let sheet: MortSheet
    let user: MortUser

    var body: some View {
        switch sheet {
        case .tipSelect(let jobId, let isLate):
            NavigationStack {
                TipSelectView(jobId: jobId, isLate: isLate)
            }
        case .receiptActions(let number):
            ReceiptActionsView(receiptNumber: number)
                .presentationDetents([.medium])
        case .paymentMethods:
            NavigationStack {
                PaymentMethodPickerView()
            }
        case .safetyReport(let jobId):
            NavigationStack {
                SafetyReportView(jobId: jobId)
            }
        case .jobCancel(let jobId):
            NavigationStack {
                JobCancelView(jobId: jobId)
            }
        case .guardianInvite:
            NavigationStack {
                GuardianInviteView()
            }
        case .supportTopics:
            NavigationStack {
                SupportTopicPickerView()
            }
        case .filterYear:
            NavigationStack {
                Text("Year filter")
                    .mortBody()
            }
            .presentationDetents([.height(320)])
        }
    }
}

struct MortFullScreenDestination: View {
    let cover: MortFullScreen
    let user: MortUser

    var body: some View {
        switch cover {
        case .paymentProcessing(let jobId):
            // Rule R2: no back affordance while funding is in flight.
            PaymentProcessingView(jobId: jobId)
        case .emergency(let jobId):
            EmergencyView(jobId: jobId)
        case .jobStartPin(let jobId):
            NavigationStack {
                JobStartPinView(jobId: jobId, user: user)
            }
        }
    }
}
