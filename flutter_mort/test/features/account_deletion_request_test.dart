import 'package:flutter_mort/data/repositories/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = <String, dynamic>{
    'id': '44444444-4444-4444-8444-444444444444',
    'source': 'web',
    'requested_at': '2026-11-22T12:00:00Z',
  };

  test('only pending requests can be cancelled', () {
    for (final status in [
      'requested',
      'processing',
      'retry_pending',
      'retention_review',
      'cancelled',
      'failed',
      'completed',
    ]) {
      final request = AccountDeletionRequest.fromJson({
        ...base,
        'status': status,
      });
      expect(request.canCancel, status == 'requested');
      expect(
        request.canSubmitAnother,
        {'cancelled', 'failed'}.contains(status),
      );
      expect(
        request.canIssueReceipt,
        {
          'requested',
          'retry_pending',
          'retention_review',
          'cancelled',
        }.contains(status),
      );
    }
  });

  test('malformed backend responses cannot become actionable requests', () {
    expect(() => AccountDeletionRequest.fromJson(base), throwsFormatException);
    expect(
      () => AccountDeletionRequest.fromJson({
        ...base,
        'requested_at': 'invalid',
        'status': 'requested',
      }),
      throwsFormatException,
    );
  });
}
