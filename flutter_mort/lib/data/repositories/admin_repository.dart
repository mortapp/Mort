import 'repository_base.dart';

class AdminRepository extends RepositoryBase {
  Future<Map<String, dynamic>> monetizationOverview() async {
    final result = await client.rpc('admin_monetization_overview');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> queue(
    String table, {
    int limit = 50,
    Map<String, String> equals = const {},
    Map<String, String> notEquals = const {},
    String? orFilter,
  }) async {
    requireUserId();
    if (table == 'profiles') {
      final result = await client.rpc(
        'admin_list_profiles',
        params: {'p_limit': limit},
      );
      return List<Map<String, dynamic>>.from(result as List);
    }
    var query = client.from(table).select();
    for (final entry in equals.entries) {
      query = query.eq(entry.key, entry.value);
    }
    for (final entry in notEquals.entries) {
      query = query.neq(entry.key, entry.value);
    }
    if (orFilter != null && orFilter.trim().isNotEmpty) {
      query = query.or(orFilter);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> updateById(
    String table,
    String id,
    Map<String, dynamic> values,
  ) async {
    requireUserId();
    await client.from(table).update(values).eq('id', id);
  }

  Future<void> restrictUser(String userId, String status) async {
    requireUserId();
    await client
        .from('profiles')
        .update({'account_status': status})
        .eq('id', userId);
  }

  Future<void> reviewIdentity({
    required String verificationId,
    required String action,
    String? decisionCode,
  }) async {
    requireUserId();
    final approving = action == 'approve';
    final result = await client.rpc(
      'admin_review_identity_verification',
      params: {
        'p_verification_id': verificationId,
        'p_action': action,
        'p_decision_code': decisionCode,
        'p_identity_match_result': approving ? 'manual_pass' : 'not_checked',
        'p_liveness_result': approving ? 'manual_pass' : 'not_checked',
        'p_email_result': approving ? 'manual_pass' : 'not_checked',
        'p_phone_result': approving ? 'manual_pass' : 'not_checked',
        'p_address_result': approving ? 'manual_pass' : 'not_checked',
        'p_expires_at': approving
            ? DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 365))
                  .toIso8601String()
            : null,
      },
    );
    _requireSuccess(result, 'The identity review action was rejected.');
  }

  Future<void> updateIncident({
    required String incidentId,
    required String status,
    required String publicNote,
    String? restrictedNote,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_update_incident_case',
      params: {
        'p_incident_id': incidentId,
        'p_status': status,
        'p_public_status_note': publicNote,
        'p_restricted_note': restrictedNote,
        'p_severity': null,
      },
    );
    _requireSuccess(result, 'The incident update was rejected.');
  }

  void _requireSuccess(Object? value, String fallback) {
    if (value is! Map || value['ok'] != true) {
      final message = value is Map
          ? value['message'] ?? value['code'] ?? fallback
          : fallback;
      throw StateError(message.toString());
    }
  }
}
