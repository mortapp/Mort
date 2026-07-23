import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/utils/safe_image.dart';
import '../models/trust_safety.dart';
import 'repository_base.dart';

class TrustSafetyRepository extends RepositoryBase {
  static const identityBucket = 'identity-evidence';
  static const incidentBucket = 'incident-evidence';
  static const _uuid = Uuid();

  Future<IdentityVerificationStatus> getIdentityStatus() async {
    requireUserId();
    final value = await client.rpc('get_my_identity_verification');
    return IdentityVerificationStatus.fromMap(_map(value));
  }

  Future<Map<String, dynamic>> startIdentityVerification({
    required String route,
    String? exceptionReason,
  }) async {
    final value = await client.rpc(
      'start_identity_verification',
      params: {
        'p_evidence_route': route,
        'p_attested': true,
        'p_exception_reason': _blankToNull(exceptionReason),
      },
    );
    return _success(value, 'Identity verification could not be started.');
  }

  Future<Map<String, dynamic>> createSandboxVerificationSession() {
    return startIdentityVerification(route: 'sandbox_simulation');
  }

  Future<void> uploadIdentityEvidence({
    required String verificationId,
    required String evidenceType,
    required Uint8List sourceBytes,
  }) async {
    throw const MortCodedError(
      'identity_document_collection_disabled',
      'MORT does not accept direct identity-document uploads.',
    );
  }

  Future<void> submitIdentityVerification(String verificationId) async {
    final value = await client.rpc(
      'submit_identity_verification',
      params: {'p_verification_id': verificationId, 'p_acknowledged': true},
    );
    _success(value, 'Identity verification could not be submitted.');
  }

  Future<void> appealIdentityVerification({
    required String verificationId,
    required String reason,
  }) async {
    final value = await client.rpc(
      'submit_identity_verification_appeal',
      params: {'p_verification_id': verificationId, 'p_reason': reason.trim()},
    );
    _success(value, 'The verification appeal could not be submitted.');
  }

  Future<List<SafetyIncidentSummary>> listMyIncidentCases() async {
    requireUserId();
    final value = await client.rpc('get_my_incident_cases');
    return _rows(value).map(SafetyIncidentSummary.fromMap).toList();
  }

  Future<void> submitIncidentAppeal({
    required String incidentId,
    required String reason,
  }) async {
    final value = await client.rpc(
      'submit_incident_appeal',
      params: {'p_incident_id': incidentId, 'p_reason': reason.trim()},
    );
    _success(value, 'The safety-case appeal could not be submitted.');
  }

  Future<String> createSafetyCircleInvite({
    required String relationship,
    required Map<String, bool> permissions,
  }) async {
    final result = _success(
      await client.rpc(
        'create_safety_circle_invite',
        params: {
          'p_relationship_label': relationship.trim(),
          'p_permissions': permissions,
        },
      ),
      'A Safety Circle invite could not be created.',
    );
    final code = result['invite_code'] as String?;
    if (code == null) {
      throw const MortCodedError(
        'invalid_response',
        'The server did not return an invitation code.',
      );
    }
    return code;
  }

  Future<void> acceptSafetyCircleInvite(String code) async {
    _success(
      await client.rpc(
        'accept_safety_circle_invite',
        params: {'p_invite_code': code.trim()},
      ),
      'The Safety Circle invite could not be accepted.',
    );
  }

  Future<List<SafetyCircleContact>> listSafetyCircle() async {
    requireUserId();
    final value = await client.rpc('get_my_safety_circle');
    return _rows(value).map(SafetyCircleContact.fromMap).toList();
  }

  Future<void> updateSafetyCirclePermissions({
    required String circleId,
    required Map<String, bool> permissions,
  }) async {
    _success(
      await client.rpc(
        'update_safety_circle_permissions',
        params: {'p_circle_id': circleId, 'p_permissions': permissions},
      ),
      'Safety Circle permissions could not be updated.',
    );
  }

  Future<void> unlinkSafetyCircle(String circleId) async {
    _success(
      await client.rpc(
        'unlink_safety_circle_member',
        params: {'p_circle_id': circleId},
      ),
      'The Safety Circle link could not be removed.',
    );
  }

  Future<JobSafetyAgreement?> getSafetyAgreement(String applicationId) async {
    final rows = await client
        .from('job_safety_agreements')
        .select()
        .eq('application_id', applicationId)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? null : JobSafetyAgreement.fromMap(list.first);
  }

  Future<void> saveSafetyPlan({
    required String applicationId,
    String? expectedPeople,
    required bool publicMeeting,
    required bool daylight,
    String? transportationPlan,
    int? checkinMinutes,
  }) async {
    _success(
      await client.rpc(
        'save_job_safety_plan',
        params: {
          'p_application_id': applicationId,
          'p_expected_people': _blankToNull(expectedPeople),
          'p_public_or_visible_meeting': publicMeeting,
          'p_daylight_preferred': daylight,
          'p_transportation_plan': _blankToNull(transportationPlan),
          'p_checkin_cadence_minutes': checkinMinutes,
        },
      ),
      'The Safety Plan could not be saved.',
    );
  }

  Future<void> confirmSafetyAgreement({
    required String applicationId,
    required int version,
  }) async {
    _success(
      await client.rpc(
        'confirm_job_safety_agreement',
        params: {
          'p_application_id': applicationId,
          'p_agreement_version': version,
        },
      ),
      'The current safety terms could not be confirmed.',
    );
  }

