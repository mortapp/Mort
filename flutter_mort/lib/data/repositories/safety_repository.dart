import 'package:uuid/uuid.dart';

import '../services/checkin_request_coordinator.dart';
import 'repository_base.dart';

typedef SafetyCheckinRpcInvoker =
    Future<dynamic> Function(String function, Map<String, dynamic> params);

class SafetyRepository extends RepositoryBase {
  static const _uuid = Uuid();

  SafetyRepository({
    CheckinRequestCoordinator? checkinRequestCoordinator,
    String? Function()? authenticatedUserId,
    SafetyCheckinRpcInvoker? checkinRpcInvoker,
  }) : _checkinRequestCoordinator =
           checkinRequestCoordinator ?? CheckinRequestCoordinator(),
       _authenticatedUserId = authenticatedUserId,
       _checkinRpcInvoker = checkinRpcInvoker;

  final CheckinRequestCoordinator _checkinRequestCoordinator;
  final String? Function()? _authenticatedUserId;
  final SafetyCheckinRpcInvoker? _checkinRpcInvoker;

  String _checkinUserId() => _authenticatedUserId?.call() ?? requireUserId();

  Future<dynamic> _invokeCheckinRpc(
    String function,
    Map<String, dynamic> params,
  ) {
    final injectedInvoker = _checkinRpcInvoker;
    if (injectedInvoker != null) return injectedInvoker(function, params);
    return client.rpc(function, params: params);
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
    final userId = _checkinUserId();
    return _checkinRequestCoordinator.execute(
      userId: userId,
      operation: CheckinOperation.schedule,
      entityId: applicationId,
      payload: {'minutes_from_now': minutesFromNow},
      preferredRequestId: clientRequestId,
      request: (requestId) => _invokeCheckinRpc('schedule_active_job_checkin', {
        'p_application_id': applicationId,
        'p_minutes_from_now': minutesFromNow,
        'p_client_request_id': requestId,
      }),
    );
  }

  Future<Map<String, dynamic>> completeActiveJobCheckin({
    required String checkinId,
    String? clientRequestId,
  }) async {
    final userId = _checkinUserId();
    return _checkinRequestCoordinator.execute(
      userId: userId,
      operation: CheckinOperation.complete,
      entityId: checkinId,
      payload: const {},
      preferredRequestId: clientRequestId,
      request: (requestId) => _invokeCheckinRpc('complete_active_job_checkin', {
        'p_checkin_id': checkinId,
        'p_client_request_id': requestId,
      }),
    );
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
