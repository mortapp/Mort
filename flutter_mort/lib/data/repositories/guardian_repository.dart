import '../../core/errors/mort_error.dart';
import 'repository_base.dart';

class GuardianRepository extends RepositoryBase {
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  Future<Map<String, dynamic>> createInvite({String? email}) async {
    final result = await client.rpc(
      'create_guardian_invite_v2',
      params: {'p_invite_email': email},
    );
    return _requireSuccess(result);
  }

  Future<Map<String, dynamic>> acceptInvite(String code) async {
    final result = await client.rpc(
      'accept_guardian_invite',
      params: {'p_invite_code': code.trim().toUpperCase()},
    );
    return normalizeAcceptInviteResult(result);
  }

  static Map<String, dynamic> normalizeAcceptInviteResult(Object? value) {
    if (value is String && _uuidPattern.hasMatch(value)) {
      return {'ok': true, 'status': 'linked', 'link_id': value};
    }
    return _requireSuccess(value);
  }

  Future<void> skipSetup() async {
    _requireSuccess(await client.rpc('set_guardian_setup_skipped'));
  }

  Future<Map<String, dynamic>> cancelInvite(String linkId) async {
    return _requireSuccess(
      await client.rpc('cancel_guardian_invite', params: {'p_link_id': linkId}),
    );
  }

  Future<void> unlink(String linkId) async {
    _requireSuccess(
      await client.rpc('unlink_guardian', params: {'p_link_id': linkId}),
    );
  }

  Future<void> updatePreferences(
    String linkId, {
    required bool safetyPingAlerts,
    required bool jobCheckinAlerts,
    required bool acceptedJobSummary,
    required bool safetyWarningAlerts,
    required bool weeklyDigest,
    required bool optionalJobApprovalEnabled,
  }) async {
    _requireSuccess(
      await client.rpc(
        'set_guardian_alert_preferences',
        params: {
          'p_link_id': linkId,
          'p_safety_ping_alerts': safetyPingAlerts,
          'p_job_checkin_alerts': jobCheckinAlerts,
          'p_accepted_job_summary': acceptedJobSummary,
          'p_safety_warning_alerts': safetyWarningAlerts,
          'p_weekly_digest': weeklyDigest,
          'p_optional_job_approval_enabled': optionalJobApprovalEnabled,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> listConnections() async {
    requireUserId();
    final rows = await client
        .from('guardian_links')
        .select('*, guardian_preferences(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Map<String, dynamic> _requireSuccess(Object? value) {
    if (value is! Map) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    }
    final result = Map<String, dynamic>.from(value);
    if (result['ok'] == true) return result;
    throw MortCodedError(
      (result['code'] as String?) ?? 'unknown_permission_failure',
      (result['message'] as String?) ??
          'We could not complete that Guardian Mode action.',
    );
  }
}
