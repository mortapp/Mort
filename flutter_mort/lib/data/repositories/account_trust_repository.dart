import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/account_trust.dart';
import 'repository_base.dart';

class AccountTrustRepository extends RepositoryBase {
  static const _uuid = Uuid();
  Future<AccountTrustProfile> getMyProfile() async {
    requireUserId();
    final result = _map(await client.rpc('get_my_account_trust_profile'));
    _requireSuccess(result, 'Account trust profile could not be loaded.');
    return AccountTrustProfile.fromMap(result);
  }

  Future<MarketplaceTrustEligibility> getEligibility({
    String action = 'browse',
    String? jobId,
  }) async {
    requireUserId();
    final result = _map(
      await client.rpc(
        'get_marketplace_trust_eligibility',
        params: {'p_action': action, 'p_job_id': jobId},
      ),
    );
    return MarketplaceTrustEligibility.fromMap(result);
  }

  Future<Map<String, dynamic>> updateDeviceSecurity({
    required bool enabled,
    int lockAfterMinutes = 15,
  }) {
    return _action('update_account_security_preferences', {
      'p_device_reauthentication_enabled': enabled,
      'p_lock_after_minutes': lockAfterMinutes,
    }, 'Device security settings could not be updated.');
  }

  Future<Map<String, dynamic>> requestSchoolAffiliation(String email) {
    return _action('request_school_email_affiliation', {
      'p_school_email': email.trim().toLowerCase(),
    }, 'School affiliation could not be requested.');
  }

  Future<TeenVerificationStatus> getTeenVerificationStatus() async {
    requireUserId();
    final result = _map(await client.rpc('get_my_teen_verification'));
    _requireSuccess(result, 'Teen verification status could not be loaded.');
    return TeenVerificationStatus.fromMap(result);
  }

  Future<Map<String, dynamic>> startTeenVerification() {
    return _action(
      'start_my_teen_verification',
      const {},
      'Teen verification could not be started.',
    );
  }

  Future<Map<String, dynamic>> syncTeenSchoolAffiliation(String sessionId) {
    return _action('sync_my_teen_school_affiliation', {
      'p_session_id': sessionId,
    }, 'School-email verification could not be synchronized.');
  }

  Future<Map<String, dynamic>> uploadTeenSchoolId({
    required String sessionId,
    required Uint8List sourceBytes,
  }) async {
    final userId = requireUserId();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const MortCodedError(
        'school_id_image_invalid',
        'That image could not be read. Try taking a new photo.',
      );
    }

    var normalized = img.bakeOrientation(decoded);
    if (normalized.width > 2200 || normalized.height > 2200) {
      normalized = normalized.width >= normalized.height
          ? img.copyResize(normalized, width: 2200)
          : img.copyResize(normalized, height: 2200);
    }
    final bytes = Uint8List.fromList(img.encodeJpg(normalized, quality: 92));
    if (bytes.lengthInBytes < 1024 || bytes.lengthInBytes > 8 * 1024 * 1024) {
      throw const MortCodedError(
        'school_id_image_size_invalid',
        'Use a clear school-ID photo smaller than 8 MB.',
      );
    }

    final objectId = _uuid.v4();
    final path = '$userId/$sessionId/$objectId.jpg';
    final digest = sha256.convert(bytes).toString();

