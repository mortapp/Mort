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
    }

    @Test("Native client uses the hosted MORT execution and safety RPCs")
    func executionAndSafety() {
        #expect(MortBackendContract.RPC.generateStartPin == "generate_job_start_pin")
        #expect(MortBackendContract.RPC.confirmStartPin == "confirm_job_start_pin_v2")
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
        #expect(MortBackendContract.RPC.createGuardianInvite == "create_guardian_invite_v2")
        #expect(MortBackendContract.RPC.acceptGuardianInvite == "accept_guardian_invite")
        #expect(MortBackendContract.RPC.unlinkGuardian == "unlink_guardian")
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
        #expect(MortBackendContract.RPC.payoutStatus == "get_my_stripe_payout_status")
    }
}
