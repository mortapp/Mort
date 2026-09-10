import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/jobs/application_screens.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

class _FakeApplicationsRepository extends ApplicationsRepository {
  _FakeApplicationsRepository({this.status = 'submitted'});

  final String status;
  final List<Map<String, Object?>> recordedCalls = [];
  final List<String> statusEventCalls = [];
  final List<String> statusUpdates = [];

  @override
  Future<MortApplication?> getApplication(
    String applicationId, {
    UserRole? role,
  }) async {
    recordedCalls.add({'applicationId': applicationId, 'role': role});
    return _application(applicationId);
  }

  MortApplication _application(String applicationId) => MortApplication(
    id: applicationId,
    jobId: 'job-1',
    teenId: 'teen-1',
    status: status,
    note: 'Test note',
    guardianId: 'guardian-1',
    job: Job(
      id: 'job-1',
      posterId: 'adult-1',
      title: 'Test job',
      description: 'A safe test job',
      category: 'safety',
      locationText: 'Nearby',
      city: 'Indy',
      state: 'IN',
      status: 'open',
      requiresGuardianApproval: false,
      proofExpected: false,
    ),
    availabilityConfirmed: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
    viewedAt: null,
    withdrawnAt: null,
    teenName: 'Sample Teen',
    teenAvatarPath: null,
  );

  @override
  Future<MortApplication> updateStatus(
    String applicationId,
    String action, {
    String? clientRequestId,
    DateTime? expectedUpdatedAt,
  }) async {
    statusUpdates.add(action);
    return _application(applicationId);
  }

  @override
  Future<List<Map<String, dynamic>>> listStatusEvents(
    String applicationId,
  ) async {
    statusEventCalls.add(applicationId);
    return const [];
  }
}

Widget _routedApp({
  required ApplicationView view,
  required ApplicationsRepository repository,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [applicationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _app({
  required ApplicationView view,
  required ApplicationsRepository repository,
}) {
  return ProviderScope(
    overrides: [applicationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: ApplicationDetailScreen(view: view, applicationId: 'app-1'),
    ),
  );
}

void main() {
  testWidgets('loads teen application details with teen role', (tester) async {
    final repository = _FakeApplicationsRepository();
    await tester.pumpWidget(
      _app(view: ApplicationView.teen, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedCalls, hasLength(1));
    expect(repository.recordedCalls.single['applicationId'], 'app-1');
    expect(repository.recordedCalls.single['role'], UserRole.teen);
    expect(find.text('Application details'), findsOneWidget);
    expect(find.text('Test job'), findsOneWidget);
  });

  testWidgets('loads adult application details with adult role', (
    tester,
  ) async {
    final repository = _FakeApplicationsRepository();
    await tester.pumpWidget(
      _app(view: ApplicationView.adult, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedCalls, hasLength(1));
    expect(repository.recordedCalls.single['applicationId'], 'app-1');
    expect(repository.recordedCalls.single['role'], UserRole.adult);
    expect(find.text('Applicant details'), findsOneWidget);
    expect(find.text('Test job'), findsOneWidget);
  });

  testWidgets('loads guardian approval details with guardian role', (
    tester,
  ) async {
    final repository = _FakeApplicationsRepository();
    await tester.pumpWidget(
      _app(view: ApplicationView.guardian, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(repository.recordedCalls, hasLength(1));
    expect(repository.recordedCalls.single['applicationId'], 'app-1');
    expect(repository.recordedCalls.single['role'], UserRole.guardian);
    expect(find.text('Approval request'), findsOneWidget);
    expect(find.text('Test job'), findsOneWidget);
  });

  testMortWidgets('loads the status timeline only when it is first expanded', (
    tester,
  ) async {
    final repository = _FakeApplicationsRepository();
    await tester.pumpWidget(
      _app(view: ApplicationView.teen, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(repository.statusEventCalls, isEmpty);

    await tester.tap(find.text('Status timeline'));
    await tester.pumpAndSettle();

    expect(repository.statusEventCalls, ['app-1']);
    expect(find.text('No status events have been recorded.'), findsOneWidget);

    await tester.tap(find.text('Status timeline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status timeline'));
    await tester.pumpAndSettle();

    expect(repository.statusEventCalls, ['app-1']);
  });

  for (final view in [ApplicationView.teen, ApplicationView.adult]) {
    testMortWidgets(
      '${view.name} execution state routes through canonical job progress',
      (tester) async {
        final repository = _FakeApplicationsRepository(
          status: view == ApplicationView.teen ? 'accepted' : 'in_progress',
        );
        final router = GoRouter(
          initialLocation: '/application',
          routes: [
            GoRoute(
              path: '/application',
              builder: (_, _) =>
                  ApplicationDetailScreen(view: view, applicationId: 'app-1'),
            ),
            GoRoute(
              path: '/jobs/progress/:applicationId',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Progress destination ${state.pathParameters['applicationId']}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _routedApp(view: view, repository: repository, router: router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open job progress'), findsOneWidget);
        expect(find.text('Start job'), findsNothing);
        expect(find.text('Mark complete'), findsNothing);

        await tester.tap(find.text('Open job progress'));
        await tester.pumpAndSettle();

        expect(find.text('Progress destination app-1'), findsOneWidget);
        expect(repository.statusUpdates, isEmpty);
      },
    );
  }
}
