import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_mort/features/jobs/job_screens.dart';
import 'package:flutter_mort/features/jobs/teen_job_screens.dart';
import 'package:flutter_mort/features/mort_screens.dart';

class _FakeJobsRepository extends JobsRepository {
  _FakeJobsRepository({List<Job>? savedJobs, JobPage? openJobsPage})
    : savedJobs = List<Job>.from(savedJobs ?? const []),
      openJobsPage = openJobsPage ?? const JobPage(items: [], hasMore: false);

  final JobPage openJobsPage;
  final List<Job> savedJobs;
  String? unsavedJobId;
  String? savedJobId;

  @override
  Future<List<Job>> listSavedJobs() async => savedJobs;

  @override
  Future<JobPage> listOpenJobsPage({
    JobSearchFilters filters = const JobSearchFilters(),
    JobPageCursor? cursor,
  }) async {
    return openJobsPage;
  }

  @override
  Future<void> unsaveJob(String jobId) async {
    unsavedJobId = jobId;
    savedJobs.removeWhere((job) => job.id == jobId);
  }

  @override
  Future<void> saveJob(String jobId) async {
    savedJobId = jobId;
  }
}

class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository({
    Map<String, dynamic>? config,
    List<Map<String, dynamic>>? checkins,
  }) : config = config ?? const {},
       checkins = checkins ?? const [];

  final Map<String, dynamic> config;
  final List<Map<String, dynamic>> checkins;
  String? completedCheckinId;

  @override
  Future<Map<String, dynamic>> getSafetyCenterConfig() async => config;

  @override
  Future<List<Map<String, dynamic>>> listActiveJobCheckins() async => checkins;

  @override
  Future<Map<String, dynamic>> completeActiveJobCheckin({
    required String checkinId,
    String? clientRequestId,
  }) async {
    completedCheckinId = checkinId;
    return {'ok': true, 'checkin_id': checkinId};
  }
}

Widget _app({required Widget child, List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(home: child),
  );
}

Job _job({required String id, String title = 'Test Job'}) {
  return Job(
    id: id,
    posterId: 'poster-1',
    title: title,
    description: 'A job for testing.',
    category: 'cleaning',
    locationText: 'Nearby area',
    city: 'TestCity',
    state: 'TS',
    status: 'open',
    requiresGuardianApproval: false,
    payAmountCents: 1200,
  );
}

