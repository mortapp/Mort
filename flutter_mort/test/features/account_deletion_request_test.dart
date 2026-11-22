import 'package:flutter/material.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/data/repositories/account_deletion_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/settings/account_management_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeletionRepository extends AccountDeletionRepository {
  int calls = 0;
  bool acceptRecentSession = false;

  @override
  Future<AccountDeletionRequest?> getCurrentRequest() async => null;

  @override
  Future<AccountDeletionRequest> requestDeletion() async {
    calls++;
    if (!acceptRecentSession) {
      throw const MortCodedError(
        'recent_reauthentication_required',
        'Verification required',
      );
    }
    return AccountDeletionRequest(
      id: '44444444-4444-4444-8444-444444444444',
      status: 'requested',
      source: 'in_app',
      requestedAt: DateTime.utc(2026, 11, 22),
    );
  }

  @override
  Future<String?> issueReceipt(String requestId) async => 'a' * 64;
}

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

  testWidgets('recent sign-in still requires confirmation and server success', (
    tester,
  ) async {
    final repository = _DeletionRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountDeletionRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AccountDeletionRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final option = find.text('Use my recent sign-in');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Confirm your password'), findsNothing);

    final submit = find.text('Submit deletion request');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.calls, 0);

    final confirmation = find.byType(TextField);
    await tester.enterText(confirmation, 'DELETE');
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(find.text('Request status: requested'), findsNothing);
    expect(find.textContaining('Sign out and sign in again'), findsOneWidget);

    repository.acceptRecentSession = true;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Request status: requested'), findsOneWidget);
    expect(find.text('a' * 64), findsOneWidget);
  });
}
