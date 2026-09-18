//
//  MortBackendContract.swift
//  MORT iOS V8
//
//  Canonical names for the shared MORT backend. These values are pinned by
//  tests against the hosted Supabase/Stripe surface so iOS never drifts into
//  a parallel API vocabulary.
//

import Foundation

nonisolated enum MortBackendContract {
    nonisolated enum RPC {
        // Auth / profile
        static let getMyProfile = "get_my_profile"
        static let updateMyProfile = "update_my_profile"
        static let requestAccountDeletion = "request_account_deletion"

        // Marketplace / applications
        static let discoverJobs = "list_open_jobs_page"
        static let submitApplication = "submit_job_application"
        static let updateApplication = "update_application_status_v3"
        static let quickAcceptJob = "quick_accept_job_v1"
        static let saveJob = "save_job_draft_or_publish_without_fee_v1"
        static let manageJob = "manage_job_v2"

        // Execution
        static let generateStartPin = "generate_job_start_pin"
        static let confirmStartPin = "confirm_job_start_pin_v2"
        static let executionStatus = "get_job_execution_status"
        static let submitApplicationProof = "submit_application_proof"
        static let submitCompletionAssertion = "submit_job_completion_assertion"

        // Safety
        static let activeCheckIns = "get_my_active_job_checkins"
        static let completeCheckIn = "complete_active_job_checkin"
        static let createSafetyPing = "create_safety_ping_v2"
        static let submitSafetyReport = "submit_safety_report_v2"
        static let safetyCircle = "get_my_safety_circle"

        // Messaging
        static let messageThreads = "list_my_message_threads_page"
        static let threadMessages = "list_thread_messages_page"
        static let sendMessage = "send_safe_message_v2"
        static let markThreadRead = "mark_message_thread_read"
        static let blockUser = "block_user_v2"

        // Guardian
        static let createGuardianInvite = "create_guardian_invite_v2"
        static let acceptGuardianInvite = "accept_guardian_invite"
        static let unlinkGuardian = "unlink_guardian"
        static let linkedTeenFinancialSummary = "get_linked_teen_financial_summary"

        // Support
        static let listSupportTickets = "list_my_support_tickets"
        static let supportThread = "get_my_support_ticket_thread"
        static let createSupportTicket = "create_support_ticket"
        static let postSupportTicketMessage = "post_support_ticket_message"
        static let requestSupportHumanReview = "request_support_human_review"

        // Payment OS / financial documents
        static let jobFundingQuote = "get_my_job_funding_quote_v1"
        static let jobPaymentSummary = "get_job_payment_summary"
        static let paymentAttemptState = "get_my_payment_attempt_state_v1"
        static let financialHistory = "get_my_financial_history_v1"
        static let financialDocument = "get_my_financial_document_v1"
        static let jobPaymentReceipt = "get_my_job_payment_receipt"
        static let payoutStatus = "get_my_stripe_payout_status"
    }

    nonisolated enum EdgeFunction {
        static let stripeConfig = "stripe-config"
        static let fundingQuote = "stripe-create-job-funding-quote"
        static let paymentIntent = "stripe-create-job-payment-intent"
        static let tipPaymentIntent = "stripe-create-tip-payment-intent"
        static let connectedAccount = "stripe-create-connected-account"
        static let onboardingLink = "stripe-create-onboarding-link"
        static let connectedAccountStatus = "stripe-get-connected-account-status"
    }
}