    try {
      await client.storage
          .from('teen-school-id')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      return await _action('register_my_teen_school_id', {
        'p_session_id': sessionId,
        'p_storage_path': path,
        'p_sha256': digest,
      }, 'The school ID could not be registered.');
    } catch (error) {
      try {
        await client.storage.from('teen-school-id').remove([path]);
      } catch (_) {
        // Cleanup is best effort; the server retention path remains fail-safe.
      }
      await recordUploadFailure(
        uploadKind: 'teen_school_id',
        safeCode: 'register_failed',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitTeenVerification() {
    return _action(
      'submit_my_teen_verification',
      const {},
      'Teen verification could not be submitted for review.',
    );
  }

  Future<List<Map<String, dynamic>>> getTeenVerificationReviewQueue({
    required String accessReason,
    required String caseId,
  }) async {
    final result = await _action('get_teen_verification_review_queue', {
      'p_access_reason': accessReason.trim(),
      'p_case_id': caseId.trim(),
    }, 'The teen verification queue is unavailable.');
    final items = result['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> claimTeenVerificationReview({
    required String sessionId,
    required String accessReason,
    required String caseId,
  }) {
    return _action('claim_teen_verification_review', {
      'p_session_id': sessionId,
      'p_access_reason': accessReason.trim(),
      'p_case_id': caseId.trim(),
    }, 'The teen verification case could not be claimed.');
  }

  Future<Map<String, dynamic>> authorizeTeenSchoolIdAccess({
    required String sessionId,
    required String accessReason,
    required String caseId,
  }) {
    return _action('authorize_teen_school_id_access', {
      'p_session_id': sessionId,
      'p_access_reason': accessReason.trim(),
      'p_case_id': caseId.trim(),
    }, 'Temporary school-ID access could not be authorized.');
  }

  Future<Uint8List> downloadTeenSchoolIdForReview({
    required String sessionId,
    required String accessReason,
    required String caseId,
  }) async {
    final grant = await authorizeTeenSchoolIdAccess(
      sessionId: sessionId,
      accessReason: accessReason,
      caseId: caseId,
    );
    final bucket = grant['bucket_id'] as String?;
    final path = grant['storage_path'] as String?;
    if (bucket == null || path == null || bucket != 'teen-school-id') {
      throw const MortCodedError(
        'invalid_school_id_access_grant',
        'The temporary school-ID access grant was invalid.',
      );
    }
    return client.storage.from(bucket).download(path);
  }

  Future<Map<String, dynamic>> reviewTeenVerification({
    required String sessionId,
    required String action,
    required bool schoolIdCurrent,
    required bool schoolMatch,
    required bool nameMatch,
    required bool schoolIdDobPresent,
    required String? observedAgeBand,
    required bool suspectedTamper,
    required String decisionCode,
    required String accessReason,
    required String caseId,
  }) {
    return _action('review_teen_verification', {
      'p_session_id': sessionId,
      'p_action': action,
      'p_school_id_current': schoolIdCurrent,
      'p_school_match': schoolMatch,
      'p_name_match': nameMatch,
      'p_school_id_dob_present': schoolIdDobPresent,
      'p_observed_age_band': observedAgeBand,
      'p_suspected_tamper': suspectedTamper,
      'p_decision_code': decisionCode.trim(),
      'p_access_reason': accessReason.trim(),
      'p_case_id': caseId.trim(),
    }, 'The teen verification review could not be saved.');
  }

  Future<Map<String, dynamic>> redeemPartnerCode(String code) {
    return _action('redeem_partner_invite_code', {
      'p_code': code.trim().toUpperCase(),
    }, 'The partner code could not be redeemed.');
  }

  Future<Map<String, dynamic>> requestBusinessRegistryMatch({
    required String jurisdiction,
    required String legalName,
    required String registrationNumber,
    required String officialSourceUrl,
    String? entityType,
  }) {
    return _action('request_business_registry_match', {
      'p_jurisdiction': jurisdiction.trim().toUpperCase(),
      'p_legal_business_name': legalName.trim(),
      'p_registration_number': registrationNumber.trim().toUpperCase(),
      'p_entity_type': _blankToNull(entityType),
      'p_official_source_url': officialSourceUrl.trim(),
    }, 'The official registry review could not be requested.');
  }

  Future<Map<String, dynamic>> requestBusinessRepresentativeClaim({
    required String checkId,
    required String relationship,
  }) {
    return _action('request_business_representative_claim', {
      'p_business_registry_check_id': checkId,
      'p_relationship_type': relationship,
      'p_attested': true,
    }, 'The representative claim could not be recorded.');
  }

  Future<Map<String, dynamic>> setIndicatorVisibility({
    required String signalType,
    required bool visible,
  }) {
    return _action('set_trust_signal_visibility', {
      'p_signal_type': signalType,
      'p_visible': visible,
    }, 'The indicator visibility could not be changed.');
  }

  Future<Map<String, dynamic>> submitAppeal({
    required String reason,
    String? signalId,
  }) {
    return _action('submit_account_trust_appeal', {
      'p_reason': reason.trim(),
      'p_signal_id': signalId,
    }, 'The trust appeal could not be submitted.');
  }

  Future<List<Map<String, dynamic>>> getAdminQueue({
    required String queue,
    required String accessReason,
    required String caseId,
  }) async {
    final result = await _action('get_admin_trust_review_queue', {
      'p_queue': queue,
      'p_access_reason': accessReason.trim(),
      'p_case_id': caseId.trim(),
    }, 'This trust queue is unavailable for the current admin role.');
    final items = result['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> _action(
    String function,
    Map<String, dynamic> params,
    String fallback,
  ) async {
    requireUserId();
    final result = _map(await client.rpc(function, params: params));
    _requireSuccess(result, fallback);
    return result;
  }

  static void _requireSuccess(Map<String, dynamic> result, String fallback) {
    if (result['ok'] == true) return;
    throw MortCodedError(
      result['code'] as String? ?? 'account_trust_action_failed',
      result['message'] as String? ?? fallback,
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const MortCodedError(
      'invalid_response',
      'The account trust service returned an unexpected response.',
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
