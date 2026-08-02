import 'mort_error.dart';

String userFacingError(Object? error) {
  if (error is MortCodedError) {
    return applicationErrorMessage(error.code, fallback: error.message);
  }
  if (error is MortError) return error.message;

  final message = error?.toString().toLowerCase() ?? '';
  if (message.contains('invalid login credentials')) {
    return 'Invalid email or password.';
  }
  if (message.contains('email not confirmed')) {
    return 'Check your email and confirm your account before signing in.';
  }
  if (message.contains('already registered') ||
      message.contains('user already exists')) {
    return 'That email is already connected to an account.';
  }
  if (message.contains('exact_address_not_allowed')) {
    return 'Use only a general area. Share an exact address only through the protected job workflow when it is needed.';
  }
  if (message.contains('exact_location_not_allowed_in_ping')) {
    return 'Do not put an exact address or live location in a Safety Ping note. Attach the active job instead.';
  }
  if (message.contains('urgent_safety_rate_limited')) {
    return 'MORT could not record another urgent action right now. Contact local emergency services for immediate danger.';
  }
  if (message.contains('safety_report_rate_limited') ||
      message.contains('safety_ping_rate_limited')) {
    return 'That safety action was sent too many times. Wait and try again, or contact emergency services for immediate danger.';
  }
  if (message.contains('safety_request_payload_mismatch') ||
      message.contains('checkin_request_payload_mismatch')) {
    return 'This request changed while retrying. Close the screen, reopen it, and try again.';
  }
  if (message.contains('active_job_required')) {
    return 'That job is no longer active. Refresh Safety Center and try again.';
  }
  if (message.contains('checkin_not_active') ||
      message.contains('checkin_not_authorized')) {
    return 'That check-in is no longer available. Refresh Safety Center.';
  }
  if (message.contains('pending_checkin_limit_reached')) {
    return 'This job already has enough scheduled check-ins.';
  }
  if (message.contains('rate limit') ||
      message.contains('too many requests') ||
      message.contains('429')) {
    return 'Too many attempts. Wait a moment and try again.';
  }
  if (message.contains('jwt') ||
      message.contains('refresh token') ||
      message.contains('session expired')) {
    return 'Your session expired. Please sign in again.';
  }
  if (message.contains('row-level security') ||
      message.contains('permission denied') ||
      message.contains('forbidden')) {
    return 'You do not have permission to do that.';
  }
  if (message.contains('duplicate') ||
      message.contains('unique constraint') ||
      message.contains('already applied')) {
    return 'That action was already completed.';
  }
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('failed host lookup') ||
      message.contains('clientexception') ||
      message.contains('connection')) {
    return 'Check your connection and try again.';
  }
  if (message.contains('suspended') ||
      message.contains('banned') ||
      message.contains('restricted')) {
    return 'Your account is temporarily restricted. Contact support.';
  }

  return 'Something went wrong. Please try again.';
}

