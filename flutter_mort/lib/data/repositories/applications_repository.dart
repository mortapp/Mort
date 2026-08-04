import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/application.dart';
import '../models/profile.dart';
import '../models/proof.dart';
import 'repository_base.dart';

class ApplicationsRepository extends RepositoryBase {
  Future<MortApplication?> getApplication(
    String applicationId, {
    UserRole? role,
  }) async {
    final query = client
        .from('applications')
        .select(
          role == UserRole.adult
              ? '*, jobs!inner(*), teen:profiles!applications_teen_id_fkey(display_name,avatar_path)'
              : '*, jobs(*), teen:profiles!applications_teen_id_fkey(display_name,avatar_path)',
        )
        .eq('id', applicationId);

    if (role != null) {
      final id = requireUserId();
      if (role == UserRole.teen) {
        query.eq('teen_id', id);
      } else if (role == UserRole.adult) {
        query.eq('jobs.poster_id', id);
      } else if (role == UserRole.guardian) {
        query.eq('guardian_id', id);
      }
    }

    final row = await query.maybeSingle();
    return row == null
        ? null
        : MortApplication.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<MortApplication>> listMyApplications() async {
    final id = requireUserId();
    final rows = await client
        .from('applications')
        .select(
          '*, jobs(*), teen:profiles!applications_teen_id_fkey(display_name,avatar_path)',
        )
        .or('teen_id.eq.$id,guardian_id.eq.$id')
        .order('created_at', ascending: false);
    return _applications(rows);
  }

  Future<List<MortApplication>> listApplicationsForMyJobs() async {
    final id = requireUserId();
    final rows = await client
        .from('applications')
        .select(
          '*, jobs!inner(*), teen:profiles!applications_teen_id_fkey(display_name,avatar_path)',
        )
        .eq('jobs.poster_id', id)
        .order('created_at', ascending: false);
    return _applications(rows);
  }

  Future<ApplicationEligibility> checkEligibility(String jobId) async {
    final result = await client.rpc(
      'get_job_application_eligibility',
      params: {'p_job_id': jobId},
    );
    return ApplicationEligibility.fromMap(_rpcMap(result));
  }

  Future<MortApplication> applyToJob(
    String jobId, {
    String? note,
    bool availabilityConfirmed = false,
    List<String> portfolioIds = const [],
  }) async {
    final result = await client.rpc(
      'submit_job_application',
      params: {
        'p_job_id': jobId,
        'p_note': note,
        'p_availability_confirmed': availabilityConfirmed,
        'p_portfolio_ids': portfolioIds,
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    return MortApplication.fromMap(
      Map<String, dynamic>.from(map['application'] as Map),
    );
  }

  Future<MortApplication> updateStatus(
    String applicationId,
    String action, {
    String? clientRequestId,
    DateTime? expectedUpdatedAt,
  }) async {
    final result = await client.rpc(
      'update_application_status_v3',
      params: {
        'p_application_id': applicationId,
        'p_action': action,
        'p_client_request_id': clientRequestId ?? const Uuid().v4(),
        'p_expected_updated_at': expectedUpdatedAt?.toUtc().toIso8601String(),
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    return MortApplication.fromMap(
      Map<String, dynamic>.from(map['application'] as Map),
    );
  }

  Future<List<Map<String, dynamic>>> listStatusEvents(
    String applicationId,
  ) async {
    final rows = await client
        .from('application_status_events')
        .select()
        .eq('application_id', applicationId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<ProofUpload>> listProofs(String applicationId) async {
    final rows = await client
        .from('proof_uploads')
        .select()
        .eq('application_id', applicationId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(ProofUpload.fromMap).toList(growable: false);
  }

  Future<ProofUpload> reviewProof(
    String proofId, {
    required String action,
    String? note,
  }) async {
    final result = await client.rpc(
      'review_application_proof',
      params: {
        'p_proof_id': proofId,
        'p_action': action,
        'p_note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    return ProofUpload.fromMap(Map<String, dynamic>.from(map['proof'] as Map));
  }

  static List<MortApplication> _applications(Object? rows) {
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(MortApplication.fromMap).toList(growable: false);
  }

  static Map<String, dynamic> _rpcMap(Object? result) {
    if (result is! Map) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  static void _throwIfFailed(Map<String, dynamic> result) {
    if (result['ok'] == true) return;
    throw MortCodedError(
      (result['code'] as String?) ?? 'unknown_permission_failure',
      (result['message'] as String?) ??
          'We could not complete that application action.',
    );
  }
}
