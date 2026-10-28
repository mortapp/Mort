import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/application.dart';
import '../models/profile.dart';
import '../models/proof.dart';
import 'repository_base.dart';

class ApplicationsRepository extends RepositoryBase {
  Future<List<MortApplication>> _loadVisibleApplications({
    String? applicationId,
  }) async {
    final result = _rpcMap(
      await client.rpc(
        'get_my_job_applications',
        params: {'p_application_id': applicationId},
      ),
    );
    _throwIfFailed(result);
    final items = result['items'];
    if (items is! List) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected application response.',
      );
    }
    return _applications(items);
  }

  Future<MortApplication?> getApplication(
    String applicationId, {
    UserRole? role,
  }) async {
    final applications = await _loadVisibleApplications(
      applicationId: applicationId,
    );
    if (applications.isEmpty) return null;
    final application = applications.first;
    if (role != null) {
      final id = requireUserId();
      final isRoleOwner = switch (role) {
        UserRole.teen => application.teenId == id,
        UserRole.adult => application.job?.posterId == id,
        UserRole.guardian => application.guardianId == id,
        UserRole.admin => false,
      };
      if (!isRoleOwner) return null;
    }
    return application;
  }

  Future<List<MortApplication>> listMyApplications() async {
    final id = requireUserId();
    final applications = await _loadVisibleApplications();
    final own =
        applications
            .where(
              (application) =>
                  application.teenId == id || application.guardianId == id,
            )
            .toList(growable: false)
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
    return own;
  }

  Future<List<MortApplication>> listApplicationsForMyJobs() async {
    final id = requireUserId();
    final applications = await _loadVisibleApplications();
    final forMyJobs =
        applications
            .where((application) => application.job?.posterId == id)
            .toList(growable: false)
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
    return forMyJobs;
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

  /// Atomically claims a Quick-Accept-eligible single-worker job. The
  /// server (quick_accept_job_v1) is the sole source of truth for who
  /// wins -- this never shows success before the RPC actually confirms
  /// it. Throws MortCodedError with a specific code (e.g. 'offer_taken',
  /// 'not_quick_accept_eligible', 'applicant_age_not_allowed') on any
  /// denial so callers can render a precise, non-alarming state rather
  /// than a generic error.
  Future<MortApplication> quickAccept(String jobId) async {
    final result = await client.rpc(
      'quick_accept_job_v1',
      params: {'p_job_id': jobId, 'p_client_request_id': const Uuid().v4()},
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
