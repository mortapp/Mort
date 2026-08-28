import 'repository_base.dart';

class AdminRepository extends RepositoryBase {
  Future<Map<String, dynamic>> moderationRecord({
    required String recordType,
    required String recordId,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_get_moderation_record',
      params: {'p_record_type': recordType, 'p_record_id': recordId},
    );
    final value = Map<String, dynamic>.from(result as Map);
    _requireSuccess(value, 'The moderation record is unavailable.');
    return value;
  }

  Future<Map<String, dynamic>> monetizationOverview() async {
    final result = await client.rpc('admin_monetization_overview');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> operationalAlerts({
    String status = 'open',
    int limit = 100,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'get_admin_operational_alerts',
      params: {'p_status': status, 'p_limit': limit},
    );
    final value = Map<String, dynamic>.from(result as Map);
    _requireSuccess(value, 'The operational alert queue is unavailable.');
    final items = value['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> acknowledgeOperationalAlert({
    required String alertId,
    required String status,
    required String reason,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_acknowledge_operational_alert',
      params: {
        'p_alert_id': alertId,
        'p_resolution_status': status,
        'p_reason': reason.trim(),
      },
    );
    _requireSuccess(result, 'The operational alert action was rejected.');
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

  Future<void> moderateJob({
    required String jobId,
    required String action,
    required String reasonCode,
    required String note,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_moderate_job',
      params: {
        'p_job_id': jobId,
        'p_action': action,
        'p_reason_code': reasonCode,
        'p_note': note.trim(),
      },
    );
    _requireSuccess(result, 'The job moderation action was rejected.');
  }

  Future<void> moderateReview({
    required String reviewId,
    required String action,
    required String reasonCode,
    required String note,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_moderate_review',
      params: {
        'p_review_id': reviewId,
        'p_action': action,
        'p_reason_code': reasonCode,
        'p_note': note.trim(),
      },
    );
    _requireSuccess(result, 'The review moderation action was rejected.');
  }

  Future<void> setAccountStatus({
    required String userId,
    required String status,
    required String reason,
    String reasonCode = 'safety_report_related',
    DateTime? expiresAt,
  }) async {
    requireUserId();
    final effectiveExpiry = status == 'suspended'
        ? (expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 24)))
        : null;
    final result = await client.rpc(
      'admin_set_account_status_v2',
      params: {
        'p_user_id': userId,
        'p_status': status,
        'p_reason_code': reasonCode,
        'p_reason': reason.trim(),
        'p_expires_at': effectiveExpiry?.toIso8601String(),
      },
    );
    _requireSuccess(result, 'The account status action was rejected.');
  }

  Future<List<Map<String, dynamic>>> banAppeals() async {
    requireUserId();
    final rows = await client
        .from('account_ban_appeals')
        .select()
        .or('status.eq.submitted,status.eq.assigned')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> claimBanAppeal({
    required String appealId,
    required String reason,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_claim_account_ban_appeal',
      params: {'p_appeal_id': appealId, 'p_reason': reason.trim()},
    );
    _requireSuccess(result, 'The appeal assignment was rejected.');
  }

  Future<void> reviewBanAppeal({
    required String appealId,
    required String decision,
    required String reason,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_review_account_ban_appeal',
      params: {
        'p_appeal_id': appealId,
        'p_decision': decision,
        'p_reason': reason.trim(),
      },
    );
    _requireSuccess(result, 'The ban appeal decision was rejected.');
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String reason,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'admin_update_report_status',
      params: {'p_report_id': reportId, 'p_status': status, 'p_reason': reason},
    );
    _requireSuccess(result, 'The report action was rejected.');
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
