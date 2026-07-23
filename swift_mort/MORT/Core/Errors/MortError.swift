import Foundation

enum MortError: LocalizedError, Equatable, Sendable {
    case authenticationRequired
    case configuration(String)
    case backend(code: String, message: String?)
    case invalidResponse
    case invalidInput(String)
    case featureUnavailable(String)
    case network(String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Sign in to continue."
        case let .configuration(message), let .invalidInput(message),
             let .featureUnavailable(message), let .network(message),
             let .underlying(message):
            return message
        case let .backend(code, message):
            return BackendErrorTranslator.message(for: code, fallback: message)
        case .invalidResponse:
            return "The server returned an unexpected response. Try again."
        }
    }
}

enum BackendErrorTranslator {
    static func message(for code: String, fallback: String? = nil) -> String {
        switch code {
        case "guardian_link_required", "guardian_approval_required":
            return "This job requires guardian approval. Link a guardian or choose another job."
        case "poster_verification_required", "poster_verification_pending":
            return "The poster must finish verification before this action is available."
        case "applicant_verification_required":
            return "This job requires verified applicants."
        case "job_not_open": return "This job is no longer accepting applications."
        case "job_already_assigned": return "This job has already been assigned."
        case "application_already_exists": return "You already applied to this job."
        case "applicant_is_job_owner": return "You cannot apply to your own job."
        case "user_role_not_allowed": return "Your account role cannot perform this action."
        case "user_account_restricted":
            return "Your account is restricted. Review your account status or contact support."
        case "applicant_age_not_allowed": return "Your age does not match this job requirement."
        case "job_expired": return "This job has expired."
        case "job_start_time_passed": return "The start time for this job has passed."
        case "application_limit_reached":
            return "You reached the active application limit. Finish or withdraw one before applying again."
        case "invalid_application_transition":
            return "That application action is no longer available. Refresh and try again."
        case "proof_required": return "This job requires proof before it can be marked complete."
        case "proof_approval_required": return "Approve the submitted proof before marking this job complete."
        case "proof_review_note_required": return "Add at least 10 characters explaining what needs to change."
        case "proof_not_found", "stale_proof_submission":
            return "That proof is no longer the current submission. Refresh and review the latest proof."
        case "invalid_proof_review_action", "invalid_proof_review_state":
            return "That proof action is no longer available. Refresh and try again."
        case "invalid_job_transition": return "That job action is unavailable in its current state."
        case "unsafe_job_content":
            return "This job includes contact details or work MORT cannot publish. Review it and try again."
        case "invalid_job_title": return "Use a clear job title between 5 and 80 characters."
        case "invalid_job_summary": return "Add a summary between 10 and 240 characters."
        case "invalid_job_description": return "Add at least 20 characters of job detail."
        case "invalid_job_location": return "Add a general area, city, and two-letter state."
        case "invalid_job_payment": return "Enter a positive payment amount."
        case "invalid_job_schedule": return "Check that the schedule and end time are valid."
        case "guardian_invite_invalid_or_expired": return "That guardian invite is invalid or expired."
        case "guardian_invite_limit_reached": return "Cancel an old invite or try again later."
        case "invalid_support_ticket": return "Add a subject and clear support message."
        case "support_ticket_limit_reached": return "You reached today's support ticket limit."
        case "proof_file_size_invalid": return "Choose a proof image smaller than 10 MB."
        case "proof_file_type_invalid": return "Choose a JPEG, PNG, HEIC, or WebP proof image."
        case "invalid_proof_submission": return "Start a new proof upload and try again."
        case "invalid_proof_path", "proof_object_not_found":
            return "The proof upload could not be verified. Choose the image again."
        case "application_not_found": return "This application is no longer available."
        case "verification_file_size_invalid": return "Choose a verification image smaller than 10 MB."
        case "verification_file_type_invalid": return "Choose a supported verification image."
        case "invalid_verification_submission": return "Start a new verification request and try again."
        case "invalid_verification_details": return "Add a valid name and account type."
        case "verification_already_pending": return "A verification request is already pending."
        case "verification_object_not_found", "invalid_verification_path":
            return "The verification upload could not be verified. Choose the image again."
        case "rate_limit_exceeded": return "Too many attempts. Wait a moment and try again."
        default:
            let clean = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let clean, !clean.isEmpty { return clean }
            return "We could not complete that action. Refresh and try again."
        }
    }

    static func translate(_ error: Error) -> MortError {
        if let error = error as? MortError { return error }
        let value = error.localizedDescription.lowercased()
        if value.contains("invalid login credentials") { return .underlying("Invalid email or password.") }
        if value.contains("email not confirmed") { return .underlying("Confirm your email before signing in.") }
        if value.contains("already registered") { return .underlying("That email is already registered.") }
        if value.contains("rate limit") || value.contains("429") {
            return .underlying("Too many attempts. Wait a moment and try again.")
        }
        if value.contains("unsafe contact") || value.contains("phone number") ||
            value.contains("social") || value.contains("exact address") || value.contains("secrecy") {
            return .underlying("That message was blocked by MORT's safety scanner. Keep contact and location planning in MORT and remove private details.")
        }
        if value.contains("participant is blocked") {
            return .underlying("Messaging is unavailable because a participant is blocked.")
        }
        if value.contains("proof_approval_required") {
            return .backend(code: "proof_approval_required", message: nil)
        }
        if value.contains("paused messaging") {
            return .underlying("Guardian Mode has paused messaging for this teen account.")
        }
        if value.contains("jwt") || value.contains("session") && value.contains("expired") {
            return .underlying("Your session expired. Sign in again.")
        }
        if value.contains("network") || value.contains("offline") || value.contains("connection") {
            return .network("Check your connection and try again.")
        }
        return .underlying("Something went wrong. Please try again.")
    }
}
