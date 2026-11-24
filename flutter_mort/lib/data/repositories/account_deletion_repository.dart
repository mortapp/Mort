import '../../core/errors/mort_error.dart';
import 'repository_base.dart';

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.source,
    required this.requestedAt,
    this.processingStartedAt,
    this.completedAt,
    this.retentionSummary,
  });

  final String id;
  final String status;
  final String source;
  final DateTime requestedAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final String? retentionSummary;

  bool get canCancel => status == 'requested';
  bool get canSubmitAnother => status == 'cancelled' || status == 'failed';
  bool get canIssueReceipt => const {
    'requested',
    'retry_pending',
    'retention_review',
    'cancelled',
  }.contains(status);

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    final source = json['source'];
    final requestedAt = _date(json['requested_at']);
    if (id is! String ||
        id.isEmpty ||
        status is! String ||
        status.isEmpty ||
        source is! String ||
        requestedAt == null) {
      throw const FormatException('Invalid deletion request');
    }
    return AccountDeletionRequest(
      id: id,
      status: status,
      source: source,
      requestedAt: requestedAt,
      processingStartedAt: _date(json['processing_started_at']),
      completedAt: _date(json['completed_at']),
      retentionSummary: json['retention_summary'] as String?,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class AccountDeletionRepository extends RepositoryBase {
  Future<AccountDeletionRequest?> getCurrentRequest() async {
    requireUserId();
    final raw = await client.rpc('get_my_account_deletion_request');
    if (raw is! Map) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The deletion service returned an unexpected response.',
      );
    }
    final result = Map<String, dynamic>.from(raw);
    if (result['ok'] != true) {
      throw MortCodedError(
        result['code'] as String? ?? 'unknown_permission_failure',
        'The deletion request could not be loaded.',
      );
    }
    final request = result['request'];
    if (request == null) return null;
    return AccountDeletionRequest.fromJson(
      Map<String, dynamic>.from(request as Map),
    );
  }

  Future<AccountDeletionRequest> requestDeletion() async {
    requireUserId();
    try {
      final raw = await client.rpc(
        'request_account_deletion',
        params: {'p_source': 'in_app'},
      );
      return _requestFromResult(
        raw,
        'The deletion request could not be created.',
      );
    } catch (_) {
      await recordOperationalFailure(
        eventType: 'deletion_failure',
        safeCode: 'deletion.request_failed',
      );
      rethrow;
    }
  }

  Future<AccountDeletionRequest> cancelDeletion() async {
    requireUserId();
    final raw = await client.rpc('cancel_account_deletion_request');
    return _requestFromResult(
      raw,
      'The deletion request could not be cancelled.',
    );
  }

  Future<String?> issueReceipt(String requestId) async {
    requireUserId();
    final code = await client.rpc(
      'issue_my_account_deletion_receipt',
      params: {'p_request_id': requestId},
    );
    return code is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(code)
        ? code
        : null;
  }

  AccountDeletionRequest _requestFromResult(Object? raw, String message) {
    if (raw is! Map) {
      throw MortCodedError('unknown_permission_failure', message);
    }
    final result = Map<String, dynamic>.from(raw);
    final request = result['request'];
    if (result['ok'] != true || request is! Map) {
      throw MortCodedError(
        result['code'] as String? ?? 'unknown_permission_failure',
        message,
      );
    }
    return AccountDeletionRequest.fromJson(Map<String, dynamic>.from(request));
  }
}
