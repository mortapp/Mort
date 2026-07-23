import '../../core/errors/mort_error.dart';
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

  Future<Map<String, dynamic>> getPolicy() async {
    return _requireSuccess(await client.rpc('get_guardian_policy_for_user'));
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
    final updated = await client
        .from('guardian_preferences')
        .update({
          'safety_ping_alerts': safetyPingAlerts,
          'job_checkin_alerts': jobCheckinAlerts,
          'accepted_job_summary': acceptedJobSummary,
          'safety_warning_alerts': safetyWarningAlerts,
          'weekly_digest': weeklyDigest,
          'optional_job_approval_enabled': optionalJobApprovalEnabled,
        })
        .eq('link_id', linkId)
        .select('link_id')
        .maybeSingle();
    if (updated == null) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'These Guardian Mode preferences could not be updated.',
      );
    }
  }

  Future<void> setTeenPause(
    String teenId,
    bool paused, {
    String? reason,
  }) async {
    await client.rpc(
      'set_teen_pause',
      params: {'p_teen_id': teenId, 'p_paused': paused, 'p_reason': reason},
    );
  }

  Future<List<Map<String, dynamic>>> listConnections() async {
    requireUserId();
    final rows = await client
        .from('guardian_connections')
        .select(
          '*, guardian_preferences(*), teen:profiles!guardian_connections_teen_id_fkey(id,display_name,avatar_path), guardian:profiles!guardian_connections_guardian_id_fkey(id,display_name,avatar_path)',
        )
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
