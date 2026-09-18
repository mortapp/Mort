//
//  MortBackendContractTests.swift
//  MORT iOS V8
//
//  Pins the native client to the real hosted MORT backend surface.
//  If these names drift, iOS must fail in CI rather than silently calling
//  invented placeholder RPCs.
//

import Testing
@testable import MORTIOSV8

struct MortBackendContractTests {
    @Test("Native client uses the hosted MORT job and application RPCs")
    func jobsAndApplications() {
        #expect(MortBackendContract.RPC.discoverJobs == "list_open_jobs_page")
        #expect(MortBackendContract.RPC.submitApplication == "submit_job_application")
        #expect(MortBackendContract.RPC.updateApplication == "update_application_status_v3")
        #expect(MortBackendContract.RPC.quickAcceptJob == "quick_accept_job_v1")
        #expect(MortBackendContract.RPC.saveJob == "save_job_draft_or_publish_without_fee_v1")
        #expect(MortBackendContract.RPC.manageJob == "manage_job_v2")
    }

    @Test("Native client uses the hosted MORT execution and safety RPCs")
    func executionAndSafety() {
        #expect(MortBackendContract.RPC.generateStartPin == "generate_job_start_pin")
        #expect(MortBackendContract.RPC.confirmStartPin == "confirm_job_start_pin_v2")
        #expect(MortBackendContract.RPC.respondCompletion == "respond_job_completion")
        #expect(MortBackendContract.RPC.activeCheckIns == "get_my_active_job_checkins")
        #expect(MortBackendContract.RPC.completeCheckIn == "complete_active_job_checkin")
        #expect(MortBackendContract.RPC.createSafetyPing == "create_safety_ping_v2")
        #expect(MortBackendContract.RPC.submitSafetyReport == "submit_safety_report_v2")
    }

    @Test("Native client uses the hosted MORT messaging, guardian and support RPCs")
    func trustAndCommunication() {
        #expect(MortBackendContract.RPC.messageThreads == "list_my_message_threads_page")
        #expect(MortBackendContract.RPC.threadMessages == "list_thread_messages_page")
        #expect(MortBackendContract.RPC.sendMessage == "send_safe_message_v2")
        #expect(MortBackendContract.RPC.markThreadRead == "mark_message_thread_read")
        #expect(MortBackendContract.RPC.blockUser == "block_user_v2")
        #expect(MortBackendContract.RPC.createGuardianInvite == "create_guardian_invite_v2")
        #expect(MortBackendContract.RPC.acceptGuardianInvite == "accept_guardian_invite")
        #expect(MortBackendContract.RPC.unlinkGuardian == "unlink_guardian")
        #expect(MortBackendContract.RPC.guardianTeenSummary == "get_guardian_teen_summary_v1")
        #expect(MortBackendContract.RPC.listSupportTickets == "list_my_support_tickets")
        #expect(MortBackendContract.RPC.supportThread == "get_my_support_ticket_thread")
    }

    @Test("Payment OS uses the hosted Stripe Edge Functions and financial RPCs")
    func payments() {
        #expect(MortBackendContract.EdgeFunction.fundingQuote == "stripe-create-job-funding-quote")
        #expect(MortBackendContract.EdgeFunction.paymentIntent == "stripe-create-job-payment-intent")
        #expect(MortBackendContract.EdgeFunction.tipPaymentIntent == "stripe-create-tip-payment-intent")
        #expect(MortBackendContract.EdgeFunction.stripeConfig == "stripe-config")
        #expect(MortBackendContract.RPC.paymentAttemptState == "get_my_payment_attempt_state_v1")
        #expect(MortBackendContract.RPC.financialHistory == "get_my_financial_history_v1")
        #expect(MortBackendContract.RPC.financialDocument == "get_my_financial_document_v1")
        #expect(MortBackendContract.RPC.financialPolicyConfig == "get_my_financial_policy_config_v1")
        #expect(MortBackendContract.RPC.jobSettlement == "get_my_job_settlement_v1")
        #expect(MortBackendContract.RPC.jobFinancialDocument == "get_my_job_financial_document_v1")
        #expect(MortBackendContract.RPC.tipAttemptState == "get_my_tip_attempt_state_v1")
        #expect(MortBackendContract.RPC.jobPaymentReceipt == "get_my_job_payment_receipt")
        #expect(MortBackendContract.RPC.payoutStatus == "get_my_stripe_payout_status")
    }


    @Test("Profile and account lifecycle use hosted MORT RPCs")
    func profileAndAccountLifecycle() {
        #expect(MortBackendContract.RPC.getMyProfile == "get_my_profile")
        #expect(MortBackendContract.RPC.updateMyProfile == "update_my_profile")
        #expect(MortBackendContract.RPC.requestAccountDeletion == "request_account_deletion")
    }
}
