import '../models/mission_pilot.dart';
import 'repository_base.dart';

class MissionPilotRepository extends RepositoryBase {
  Future<Map<String, dynamic>> releaseModeStatus() async {
    final result = await client.rpc('get_release_mode_status');
    return missionMap(result);
  }

  Future<MissionPilotDashboard> dashboard() async {
    requireUserId();
    final result = await client.rpc('get_mission_pilot_dashboard');
    return MissionPilotDashboard.fromMap(missionMap(result));
  }

  Future<ClosedPilotEligibility> eligibility({
    String action = 'browse',
    String? jobId,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'get_closed_pilot_eligibility',
      params: {'p_action': action, 'p_job_id': jobId},
    );
    return ClosedPilotEligibility.fromMap(missionMap(result));
  }

  Future<Map<String, dynamic>> acknowledge(String type) async {
    requireUserId();
    final result = await client.rpc(
      'acknowledge_pilot_policy',
      params: {'p_acknowledgement_type': type},
    );
    return missionMap(result);
  }

  Future<List<PartnerAttestation>> partnerAttestations() async {
    requireUserId();
    final result = missionMap(await client.rpc('get_my_partner_attestations'));
    final rows = result['attestations'];
    if (rows is! List) return const [];
    return rows
        .map((row) => PartnerAttestation.fromMap(missionMap(row)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> partnerStaffContexts() async {
    requireUserId();
    final result = missionMap(await client.rpc('get_my_partner_staff_context'));
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Partner access is unavailable.',
      );
    }
    final items = result['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> partnerConnectedParticipants(
    String organizationId,
  ) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'get_partner_connected_participants',
        params: {'p_organization_id': organizationId},
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Partner roster is unavailable.',
      );
    }
    final items = result['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createPartnerInvite({
    required String organizationId,
    String? programId,
    required DateTime expiresAt,
    int maxUses = 1,
    String purpose = 'pilot_enrollment',
  }) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'partner_create_pilot_invite',
        params: {
          'p_organization_id': organizationId,
          'p_program_id': programId,
          'p_expires_at': expiresAt.toUtc().toIso8601String(),
          'p_max_uses': maxUses,
          'p_purpose': purpose,
        },
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Invitation could not be created.',
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> partnerInvites(
    String organizationId,
  ) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'get_my_partner_invites',
        params: {'p_organization_id': organizationId},
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Invitations are unavailable.',
      );
    }
    final items = result['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> revokePartnerInvite({
    required String codeId,
    required String reason,
  }) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'partner_revoke_pilot_invite',
        params: {'p_code_id': codeId, 'p_reason': reason.trim()},
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Invitation could not be revoked.',
      );
    }
  }

  Future<Map<String, dynamic>> submitPartnerAttestation({
    required String organizationId,
    required String subjectUserId,
    required String factType,
    required DateTime expiresAt,
  }) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'submit_partner_attestation',
        params: {
          'p_subject_user_id': subjectUserId,
          'p_organization_id': organizationId,
          'p_fact_type': factType,
          'p_expires_at': expiresAt.toUtc().toIso8601String(),
        },
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Attestation could not be saved.',
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> organizationAttestations(
    String organizationId,
  ) async {
    requireUserId();
    final rows = await client
        .from('partner_attestations')
        .select(
          'id,subject_user_id,fact_type,status,attestation_statement,'
          'what_was_not_established,effective_at,expires_at,revoked_at',
        )
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> revokePartnerAttestation({
    required String attestationId,
    required String reason,
  }) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'revoke_partner_attestation',
        params: {'p_attestation_id': attestationId, 'p_reason': reason.trim()},
      ),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['code']?.toString() ?? 'Attestation could not be revoked.',
      );
    }
  }

  Future<void> updateDiscreetMode({
    required bool enabled,
    required bool appLockEnabled,
    required int automaticLockMinutes,
    required String quickExitDestination,
  }) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'update_discreet_mode',
        params: {
          'p_enabled': enabled,
          'p_app_lock_enabled': appLockEnabled,
          'p_automatic_lock_minutes': automaticLockMinutes,
          'p_quick_exit_destination': quickExitDestination,
        },
      ),
    );
    if (result['ok'] != true) {
      throw StateError(result['code']?.toString() ?? 'Discreet Mode failed.');
    }
  }

  Future<void> configureSupportCircle(bool enabled) async {
    requireUserId();
    final result = missionMap(
      await client.rpc(
        'configure_support_circle',
        params: {'p_enabled': enabled},
      ),
    );
    if (result['ok'] != true) {
      throw StateError(result['code']?.toString() ?? 'Support Circle failed.');
    }
  }

  Future<DocumentCollectionReadiness> documentReadiness() async {
    requireUserId();
    final result = await client.rpc('get_document_collection_readiness');
    return DocumentCollectionReadiness.fromMap(missionMap(result));
  }

  Future<List<Map<String, dynamic>>> documentCases() async {
    requireUserId();
    final rows = await client
        .from('document_review_cases')
        .select(
          'id,evidence_category,status,public_label,what_was_established,'
          'what_was_not_established,final_decision_at,expires_at',
        )
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<ResourceDirectoryEntry>> resources() async {
    requireUserId();
    final rows = await client
        .from('resource_directory_entries')
        .select(
          'id,organization_name,category,source_url,source_status,'
          'organization_verification_status,city,state,summary,'
          'emergency_limitations,availability_claimed',
        )
        .order('organization_name');
    return rows
        .map((row) => ResourceDirectoryEntry.fromMap(row))
        .toList(growable: false);
  }

  Future<void> bookmarkResource(String resourceId) async {
    await client.from('private_resource_bookmarks').upsert({
      'user_id': requireUserId(),
      'resource_id': resourceId,
    });
  }

  Future<List<IndependenceGoal>> goals() async {
    requireUserId();
    final rows = await client
        .from('independence_goals')
        .select(
          'id,goal_type,title,target_amount_cents,current_amount_cents,'
          'target_date,status',
        )
        .order('created_at', ascending: false);
    return rows
        .map((row) => IndependenceGoal.fromMap(row))
        .toList(growable: false);
  }

  Future<void> createGoal({
    required String goalType,
    required String title,
    int? targetAmountCents,
  }) async {
    await client.from('independence_goals').insert({
      'user_id': requireUserId(),
      'goal_type': goalType,
      'title': title.trim(),
      'target_amount_cents': targetAmountCents,
    });
  }

  Future<void> saveFuturePlan({
    DateTime? targetDate,
    String? educationPlan,
    String? employmentPlan,
    String? transportationPlan,
    int? savingsTargetCents,
  }) async {
    await client.from('future_independence_plans').upsert({
      'user_id': requireUserId(),
      'target_date': targetDate?.toIso8601String().split('T').first,
      'education_plan': _blankToNull(educationPlan),
      'employment_plan': _blankToNull(employmentPlan),
      'transportation_plan': _blankToNull(transportationPlan),
      'savings_target_cents': savingsTargetCents,
      'runaway_guidance_provided': false,
    });
  }

  Future<Map<String, dynamic>> privateWorkSummary() async {
    requireUserId();
    return missionMap(await client.rpc('get_private_work_summary'));
  }

  String? _blankToNull(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
