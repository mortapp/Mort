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
    requireUserId();
    final result = await client.rpc(
      'get_my_job_applications',
      params: {'p_application_id': applicationId},
    );
    final applications = _applicationsFromCurrentUserRpc(result);
    return applications.isEmpty ? null : applications.first;
  }

  Future<List<MortApplication>> listMyApplications({
    UserRole role = UserRole.teen,
  }) async {
    final id = requireUserId();
    final applications = _applicationsFromCurrentUserRpc(
      await client.rpc(
        'get_my_job_applications',
        params: {'p_application_id': null},
      ),
    );
    return switch (role) {
      UserRole.teen =>
        applications
            .where((application) => application.teenId == id)
            .toList(growable: false),
      UserRole.guardian =>
        applications
            .where(
              (application) =>
                  application.job?.requiresGuardianApproval == true,
            )
            .toList(growable: false),
      UserRole.adult || UserRole.admin => const [],
    };
  }

  Future<List<MortApplication>> listApplicationsForMyJobs() async {
    final id = requireUserId();
    final applications = _applicationsFromCurrentUserRpc(
      await client.rpc(
        'get_my_job_applications',
        params: {'p_application_id': null},
      ),
    );
    return applications
        .where((application) => application.job?.posterId == id)
        .toList(growable: false);
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
    DateTime? expectedUpdatedAt,
  }) async {
    const supportedActions = {
      'accepted',
      'shortlisted',
      'rejected',
      'viewed',
      'withdrawn',
    };
    if (!supportedActions.contains(action)) {
      throw const MortCodedError(
        'application_action_not_supported',
        'That application action is not available.',
      );
    }
    final result = await client.rpc(
      'update_my_job_application_status',
      params: {
        'p_application_id': applicationId,
        'p_action': action,
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

  static List<MortApplication> _applicationsFromCurrentUserRpc(Object? value) {
    final response = _rpcMap(value);
    _throwIfFailed(response);
    final items = response['items'];
    if (items is! List) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected applications response.',
      );
    }
    return items
        .whereType<Map>()
        .map((row) => MortApplication.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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
