import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/jobs/job_screens.dart';
import 'package:flutter_mort/features/jobs/teen_job_screens.dart';
import 'package:flutter_mort/features/mort_screens.dart';

import 'helpers/mort_widget_harness.dart';

class _FakeJobsRepository extends JobsRepository {
  _FakeJobsRepository({
    List<Job>? savedJobs,
    JobPage? openJobsPage,
    this.jobDetail,
  }) : savedJobs = List<Job>.from(savedJobs ?? const []),
       openJobsPage = openJobsPage ?? const JobPage(items: [], hasMore: false);

  final JobPage openJobsPage;
  final List<Job> savedJobs;
  final Job? jobDetail;
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

  @override
  Future<Job?> getJob(String id) async => jobDetail;

  @override
  Future<bool> isSaved(String jobId) async =>
      savedJobs.any((job) => job.id == jobId);
}

class _FakeApplicationsRepository extends ApplicationsRepository {
  _FakeApplicationsRepository(this.eligibility);

  final ApplicationEligibility eligibility;

  @override
  Future<ApplicationEligibility> checkEligibility(String jobId) async =>
      eligibility;
}

class _FakeSafetyRepository extends SafetyRepository {
  _FakeSafetyRepository({
    Map<String, dynamic>? config,
    List<Map<String, dynamic>>? checkins,
    this.configFailuresRemaining = 0,
  }) : config = config ?? const {},
       checkins = checkins ?? const [];

  final Map<String, dynamic> config;
  final List<Map<String, dynamic>> checkins;
  int configFailuresRemaining;
  int configLoadCount = 0;
  String? completedCheckinId;

  @override
  Future<Map<String, dynamic>> getSafetyCenterConfig() async {
    configLoadCount += 1;
    if (configFailuresRemaining > 0) {
      configFailuresRemaining -= 1;
      throw StateError('safety_status_unavailable');
    }
    return config;
  }

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
    child: MaterialApp(theme: mortTestTheme(ThemeData()), home: child),
  );
}

