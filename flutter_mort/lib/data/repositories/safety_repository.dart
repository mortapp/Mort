import 'package:uuid/uuid.dart';
import 'dart:typed_data';

import 'repository_base.dart';

class SafetyRepository extends RepositoryBase {
  static const _uuid = Uuid();
  Future<Map<String, dynamic>> adultSafetyExit(
    String applicationId,
    String requestId,
  ) async => _requireSuccess(
    await client.rpc(
      'perform_adult_safety_exit',
      params: {
        'p_application_id': applicationId,
        'p_client_request_id': requestId,
      },
    ),
    'Safety end not confirmed',
  );
  Future<void> refreshTravelEta(String applicationId) async {
    requireUserId();
    // The service returns only an acknowledgment. Status is read from scoped
    // RPCs; no route, provider key or destination coordinates reach the app.
    await client.functions.invoke(
      'safety-travel-eta',
      body: {'applicationId': applicationId},
    );
  }

  Future<Map<String, dynamic>> recordPosterConnectionResponse(
    String applicationId,
    String response,
    String requestId,
  ) async => _requireSuccess(
    await client.rpc(
      'record_worker_connection_response',
      params: {
        'p_application_id': applicationId,
        'p_response': response,
        'p_client_request_id': requestId,
      },
    ),
    'Connection response not confirmed',
  );
  Future<List<Map<String, dynamic>>> staffEvidenceManifest(
    String incidentId,
  ) async {
    requireUserId();
    final rows = await client.rpc(
      'get_incident_evidence_manifest',
      params: {'p_incident_id': incidentId},
    );
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Uint8List> staffEvidenceImage(String evidenceId, String reason) async {
    final actor = requireUserId();
    final grant = _requireSuccess(
      await client.rpc(
        'authorize_incident_evidence_access',
        params: {'p_evidence_id': evidenceId, 'p_reason': reason},
      ),
      'Evidence access denied',
    );
    if (requireUserId() != actor ||
        grant['bucket_id'] != 'incident-evidence' ||
        grant['content_type'] != 'image/jpeg')
      throw StateError('Evidence preview unavailable');
    final bytes = await client.storage
        .from('incident-evidence')
        .download(grant['storage_path'] as String);
    if (requireUserId() != actor || bytes.length > 10 * 1024 * 1024)
      throw StateError('Evidence preview unavailable');
    return bytes;
  }

  Future<Map<String, dynamic>> getStaffSafetyContext(
    String incidentId,
    String reason,
  ) async => _requireSuccess(
    await client.rpc(
      'get_staff_safety_context',
      params: {'p_incident_id': incidentId, 'p_reason': reason},
    ),
    'Staff Safety context unavailable',
  );
  Future<List<Map<String, dynamic>>> listGuardianStatus() async {
    final value = _requireSuccess(
      await client.rpc('list_guardian_safety_status'),
      'Guardian safety unavailable',
    );
    return (value['teens'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getSafetyContact(String threadId) async =>
      _requireSuccess(
        await client.rpc(
          'get_safety_contact_thread',
          params: {'p_thread_id': threadId},
        ),
        'Safety Contact unavailable',
      );
  Future<String> openSafetyContact(String eventId, String target) async {
    final response = _requireSuccess(
      await client.rpc(
        'open_safety_contact',
        params: {'p_event_id': eventId, 'p_target': target},
      ),
      'Safety Contact unavailable',
    );
    return response['thread_id'] as String;
  }

  Future<Map<String, dynamic>> createReportCategories({
    required List<String> categories,
    String details = '',
    String? targetUserId,
    String? targetJobId,
    String? targetMessageId,
    String? targetReviewId,
    bool immediateDanger = false,
    required String clientRequestId,
  }) async => _requireSuccess(
    await client.rpc(
      'submit_safety_report_categories',
      params: {
        'p_categories': categories,
        'p_details': details,
        'p_target_user_id': targetUserId,
        'p_target_job_id': targetJobId,
        'p_target_message_id': targetMessageId,
        'p_target_review_id': targetReviewId,
        'p_immediate_danger': immediateDanger,
        'p_client_request_id': clientRequestId,
      },
    ),
    'Safety report not confirmed',
  );

  Future<Map<String, dynamic>> getJobRuntime(String applicationId) async =>
      _requireSuccess(
        await client.rpc(
          'get_job_safety_runtime',
          params: {'p_application_id': applicationId},
        ),
        'Job safety unavailable',
      );

  Future<List<Map<String, dynamic>>> listSafetyEvents() async {
    requireUserId();
    final result = await client.rpc('list_my_safety_events');
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getSafetyEvent(String id) async =>
      _requireSuccess(
        await client.rpc('get_safety_event_status', params: {'p_event_id': id}),
        'Safety event unavailable',
      );

  Future<void> recordContactReached(String id) async {
    _requireSuccess(
      await client.rpc(
        'record_safety_contact_reached',
        params: {'p_event_id': id},
      ),
      'Contact response not confirmed',
    );
  }

  Future<Map<String, dynamic>> getRuntime() async {
    requireUserId();
    return _requireSuccess(
      await client.rpc('get_my_safety_runtime'),
      'Safety status unavailable',
    );
  }

  Future<Map<String, dynamic>> performAction({
    required String action,
    String? applicationId,
    Map<String, dynamic> payload = const {},
    required String clientRequestId,
  }) async {
    final actorId = requireUserId();
    return _requireSuccess(
      await client.rpc(
        'perform_safety_action',
        params: {
          'p_action': action,
          'p_application_id': applicationId,
          'p_payload': {'actor_id': actorId, ...payload},
          'p_client_request_id': clientRequestId,
        },
      ),
      'Safety action was not confirmed',
    );
  }

  Future<Map<String, dynamic>> recordDeviceSnapshot({
    String? applicationId,
    int? batteryPercent,
    bool saverEnabled = false,
    double? latitude,
    double? longitude,
    DateTime? locationAt,
    required String expectedActorId,
  }) async {
    requireUserId();
    return _requireSuccess(
      await client.rpc(
        'record_safety_device_snapshot',
        params: {
          'p_application_id': applicationId,
          'p_battery_percent': batteryPercent,
          'p_saver_enabled': saverEnabled,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_location_at': locationAt?.toUtc().toIso8601String(),
          'p_expected_actor_id': expectedActorId,
        },
      ),
      'Device safety snapshot was not confirmed',
    );
  }

  Map<String, dynamic> _requireSuccess(dynamic value, String fallback) {
    if (value is Map && value['ok'] == true) {
      return Map<String, dynamic>.from(value);
    }
    throw StateError(
      value is Map
          ? (value['message'] ?? value['code'] ?? fallback).toString()
          : fallback,
    );
  }

  Future<Map<String, dynamic>> createReport({
    String? targetUserId,
    String? targetJobId,
    String? targetMessageId,
    String? targetReviewId,
    required String reason,
    required String details,
    bool immediateDanger = false,
    String? clientRequestId,
  }) async {
    requireUserId();
    final category = switch (reason) {
      'harassment' => 'harassment',
      'threats' => 'threats',
      'stalking' => 'stalking',
      'scam' => 'scam',
      'grooming_exploitation' => 'child_safety_concern',
      'privacy' => 'personal_information_request',
      'discrimination' => 'discrimination',
      'unsafe_job' => 'unsafe_job_conditions',
      'contact_sharing' => 'off_platform_pressure',
      'sexual_content' => 'sexual_conduct',
      'private_images' => 'inappropriate_images',
      'weapons_substances' => 'weapons',
      _ => 'other_urgent_concern',
    };
    final highSeverity = {
      'child_safety_concern',
      'sexual_conduct',
      'inappropriate_images',
      'stalking',
      'threats',
      'weapons',
    }.contains(category);
    final value = await client.rpc(
      'submit_safety_report_v2',
      params: {
        'p_target_user_id': targetUserId,
        'p_target_job_id': targetJobId,
        'p_target_message_id': targetMessageId,
        'p_target_review_id': targetReviewId,
        'p_application_id': null,
        'p_category': category,
        'p_severity': immediateDanger
            ? 'critical'
            : highSeverity
            ? 'high'
            : 'moderate',
        'p_immediate_danger': immediateDanger,
        'p_details': details.trim(),
        'p_occurred_at': null,
        'p_location_type': null,
        'p_desired_outcome':
            'Review the concern and apply proportionate safety action.',
        'p_confidential_safety_feedback': {
          'child_safety_concern',
          'sexual_conduct',
        }.contains(category),
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _requireSuccess(value, 'Report failed');
  }

  Future<Map<String, dynamic>> blockUser(
    String blockedId, {
    String? clientRequestId,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'block_user_v2',
      params: {
        'p_blocked_id': blockedId,
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _requireSuccess(value, 'Block failed');
  }

  Future<bool> unblockUser(String blockedId) async {
    requireUserId();
    final value = await client.rpc(
      'unblock_user',
      params: {'p_blocked_id': blockedId},
    );
    return _requireSuccess(value, 'Unblock failed')['removed'] == true;
  }

  Future<Map<String, dynamic>> createSafetyPing({
    String status = 'needs_help',
    String? note,
    String? jobId,
    bool immediateDanger = false,
    String? clientRequestId,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'create_safety_ping_v2',
      params: {
        'p_status': status,
        'p_note': note,
        'p_job_id': jobId,
        'p_immediate_danger': immediateDanger,
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _requireSuccess(value, 'Safety Ping failed');
  }

  Future<Map<String, dynamic>> getSafetyCenterConfig() async {
    requireUserId();
    final value = await client.rpc('get_safety_center_config');
    return _requireSuccess(value, 'Safety Center configuration unavailable');
  }

  Future<List<Map<String, dynamic>>> listActiveJobCheckins() async {
    requireUserId();
    final rows = await client.rpc('get_my_active_job_checkins');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> scheduleActiveJobCheckin({
    required String applicationId,
    required int minutesFromNow,
    String? clientRequestId,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'schedule_active_job_checkin',
      params: {
        'p_application_id': applicationId,
        'p_minutes_from_now': minutesFromNow,
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _requireSuccess(value, 'Unable to schedule check-in');
  }

  Future<Map<String, dynamic>> completeActiveJobCheckin({
    required String checkinId,
    String? clientRequestId,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'complete_active_job_checkin',
      params: {
        'p_checkin_id': checkinId,
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _requireSuccess(value, 'Unable to complete check-in');
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers() async {
    final rows = await client
        .from('blocks')
        .select()
        .eq('blocker_id', requireUserId())
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> listMyReports() async {
    final rows = await client
        .from('reports')
        .select('id,reason,status,created_at')
        .eq('reporter_id', requireUserId())
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> listVisibleSafetyPings() async {
    requireUserId();
    final rows = await client
        .from('safety_pings')
        .select(
          'id,teen_id,status,note,job_id,immediate_danger,created_at,teen:profiles!safety_pings_teen_id_fkey(id,display_name,avatar_path)',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
