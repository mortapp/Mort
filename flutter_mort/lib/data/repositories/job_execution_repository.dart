import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import 'repository_base.dart';

class JobExecutionStatus {
  const JobExecutionStatus({
    required this.applicationId,
    required this.jobId,
    required this.contractId,
    required this.role,
    required this.state,
    required this.fundingStatus,
    required this.startPinActive,
    required this.finishPinActive,
    required this.livePaymentEnabled,
    this.startPinExpiresAt,
    this.finishPinExpiresAt,
    this.startedAt,
    this.completionPendingAt,
    this.reviewWindowEndsAt,
  });

  final String applicationId;
  final String jobId;
  final String contractId;
  final String role;
  final String state;
  final String fundingStatus;
  final bool startPinActive;
  final bool finishPinActive;
  final bool livePaymentEnabled;
  final DateTime? startPinExpiresAt;
  final DateTime? finishPinExpiresAt;
  final DateTime? startedAt;
  final DateTime? completionPendingAt;
  final DateTime? reviewWindowEndsAt;

  bool get isAdult => role == 'adult';
  bool get isTeen => role == 'teen';

  factory JobExecutionStatus.fromJson(Map<String, dynamic> json) =>
      JobExecutionStatus(
        applicationId: json['application_id']?.toString() ?? '',
        jobId: json['job_id']?.toString() ?? '',
        contractId: json['contract_id']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        state: json['state']?.toString() ?? 'awaiting_start',
        fundingStatus: json['funding_status']?.toString() ?? 'missing',
        startPinActive: json['start_pin_active'] == true,
        finishPinActive: json['finish_pin_active'] == true,
        livePaymentEnabled: json['live_payment_enabled'] == true,
        startPinExpiresAt: _date(json['start_pin_expires_at']),
        finishPinExpiresAt: _date(json['finish_pin_expires_at']),
        startedAt: _date(json['started_at']),
        completionPendingAt: _date(json['completion_pending_at']),
        reviewWindowEndsAt: _date(json['review_window_ends_at']),
      );

  static DateTime? _date(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '');
}

enum JobPinKind { start, finish }

class GeneratedJobPin {
  const GeneratedJobPin({
    required this.kind,
    required this.pin,
    required this.expiresAt,
  });

  final JobPinKind kind;
  final String pin;
  final DateTime? expiresAt;
}

class JobExecutionRepository extends RepositoryBase {
  static const _uuid = Uuid();

  Future<JobExecutionStatus> getStatus(String applicationId) async {
    final result = await _rpc('get_job_execution_status', {
      'p_application_id': applicationId,
    });
    return JobExecutionStatus.fromJson(result);
  }

  Future<GeneratedJobPin> generateStartPin(String applicationId) async {
    final result = await _rpc('generate_job_start_pin', {
      'p_application_id': applicationId,
      'p_client_request_id': _uuid.v4(),
    });
    return GeneratedJobPin(
      kind: JobPinKind.start,
      pin: result['start_pin']?.toString() ?? '',
      expiresAt: JobExecutionStatus._date(result['expires_at']),
    );
  }

  Future<Map<String, dynamic>> confirmStartPin({
    required String applicationId,
    required String pin,
    required bool personMatchesProfile,
    String? clientRequestId,
  }) async {
    return _rpc('confirm_job_start_pin_v2', {
      'p_application_id': applicationId,
      'p_pin': pin,
      'p_person_matches_profile': personMatchesProfile,
      'p_client_request_id': clientRequestId ?? _uuid.v4(),
    });
  }

  Future<Map<String, dynamic>> reportPersonMismatch(String applicationId) =>
      confirmStartPin(
        applicationId: applicationId,
        pin: '000000',
        personMatchesProfile: false,
      );

  Future<GeneratedJobPin> generateFinishPin(String applicationId) async {
    final result = await _rpc('generate_job_finish_pin', {
      'p_application_id': applicationId,
      'p_client_request_id': _uuid.v4(),
    });
    return GeneratedJobPin(
      kind: JobPinKind.finish,
      pin: result['finish_pin']?.toString() ?? '',
      expiresAt: JobExecutionStatus._date(result['expires_at']),
    );
  }

  Future<Map<String, dynamic>> confirmFinishPin({
    required String applicationId,
    required String pin,
    String? clientRequestId,
  }) async {
    return _rpc('confirm_job_finish_pin_v2', {
      'p_application_id': applicationId,
      'p_pin': pin,
      'p_client_request_id': clientRequestId ?? _uuid.v4(),
    });
  }

