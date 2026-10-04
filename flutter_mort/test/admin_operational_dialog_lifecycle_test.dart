import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/admin_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/admin/admin_operational_alerts_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminRepository extends AdminRepository {
  String? lastReason;

  @override
  Future<List<Map<String, dynamic>>> operationalAlerts({
    String status = 'open',
    int limit = 100,
  }) async => status == 'open'
      ? [
          {
            'id': 'alert-1',
            'status': 'open',
            'severity': 'warning',
            'category': 'reliability',
            'safe_code': 'provider_lag',
            'source': 'synthetic',
          },
        ]
      : const [];

  @override
  Future<void> acknowledgeOperationalAlert({
    required String alertId,
    required String status,
    required String reason,
  }) async {
    lastReason = reason;
  }
}

void main() {
  testWidgets('operational reason dialog closes without disposed controller', (
    tester,
  ) async {
    final repository = _FakeAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const AdminOperationalAlertsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Required operational reason'),
      'Synthetic reliability review note',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repository.lastReason, 'Synthetic reliability review note');
    expect(tester.takeException(), isNull);
  });
}
