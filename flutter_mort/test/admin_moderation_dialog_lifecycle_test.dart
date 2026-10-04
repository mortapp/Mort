import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/admin_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/admin/admin_moderation_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminRepository extends AdminRepository {
  String? reason;

  @override
  Future<Map<String, dynamic>> moderationRecord({
    required String recordType,
    required String recordId,
  }) async => {
    'ok': true,
    'record': {'id': recordId, 'status': 'open'},
  };

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String reason,
  }) async {
    this.reason = reason;
  }
}

void main() {
  testWidgets('moderation reason dialog closes without disposed controller', (
    tester,
  ) async {
    final repository = _FakeAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const AdminModerationDetailScreen(
            recordType: AdminModerationRecordType.report,
            recordId: '00000000-0000-4000-8000-000000000001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin review'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Required decision reason'),
      'Synthetic case review reason',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repository.reason, 'Synthetic case review reason');
    expect(tester.takeException(), isNull);
  });
}
