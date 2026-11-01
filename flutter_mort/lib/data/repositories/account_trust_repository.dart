import '../../core/errors/mort_error.dart';
import '../models/account_trust.dart';
import 'repository_base.dart';

class AccountTrustRepository extends RepositoryBase {
  Future<AccountTrustProfile> getMyProfile() async {
    throw _unavailable('Account trust status is unavailable.');
  }

  Future<MarketplaceTrustEligibility> getEligibility({
    String action = 'browse',
    String? jobId,
  }) async {
    throw _unavailable('Marketplace trust eligibility is unavailable.');
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
    return Future.error(
      _unavailable('School affiliation requests are unavailable.'),
    );
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

  static MortCodedError _unavailable(String message) => MortCodedError(
    'account_trust_unavailable',
    '$message The production backend does not expose this service yet.',
  );
}
