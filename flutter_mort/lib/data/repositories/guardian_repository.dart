import '../../core/errors/mort_error.dart';
import '../models/production_backend_rows.dart';
import 'repository_base.dart';

class GuardianRepository extends RepositoryBase {
  Future<Map<String, dynamic>> createInvite({String? email}) async {
    final result = await client.rpc(
      'create_guardian_invite_v2',
      params: {'p_invite_email': email},
    );
    return _requireSuccess(result);
  }

  Future<Map<String, dynamic>> acceptInvite(String code) async {
    try {
      final result = await client.rpc(
        'accept_guardian_invite',
        params: {'p_invite_code': code.trim().toUpperCase()},
      );
      return {'ok': true, 'link_id': result};
    } catch (error) {
      if (error.toString().contains('guardian_invite_invalid_or_expired')) {
        throw const MortCodedError(
          'guardian_invite_invalid_or_expired',
          'That guardian invite code is invalid or expired.',
        );
      }
      if (error.toString().contains(
        'guardian_invite_accept_rate_limit_reached',
      )) {
        throw const MortCodedError(
          'guardian_invite_accept_rate_limit_reached',
          'Too many attempts. Please wait a while before trying again.',
        );
      }
      rethrow;
    }
  }

  Future<void> skipSetup() async {
    _requireSuccess(await client.rpc('set_guardian_setup_skipped'));
  }

  Future<Map<String, dynamic>> cancelInvite(String linkId) async {
    return _requireSuccess(
      await client.rpc('cancel_guardian_invite', params: {'p_link_id': linkId}),
    );
  }

  Future<Map<String, dynamic>> resendInvite(String linkId) async {
    return _requireSuccess(
      await client.rpc('resend_guardian_invite', params: {'p_link_id': linkId}),
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
        .from(productionGuardianLinksTable)
        .select(
          '*, guardian_preferences(*), teen:profiles!guardian_links_teen_user_id_fkey(id,display_name,avatar_path), guardian:profiles!guardian_links_guardian_user_id_fkey(id,display_name,avatar_path)',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              mapProductionGuardianLink(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
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
