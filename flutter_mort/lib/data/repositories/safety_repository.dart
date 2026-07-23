import 'repository_base.dart';

class SafetyRepository extends RepositoryBase {
  Future<void> createReport({
    String? targetUserId,
    String? targetJobId,
    String? targetMessageId,
    String? targetReviewId,
    required String reason,
    String? details,
  }) async {
    requireUserId();
    final category = switch (reason) {
      'harassment' => 'harassment',
      'scam' => 'scam',
      'exploitation' => 'child_safety_concern',
      'privacy' => 'personal_information_request',
      'discrimination' => 'discrimination',
      'unsafe_content' => 'unsafe_job_conditions',
      _ => 'other_urgent_concern',
    };
    final value = await client.rpc(
      'submit_safety_report',
      params: {
        'p_target_user_id': targetUserId,
        'p_target_job_id': targetJobId,
        'p_target_message_id': targetMessageId,
        'p_target_review_id': targetReviewId,
        'p_application_id': null,
        'p_category': category,
        'p_severity':
            {'child_safety_concern', 'sexual_conduct'}.contains(category)
            ? 'high'
            : 'moderate',
        'p_immediate_danger': false,
        'p_details': details?.trim().isNotEmpty == true
            ? details!.trim()
            : 'Safety concern submitted for restricted review.',
        'p_occurred_at': null,
        'p_location_type': null,
        'p_desired_outcome':
            'Review the concern and apply proportionate safety action.',
        'p_confidential_safety_feedback': {
          'child_safety_concern',
          'sexual_conduct',
        }.contains(category),
      },
    );
    if (value is! Map || value['ok'] != true) {
      throw StateError(
        value is Map
            ? (value['message'] ?? value['code'] ?? 'Report failed').toString()
            : 'Report failed',
      );
    }
  }

  Future<void> blockUser(String blockedId) async {
    await client.from('blocks').insert({
      'blocker_id': requireUserId(),
      'blocked_id': blockedId,
    });
  }

  Future<void> createSafetyPing({
    String status = 'needs_help',
    String? note,
  }) async {
    await client.from('safety_pings').insert({
      'teen_id': requireUserId(),
      'status': status,
      'note': note,
    });
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
          'id,teen_id,status,note,created_at,teen:profiles!safety_pings_teen_id_fkey(id,display_name,avatar_path)',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