void main() {
  testWidgets(
    'TeenJobFeedScreen shows clear filters when empty results and filters are active',
    (tester) async {
      final repository = _FakeJobsRepository(
        openJobsPage: const JobPage(items: [], hasMore: false),
      );
      final profile = Profile(
        id: 'profile-1',
        role: UserRole.teen,
        displayName: 'Test Teen',
        username: 'testteen',
        dob: DateTime(2010, 1, 1),
        city: 'TestCity',
        state: 'TS',
        onboardingCompleted: true,
        accountStatus: 'active',
        verificationStatus: 'approved',
        paymentPreference: 'none',
      );

      await tester.pumpWidget(
        _app(
          child: const TeenJobFeedScreen(),
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(AsyncValue.data(profile)),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No jobs in this area yet'), findsOneWidget);
      expect(find.text('Refresh'), findsWidgets);

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Try tutoring, yard work, or technology help',
      );
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'tutoring');
      await tester.ensureVisible(find.text('Filters and sorting'));
      await tester.tap(find.text('Filters and sorting'));
      await tester.pumpAndSettle();

      final applyFiltersButton = find.text('Apply filters');
      expect(applyFiltersButton, findsOneWidget);
      await tester.ensureVisible(applyFiltersButton);
      await tester.pumpAndSettle();
      await tester.tap(applyFiltersButton);
      await tester.pumpAndSettle();

      expect(find.text('Clear filters'), findsOneWidget);
    },
  );

  testWidgets('TeenJobFeedScreen saves a real feed job', (tester) async {
    final job = _job(id: 'job-1', title: 'Yard cleanup');
    final repository = _FakeJobsRepository(
      openJobsPage: JobPage(items: [job], hasMore: false),
    );
    final profile = Profile(
      id: 'profile-1',
      role: UserRole.teen,
      displayName: 'Test Teen',
      username: 'testteen',
      dob: DateTime(2010, 1, 1),
      city: 'TestCity',
      state: 'TS',
      onboardingCompleted: true,
      accountStatus: 'active',
      verificationStatus: 'approved',
      paymentPreference: 'none',
    );

    await tester.pumpWidget(
      _app(
        child: const TeenJobFeedScreen(),
        overrides: [
          jobsRepositoryProvider.overrideWithValue(repository),
          currentProfileProvider.overrideWithValue(AsyncValue.data(profile)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yard cleanup'), findsOneWidget);
    await tester.tap(find.byTooltip('Save job'));
    await tester.pumpAndSettle();

    expect(repository.savedJobId, 'job-1');
    expect(find.byTooltip('Unsave job'), findsOneWidget);
  });

  testWidgets(
    'SavedJobsScreen shows empty state when there are no saved jobs',
    (tester) async {
      final repository = _FakeJobsRepository(savedJobs: []);

      await tester.pumpWidget(
        _app(
          child: const SavedJobsScreen(),
          overrides: [jobsRepositoryProvider.overrideWithValue(repository)],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No saved jobs'), findsOneWidget);
      expect(find.text('Browse teen jobs'), findsOneWidget);
    },
  );

  testWidgets('SavedJobsScreen allows removing a saved job', (tester) async {
    final repository = _FakeJobsRepository(
      savedJobs: [_job(id: 'job-1', title: 'Saved Test Job')],
    );

    await tester.pumpWidget(
      _app(
        child: const SavedJobsScreen(),
        overrides: [jobsRepositoryProvider.overrideWithValue(repository)],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Saved Test Job'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(repository.unsavedJobId, 'job-1');
    expect(find.text('No saved jobs'), findsOneWidget);
  });

  testWidgets(
    'SafetyCenterScreen renders emergency actions and a safety banner',
    (tester) async {
      final repository = _FakeSafetyRepository(
        config: {
          'emergency_phone_uri': 'tel:911',
          'emergency_guidance': 'Test safety guidance message',
        },
        checkins: [],
      );

      await tester.pumpWidget(
        _app(
          child: const SafetyCenterScreen(),
          overrides: [
            safetyRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(
              const AsyncValue.data(null),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Call 911'), findsOneWidget);
      expect(find.text('Urgent support and human review'), findsOneWidget);
      expect(find.text('Test safety guidance message'), findsOneWidget);

      final emergencyButton = find.text('Call 911');
      await tester.ensureVisible(emergencyButton);
      await tester.pumpAndSettle();
      await tester.tap(emergencyButton);
      await tester.pumpAndSettle();
      expect(find.text('Open the emergency dialer?'), findsOneWidget);
      expect(find.text('Open dialer'), findsOneWidget);
    },
  );

  testWidgets('Safety Pulse completes the active persisted check-in', (
    tester,
  ) async {
    final repository = _FakeSafetyRepository(
      checkins: [
        {
          'checkin_id': 'checkin-1',
          'application_id': 'application-1',
          'job_id': 'job-1',
          'job_title': 'Yard cleanup',
          'status': 'pending',
          'expected_at': '2026-08-08T12:00:00Z',
        },
      ],
    );

    await tester.pumpWidget(
      _app(
        child: const SafetyCenterScreen(),
        overrides: [
          safetyRepositoryProvider.overrideWithValue(repository),
          currentProfileProvider.overrideWithValue(const AsyncValue.data(null)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('I am okay'), findsWidgets);
    final checkInControl = find.text('I am okay').first;
    await tester.ensureVisible(checkInControl);
    await tester.pumpAndSettle();
    await tester.tap(checkInControl);
    await tester.pumpAndSettle();

    expect(repository.completedCheckinId, 'checkin-1');
  });
}