  Future<void> savePrivateJobLocation({
    required String jobId,
    required String exactAddress,
    String? arrivalInstructions,
  }) async {
    _success(
      await client.rpc(
        'save_job_private_location',
        params: {
          'p_job_id': jobId,
          'p_exact_address': exactAddress.trim(),
          'p_arrival_instructions': _blankToNull(arrivalInstructions),
          'p_access_notes': null,
        },
      ),
      'The restricted job location could not be saved.',
    );
  }

  Future<Map<String, dynamic>> getReleasedJobLocation(
    String applicationId,
  ) async {
    return _success(
      await client.rpc(
        'get_released_job_location',
        params: {'p_application_id': applicationId},
      ),
      'The exact job location is not available at this stage.',
    );
  }

  Future<Map<String, dynamic>> generateArrivalCode(String applicationId) async {
    return _success(
      await client.rpc(
        'generate_job_arrival_code',
        params: {'p_application_id': applicationId},
      ),
      'An arrival code could not be generated.',
    );
  }

  Future<Map<String, dynamic>> confirmArrival({
    required String applicationId,
    required String code,
    required bool personMatches,
  }) async {
    return _success(
      await client.rpc(
        'confirm_job_arrival_code',
        params: {
          'p_application_id': applicationId,
          'p_code': code.trim(),
          'p_person_matches_profile': personMatches,
        },
      ),
      'Arrival could not be confirmed.',
    );
  }

  Future<void> submitSafetyCancellation({
    required String applicationId,
    required String reason,
    String? details,
  }) async {
    _success(
      await client.rpc(
        'submit_safety_cancellation',
        params: {
          'p_application_id': applicationId,
          'p_reason': reason,
          'p_details': _blankToNull(details),
        },
      ),
      'The safety cancellation could not be recorded.',
    );
  }

  Future<Map<String, dynamic>> startCoarseLocationShare({
    required JobSafetyAgreement agreement,
    required String coarseLocation,
  }) async {
    final userId = requireUserId();
    final recipient = userId == agreement.teenId
        ? agreement.adultId
        : agreement.teenId;
    return _success(
      await client.rpc(
        'start_temporary_location_share',
        params: {
          'p_application_id': agreement.applicationId,
          'p_recipient_user_id': recipient,
          'p_mode': 'coarse_area',
          'p_expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .toIso8601String(),
          'p_coarse_location': coarseLocation.trim(),
          'p_latitude': null,
          'p_longitude': null,
          'p_explicit_consent': true,
        },
      ),
      'Temporary coarse location sharing could not be started.',
    );
  }

  Future<List<AuthorizedLocationShare>> listLocationShares() async {
    requireUserId();
    final value = await client.rpc('get_authorized_location_shares');
    return _rows(value).map(AuthorizedLocationShare.fromMap).toList();
  }

  Future<void> stopLocationShare(String shareId) async {
    _success(
      await client.rpc(
        'stop_temporary_location_share',
        params: {'p_share_id': shareId},
      ),
      'Temporary location sharing could not be stopped.',
    );
  }

  Future<List<AccountSessionSummary>> listAccountSessions() async {
    requireUserId();
    final value = await client.rpc('get_my_active_sessions');
    return _rows(value).map(AccountSessionSummary.fromMap).toList();
  }

  Future<void> reportAccountSession(AccountSessionSummary session) async {
    _success(
      await client.rpc(
        'report_account_security_concern',
        params: {
          'p_event_type': 'unrecognized_session',
          'p_session_reference': session.reference,
          'p_details':
              'User reported this session as unfamiliar from Flutter account security.',
        },
      ),
      'The account security concern could not be recorded.',
    );
  }

  Future<void> uploadIncidentEvidence({
    required String incidentId,
    required String evidenceType,
    required Uint8List sourceBytes,
  }) async {
    final userId = requireUserId();
    final evidenceId = _uuid.v4();
    final bytes = SafeImageProcessor.verification(
      sourceBytes,
      maximumBytes: 10 * 1024 * 1024,
    );
    final path = '$userId/$incidentId/$evidenceId.jpg';
    await client.storage
        .from(incidentBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '3600',
            upsert: false,
          ),
        );
    try {
      _success(
        await client.rpc(
          'register_incident_evidence',
          params: {
            'p_incident_id': incidentId,
            'p_evidence_id': evidenceId,
            'p_storage_path': path,
            'p_evidence_type': evidenceType.trim(),
            'p_sha256': sha256.convert(bytes).toString().toUpperCase(),
          },
        ),
        'Incident evidence could not be registered.',
      );
    } catch (_) {
      try {
        await client.storage.from(incidentBucket).remove([path]);
      } catch (_) {
        // Preserved evidence is intentionally not client-deletable.
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) {
      throw const MortCodedError(
        'invalid_response',
        'The backend returned an unexpected response.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) {
      throw const MortCodedError(
        'invalid_response',
        'The backend returned an unexpected list.',
      );
    }
    return List<Map<String, dynamic>>.from(value);
  }

  static Map<String, dynamic> _success(dynamic value, String fallback) {
    final result = _map(value);
    if (result['ok'] != true) {
      throw MortCodedError(
        result['code'] as String? ?? 'unknown_permission_failure',
        result['message'] as String? ?? fallback,
      );
    }
    return result;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