String applicationErrorMessage(String code, {String? fallback}) {
  return switch (code) {
    'guardian_link_required' || 'guardian_approval_required' =>
      'This job requires guardian approval. Link a guardian or choose another job.',
    'poster_verification_required' =>
      'This job is not accepting applications until the poster finishes verification.',
    'applicant_verification_required' =>
      'This poster requires verified applicants for this job.',
    'job_not_open' => 'This job is no longer accepting applications.',
    'job_already_assigned' => 'This job has already been assigned.',
    'application_already_exists' => 'You already applied to this job.',
    'applicant_is_job_owner' => 'You cannot apply to your own job.',
    'user_role_not_allowed' => 'Your account role cannot perform this action.',
    'user_account_restricted' =>
      'Your account is currently restricted. Check your account status or contact support.',
    'applicant_age_not_allowed' =>
      'Your age does not match this job requirement.',
    'job_expired' => 'This job has expired.',
    'job_start_time_passed' =>
      'The start time for this job has already passed.',
    'application_limit_reached' =>
      'You have reached the application limit. Finish or withdraw an application before adding another.',
    'invalid_application_transition' =>
      'That application action is no longer available. Refresh and try again.',
    'stale_application_state' =>
      'This application changed on another screen. Refresh before trying that action again.',
    'invalid_application_transition_request' =>
      'That application action is not supported. Refresh and try again.',
    'proof_required' =>
      'This job requires proof before it can be marked complete.',
    'proof_approval_required' =>
      'Approve the submitted proof before marking this job complete.',
    'proof_review_note_required' =>
      'Add at least 10 characters explaining what needs to change.',
    'proof_not_found' || 'stale_proof_submission' =>
      'That proof is no longer the current submission. Refresh and review the latest proof.',
    'invalid_proof_review_action' || 'invalid_proof_review_state' =>
      'That proof action is no longer available. Refresh and try again.',
    'invalid_job_transition' =>
      'That job action is not available in its current state.',
    'stale_job_state' =>
      'This job changed on another screen. Refresh before trying that action again.',
    'job_cancellation_reason_required' =>
      'Add a clear cancellation reason between 10 and 500 characters without contact details.',
    'job_in_progress_requires_dispute' =>
      'An in-progress job cannot be canceled from this screen. Use support or the dispute workflow.',
    'invalid_job_feed_filters' || 'invalid_job_feed_cursor' =>
      'Those job filters are no longer valid. Clear the filters and refresh.',
    'unsafe_job_content' =>
      'This job includes contact details or work MORT cannot publish. Review the safety fields and try again.',
    'invalid_job_title' => 'Use a clear job title between 5 and 80 characters.',
    'invalid_job_summary' =>
      'Add a short summary between 10 and 240 characters.',
    'invalid_job_description' =>
      'Add at least 20 characters of clear job detail.',
    'invalid_job_location' => 'Add a general area, city, and two-letter state.',
    'invalid_job_payment' => 'Enter an offered job amount greater than zero.',
    'invalid_job_response' =>
      'The job server returned an incomplete response. Try again safely.',
    'job_transportation_invalid' =>
      'Choose valid general transportation options without contact details or an exact address.',
    'invalid_job_schedule' =>
      'Check the job schedule. End time must be after the start time.',
    'poster_verification_pending' =>
      'Finish adult or business verification before publishing.',
    'guardian_invite_invalid_or_expired' =>
      'That guardian invite code is invalid or expired.',
    'guardian_invite_limit_reached' =>
      'You have reached the guardian invite limit. Cancel an old invite or try later.',
    'invalid_support_ticket' =>
      'Add a subject and a clear support message before submitting.',
    'support_ticket_limit_reached' =>
      'You have reached today\'s support ticket limit. Add updates to an existing ticket or try again tomorrow.',
    'proof_file_size_invalid' => 'Choose a proof image smaller than 10 MB.',
    'proof_file_type_invalid' => 'Choose a JPEG, PNG, or WebP proof image.',
    'invalid_proof_submission' => 'Start a new proof upload and try again.',
    'invalid_proof_path' || 'proof_object_not_found' =>
      'The proof upload could not be verified. Choose the photo again and retry.',
    'application_not_found' =>
      'This application is no longer available. Return to applications and refresh.',
    'verification_file_size_invalid' =>
      'Choose a verification image smaller than 10 MB.',
    'verification_file_type_invalid' =>
      'Choose a JPEG, PNG, or WebP verification image.',
    'invalid_verification_submission' =>
      'Start a new verification request and try again.',
    'invalid_verification_details' =>
      'Add a valid account or business name and choose an account type.',
    'verification_already_pending' =>
      'A verification request is already pending review.',
    'verification_object_not_found' || 'invalid_verification_path' =>
      'The verification upload could not be verified. Choose the image again and retry.',
    'unknown_permission_failure' =>
      'We could not complete that action. Refresh and try again.',
    _ =>
      fallback?.trim().isNotEmpty == true
          ? fallback!.trim()
          : 'We could not complete that action. Refresh and try again.',
  };
}
