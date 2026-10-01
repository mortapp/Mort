import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/school_directory_entry.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/school_directory_repository.dart';
import 'package:flutter_mort/features/auth/school_directory_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolDirectoryRepository extends SchoolDirectoryRepository {
  final queries = <String>[];
  int requestCalls = 0;

  @override
  Future<Map<String, dynamic>> requestSchool({
    required String schoolName,
    required String city,
    required String state,
    String? website,
    String? studentDomain,
  }) async {
    requestCalls++;
    return {'ok': true, 'code': 'request_received'};
  }

  @override
  Future<List<SchoolDirectoryEntry>> search(String query) async {
    queries.add(query);
    const schools = [
      SchoolDirectoryEntry(
        id: 'school-a',
        officialName: 'Indiana Math and Science Academy West',
        displayName: 'Indiana Math and Science Academy West',
        city: 'Indianapolis',
        state: 'IN',
        schoolType: 'k8',
      ),
      SchoolDirectoryEntry(
        id: 'school-b',
        officialName: 'Pike High School',
        displayName: 'Pike High School',
        city: 'Indianapolis',
        state: 'IN',
        schoolType: 'high_school',
      ),
    ];
    if (query.trim().isEmpty) return schools;
    return schools
        .where(
          (school) =>
              school.displayName.toLowerCase().contains(query.toLowerCase()) ||
              (query.toLowerCase() == 'imsa west' && school.id == 'school-a'),
        )
        .toList();
  }
}

void main() {
  testWidgets('school search stays live and selection needs Continue', (
    tester,
  ) async {
    final repository = _FakeSchoolDirectoryRepository();
    SchoolDirectoryEntry? chosen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolDirectoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    chosen = await Navigator.of(context)
                        .push<SchoolDirectoryEntry>(
                          MaterialPageRoute(
                            builder: (_) => const SchoolDirectoryPicker(),
                          ),
                        );
                  },
                  child: const Text('Choose school'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose school'));
    await tester.pumpAndSettle();

    expect(find.text('Find your school'), findsOneWidget);
    expect(find.text('Pike High School'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, 'imsa west');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.queries, contains('imsa west'));
    expect(find.text('Indiana Math and Science Academy West'), findsOneWidget);
    expect(find.text('Pike High School'), findsNothing);

    await tester.tap(find.text('Indiana Math and Science Academy West'));
    await tester.pump();
    expect(chosen, isNull);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(chosen?.id, 'school-a');
  });

  testWidgets('unknown school request stays pending and creates no selection', (
    tester,
  ) async {
    final repository = _FakeSchoolDirectoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolDirectoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const SchoolDirectoryPicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Synthetic Unknown Academy',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Can't find your school? Request your school"));
    await tester.pumpAndSettle();
    expect(find.text('Request your school'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Indianapolis',
    );
    await tester.ensureVisible(find.text('Submit school request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit school request'));
    await tester.pumpAndSettle();
    expect(repository.requestCalls, 1);
    expect(find.textContaining('Request received.'), findsOneWidget);
    expect(find.textContaining('Teen signup stays unavailable'), findsNothing);
    await tester.tap(find.text('Back to schools'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });
}