Profile _teenProfile() => Profile(
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
  testMortWidgets(
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

  testMortWidgets('TeenJobFeedScreen saves a real feed job', (tester) async {
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

  testMortWidgets(
    'TeenJobFeedScreen keeps a detailed job card accessible at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final job = Job(
        id: 'job-accessible',
        posterId: 'poster-1',
        title: 'Help organize a community library reading room',
        description: 'A job for testing.',
        category: 'Community and library help',
        locationText: 'Broad Ripple public library area',
        city: 'Indianapolis',
        state: 'IN',
        status: 'open',
        requiresGuardianApproval: true,
        payAmountCents: 12500,
        posterVerificationStatus: 'approved',
        estimatedDurationMinutes: 150,
        acceptableTransportationMethods: const ['walking', 'public_transit'],
      );
      final repository = _FakeJobsRepository(
        openJobsPage: JobPage(items: [job], hasMore: false),
      );

      await tester.pumpWidget(
        _app(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: const TeenJobFeedScreen(),
          ),
          overrides: [
            jobsRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_teenProfile()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.text('Help organize a community library reading room'),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<MortGlassCard>(
        find.ancestor(
          of: find.text('Help organize a community library reading room'),
          matching: find.byType(MortGlassCard),
        ),
      );
      expect(
        card.semanticLabel,
        'Help organize a community library reading room. Listed pay \$125.00. Approximate area Broad Ripple public library area. Flexible schedule. Verified poster.',
      );
      await tester.ensureVisible(find.byTooltip('Save job'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save job').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testMortWidgets(
    'TeenJobDetailScreen keeps trust payment safety and apply truth visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final job = Job(
        id: 'job-detail',
        posterId: 'poster-1',
        title: 'Community garden support',
        description: 'Help prepare shared garden beds for spring.',
        category: 'Yard work',
        locationText: 'Near the public library',
        city: 'Indianapolis',
        state: 'IN',
        status: 'open',
        requiresGuardianApproval: false,
        payAmountCents: 4800,
        posterName: 'Synthetic Poster',
        posterVerificationStatus: 'approved',
        safetyNotes: 'Work stays in the public garden area.',
      );
      final jobs = _FakeJobsRepository(jobDetail: job);
      final applications = _FakeApplicationsRepository(
        const ApplicationEligibility(
          eligible: true,
          code: 'eligible',
          message: 'You can apply for this job.',
          guardianRequiredForThisJob: false,
          guardianLinked: true,
        ),
      );

      await tester.pumpWidget(
        _app(
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              disableAnimations: true,
              textScaler: TextScaler.linear(2),
            ),
            child: TeenJobDetailScreen(jobId: 'job-detail'),
          ),
          overrides: [
            jobsRepositoryProvider.overrideWithValue(jobs),
            applicationsRepositoryProvider.overrideWithValue(applications),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final applyButton = find.text('Apply now');
      expect(applyButton.hitTestable(), findsOneWidget);

      for (final text in [
        'Community garden support',
        'Offered compensation',
        'MORT does not process, hold, guarantee, or mark this amount paid.',
        'Approximate area: Near the public library, Indianapolis, IN',
        'Safety expectations',
        'Work stays in the public garden area.',
        'Application eligibility',
      ]) {
        final content = find.text(text);
        expect(content, findsOneWidget, reason: text);
        await tester.ensureVisible(content);
        await tester.pumpAndSettle();
        expect(content.hitTestable(), findsOneWidget, reason: text);
        expect(tester.takeException(), isNull, reason: text);
      }

      final report = find.byTooltip('Report profile picture or poster');
      expect(report, findsOneWidget);
      await tester.ensureVisible(report);
      await tester.pumpAndSettle();
      expect(report.hitTestable(), findsOneWidget);
      expect(find.byType(MortPaymentDisclaimer), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  testMortWidgets('SavedJobsScreen allows removing a saved job', (
    tester,
  ) async {
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

  testMortWidgets(
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
              AsyncValue.data(_teenProfile()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Call 911'), findsOneWidget);
      expect(find.text('Urgent support'), findsOneWidget);
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
          currentProfileProvider.overrideWithValue(
            AsyncValue.data(_teenProfile()),
          ),
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

  testWidgets(
    'SafetyCenterScreen keeps emergency help available and recovers after load failure',
    (tester) async {
      final repository = _FakeSafetyRepository(
        config: {'emergency_guidance': 'Recovered safety guidance'},
        configFailuresRemaining: 1,
      );

      await tester.pumpWidget(
        _app(
          child: const SafetyCenterScreen(),
          overrides: [
            safetyRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_teenProfile()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Safety status unavailable'), findsOneWidget);
      expect(find.text('Retry safety status'), findsOneWidget);

      final emergencyButton = find.text('Call 911');
      await tester.ensureVisible(emergencyButton);
      await tester.tap(emergencyButton);
      await tester.pumpAndSettle();
      expect(find.text('Open the emergency dialer?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final retry = find.text('Retry safety status');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repository.configLoadCount, 2);
      expect(find.text('Safety status unavailable'), findsNothing);
      expect(find.text('Recovered safety guidance'), findsOneWidget);
    },
  );

  testWidgets('SafetyCenterScreen keeps Teen-only Safety Ping off adult UI', (
    tester,
  ) async {
    final repository = _FakeSafetyRepository();
    final adult = Profile(
      id: 'adult-1',
      role: UserRole.adult,
      displayName: 'Test Adult',
      username: 'testadult',
      dob: DateTime(1990, 1, 1),
      city: 'TestCity',
      state: 'TS',
      onboardingCompleted: true,
      accountStatus: 'active',
      verificationStatus: 'approved',
      paymentPreference: 'none',
    );

    await tester.pumpWidget(
      _app(
        child: const SafetyCenterScreen(),
        overrides: [
          safetyRepositoryProvider.overrideWithValue(repository),
          currentProfileProvider.overrideWithValue(AsyncValue.data(adult)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safety Ping is for Teen accounts'), findsOneWidget);
    expect(find.text('Optional Safety Ping note'), findsNothing);
    expect(find.text('Call 911'), findsOneWidget);
    expect(find.text('Report a concern'), findsOneWidget);
  });
}