  Future<Map<String, dynamic>> reportFinishPinUnavailable({
    required String applicationId,
    required DateTime actualStartAt,
    required DateTime actualFinishAt,
    required String workCompleted,
    required String statement,
  }) => _rpc('report_finish_pin_unavailable', {
    'p_application_id': applicationId,
    'p_actual_start_at': actualStartAt.toUtc().toIso8601String(),
    'p_actual_finish_at': actualFinishAt.toUtc().toIso8601String(),
    'p_work_completed': workCompleted.trim(),
    'p_statement': statement.trim(),
    'p_client_request_id': _uuid.v4(),
  });

  Future<Map<String, dynamic>> requestAdultCancellation({
    required String applicationId,
    required String reason,
  }) => _rpc('request_adult_job_cancellation', {
    'p_application_id': applicationId,
    'p_reason': reason.trim(),
    'p_client_request_id': _uuid.v4(),
  });

  Future<Map<String, dynamic>> reportPossibleTeenAbandonment({
    required String applicationId,
    required String statement,
  }) => _rpc('report_possible_teen_abandonment', {
    'p_application_id': applicationId,
    'p_statement': statement.trim(),
    'p_client_request_id': _uuid.v4(),
  });

  Future<Map<String, dynamic>> respondToAbandonment({
    required String applicationId,
    required String statement,
    required bool safetyRelated,
  }) => _rpc('respond_to_teen_abandonment', {
    'p_application_id': applicationId,
    'p_statement': statement.trim(),
    'p_safety_related': safetyRelated,
    'p_client_request_id': _uuid.v4(),
  });

  Future<Map<String, dynamic>> _rpc(
    String function,
    Map<String, dynamic> parameters,
  ) async {
    requireUserId();
    final raw = await client.rpc(function, params: parameters);
    if (raw is! Map) {
      await recordOperationalFailure(
        eventType: function.contains('pin')
            ? 'pin_failure'
            : 'job_transition_failure',
        safeCode: 'job.invalid_execution_response',
      );
      throw const MortCodedError(
        'invalid_job_execution_response',
        'The job status service returned an invalid response.',
      );
    }
    final result = Map<String, dynamic>.from(raw);
    if (result['ok'] != true) {
      final code = result['code']?.toString() ?? 'job_execution_failed';
      await recordOperationalFailure(
        eventType: function.contains('pin')
            ? 'pin_failure'
            : 'job_transition_failure',
        safeCode: code,
      );
      throw MortCodedError(code, _message(code));
    }
    return result;
  }

  String _message(String code) => switch (code) {
    'confirmed_job_funding_required' =>
      'The funded payment must be confirmed before a start PIN is available.',
    'outside_start_window' =>
      'The start PIN is available only during the approved job start window.',
    'current_contract_acceptance_required' ||
    'contract_changed_reconfirmation_required' =>
      'Both participants must accept the current agreement before continuing.',
    'mutual_safety_agreement_required' =>
      'Complete the job safety agreement before continuing.',
    'pin_generation_rate_limited' =>
      'A PIN was generated recently. Wait briefly before requesting another.',
    'start_pin_expired' || 'finish_pin_expired' =>
      'That PIN expired. Ask the adult to generate a new one in person.',
    'start_pin_locked' || 'finish_pin_locked' =>
      'PIN entry is temporarily locked after repeated attempts.',
    'start_pin_invalid' || 'finish_pin_invalid' =>
      'That PIN was not accepted. Check the six digits and try again.',
    'start_pin_already_used' || 'finish_pin_already_used' =>
      'That PIN was already used. Refresh the job status before continuing.',
    'pin_request_payload_mismatch' =>
      'The PIN entry changed during a retry. Check the six digits and submit again.',
    'adult_report_required' =>
      'There is no open abandonment report requiring your response.',
    'response_confirmation_required' =>
      'Confirm the response before submitting it.',
    'abandonment_statement_required' =>
      'Add a few more factual details before submitting.',
    'active_dispute_blocks_finish_pin' =>
      'An open dispute must be resolved before a finish PIN can be generated.',
    'active_safety_incident_blocks_start' =>
      'An open safety report is blocking the start PIN for this job.',
    'participant_not_eligible' =>
      'One participant is not currently eligible to start this job.',
    'job_participant_required' =>
      'Only the assigned teen and adult can view this job progress.',
    _ =>
      'The job progress action could not be completed. Refresh and try again.',
  };
}
