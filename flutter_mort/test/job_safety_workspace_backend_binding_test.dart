import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/safety/trust_safety_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SafetyWorkspaceRepository extends TrustSafetyRepository {
  int cancellationCalls = 0;
  String? cancellationDetails;

  @override
  Future<JobSafetyAgreement?> getSafetyAgreement(String applicationId) async =>
      const JobSafetyAgreement(
        id: 'agreement-1',
        applicationId: 'application-1',
        jobId: 'job-1',
        teenId: 'teen-1',
        adultId: 'adult-1',
        version: 3,
        status: 'awaiting_both',
        terms: {'job_title': 'Garden help'},
      );

  @override
  Future<JobSafetyPlan?> getSafetyPlan(String applicationId) async =>
      const JobSafetyPlan(
        expectedPeople: 'Guardian will be present',
        publicOrVisibleMeeting: false,
        daylightPreferred: false,
        transportationPlan: 'Guardian pickup',
        checkinCadenceMinutes: 45,
      );

  @override
  Future<List<AuthorizedLocationShare>> listLocationShares() async => const [];

  @override
  Future<void> submitSafetyCancellation({
    required String applicationId,
    required String reason,
    String? details,
  }) async {
    cancellationCalls++;
    cancellationDetails = details;
  }
}

void main() {
  testWidgets('safety workspace restores the persisted backend plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustSafetyRepositoryProvider.overrideWithValue(
            _SafetyWorkspaceRepository(),
          ),
          currentProfileProvider.overrideWithValue(const AsyncValue.data(null)),
        ],
        child: const MaterialApp(
          home: JobSafetyWorkspaceScreen(applicationId: 'application-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardian will be present'), findsOneWidget);
    expect(find.text('Guardian pickup'), findsOneWidget);
    expect(find.text('Every 45 minutes'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'safety cancellation rejects details shorter than 10 characters',
    (tester) async {
      final repository = _SafetyWorkspaceRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustSafetyRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(
              const AsyncValue.data(null),
            ),
          ],
          child: const MaterialApp(
            home: JobSafetyWorkspaceScreen(applicationId: 'application-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final detailsField = find.widgetWithText(TextFormField, 'What changed?');
      await tester.enterText(detailsField, '  too short  ');
      await tester.ensureVisible(find.text('Cancel for this reason'));
      await tester.tap(find.text('Cancel for this reason'));
      await tester.pump();

      expect(
        find.text(
          'Enter between 10 and 3,000 characters describing what changed.',
        ),
        findsOneWidget,
      );
      expect(repository.cancellationCalls, 0);
    },
  );

  testWidgets('safety cancellation accepts exactly 10 trimmed characters', (
    tester,
  ) async {
    final repository = _SafetyWorkspaceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustSafetyRepositoryProvider.overrideWithValue(repository),
          currentProfileProvider.overrideWithValue(const AsyncValue.data(null)),
        ],
        child: const MaterialApp(
          home: JobSafetyWorkspaceScreen(applicationId: 'application-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailsField = find.widgetWithText(TextFormField, 'What changed?');
    await tester.enterText(detailsField, '  ten chars!  ');
    await tester.ensureVisible(find.text('Cancel for this reason'));
    await tester.tap(find.text('Cancel for this reason'));
    await tester.pumpAndSettle();

    expect(repository.cancellationCalls, 1);
    expect(repository.cancellationDetails, 'ten chars!');
    expect(
      find.text('Cancellation recorded with no automatic reputation penalty.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'safety cancellation rejects details longer than 3,000 characters',
    (tester) async {
      final repository = _SafetyWorkspaceRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trustSafetyRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(
              const AsyncValue.data(null),
            ),
          ],
          child: const MaterialApp(
            home: JobSafetyWorkspaceScreen(applicationId: 'application-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final detailsField = find.widgetWithText(TextFormField, 'What changed?');
      await tester.enterText(detailsField, 'x' * 3001);
      await tester.ensureVisible(find.text('Cancel for this reason'));
      await tester.tap(find.text('Cancel for this reason'));
      await tester.pump();

      expect(
        find.text(
          'Enter between 10 and 3,000 characters describing what changed.',
        ),
        findsOneWidget,
      );
      expect(repository.cancellationCalls, 0);
    },
  );
}
