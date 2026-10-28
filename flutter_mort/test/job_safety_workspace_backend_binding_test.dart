import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/safety/trust_safety_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SafetyWorkspaceRepository extends TrustSafetyRepository {
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
}
