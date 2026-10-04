import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/admin_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/admin/admin_school_requests_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminRepository extends AdminRepository {
  String? decision;
  String? note;
  bool paged = false;
  final offsets = <int>[];

  @override
  Future<List<Map<String, dynamic>>> schoolDirectoryRequests({
    String status = 'pending',
    int limit = 25,
    int offset = 0,
  }) async {
    offsets.add(offset);
    if (paged && status == 'pending') {
      if (offset == 0) {
        return List.generate(
          limit,
          (index) => {
            'id': 'request-$index',
            'requested_school_name': 'Synthetic School $index',
            'requested_city': 'Indianapolis',
            'requested_state': 'IN',
          },
        );
      }
      return [
        {
          'id': 'request-older',
          'requested_school_name': 'Older School Request',
          'requested_city': 'Indianapolis',
          'requested_state': 'IN',
        },
      ];
    }
    return status == 'pending'
        ? [
            {
              'id': 'request-1',
              'requested_school_name': 'Synthetic Unknown Academy',
              'requested_city': 'Indianapolis',
              'requested_state': 'IN',
              'suggested_student_domain': 'students.example.invalid',
            },
          ]
        : const [];
  }

  @override
  Future<void> triageSchoolDirectoryRequest({
    required String requestId,
    required String decision,
    required String note,
  }) async {
    this.decision = decision;
    this.note = note;
  }
}

void main() {
  testWidgets('staff triage requires a note and never offers approval', (
    tester,
  ) async {
    final repository = _FakeAdminRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const AdminSchoolRequestsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic Unknown Academy'), findsOneWidget);
    expect(find.textContaining('students.example.invalid'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);

    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record decision'));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least 10 characters.'), findsOneWidget);
    expect(repository.decision, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Review note'),
      'Check the official school directory.',
    );
    await tester.tap(find.text('Record decision'));
    await tester.pumpAndSettle();
    expect(repository.decision, 'reviewing');
    expect(repository.note, 'Check the official school directory.');
  });

  testWidgets('staff can load older school requests', (tester) async {
    final repository = _FakeAdminRepository()..paged = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const AdminSchoolRequestsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Load more requests'));
    await tester.tap(find.text('Load more requests'));
    await tester.pumpAndSettle();
    expect(repository.offsets, [0, 25]);
    expect(find.text('Older School Request'), findsOneWidget);
    expect(find.text('Load more requests'), findsNothing);
  });
}
