import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/data/models/application.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/jobs/quick_accept_button.dart';

class _FakeApplicationsRepository extends ApplicationsRepository {
  _FakeApplicationsRepository({this.onQuickAccept});

  final Future<MortApplication> Function()? onQuickAccept;
  int quickAcceptCalls = 0;

  @override
  Future<MortApplication> quickAccept(String jobId) async {
    quickAcceptCalls += 1;
    if (onQuickAccept != null) return onQuickAccept!();
    // A real network round-trip always has a gap; simulate one so the
    // CLAIMING state is genuinely observable mid-flight in tests, exactly
    // as it would be against a real backend.
    await Future.delayed(const Duration(milliseconds: 20));
    return _application(jobId);
  }
}

MortApplication _application(String jobId) => MortApplication(
  id: 'application-1',
  jobId: jobId,
  teenId: 'teen-1',
  status: 'accepted',
  note: null,
  guardianId: null,
  job: null,
  availabilityConfirmed: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  viewedAt: null,
  withdrawnAt: null,
  teenName: null,
  teenAvatarPath: null,
);

Job _job({bool quickAcceptEligible = true, DateTime? expiresAt}) => Job(
  id: 'job-1',
  posterId: 'adult-1',
  title: 'Quick accept test job',
  description: 'A safe test job',
  category: 'safety',
  locationText: 'Nearby',
  city: 'Indy',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
  quickAcceptEligible: quickAcceptEligible,
  expiresAt: expiresAt,
);

Widget _app(
  Job job,
  ApplicationsRepository repository, {
  ValueChanged<MortApplication>? onAccepted,
}) {
  return ProviderScope(
    overrides: [applicationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: QuickAcceptButton(job: job, onAccepted: onAccepted),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing for a job that is not quick-accept eligible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_job(quickAcceptEligible: false), _FakeApplicationsRepository()),
    );
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets(
    'AVAILABLE -> CLAIMING -> ACCEPTED never shows success before the server confirms',
    (tester) async {
      MortApplication? accepted;
      final repository = _FakeApplicationsRepository();
      await tester.pumpWidget(
        _app(
          _job(),
          repository,
          onAccepted: (application) => accepted = application,
        ),
      );

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Accepted'), findsNothing);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      // Mid-flight: claiming, not yet accepted.
      expect(find.text('Claiming...'), findsOneWidget);
      expect(find.text('Accepted'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Accepted'), findsOneWidget);
      expect(repository.quickAcceptCalls, 1);
      expect(accepted?.jobId, 'job-1');
    },
  );

  testWidgets('OFFER_TAKEN shows a clean state, not a raw error', (
    tester,
  ) async {
    final repository = _FakeApplicationsRepository(
      onQuickAccept: () async => throw const MortCodedError(
        'offer_taken',
        'Another teen already accepted this job.',
      ),
    );
    await tester.pumpWidget(_app(_job(), repository));
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Offer taken'), findsOneWidget);
    expect(find.textContaining('offer_taken'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets(
    'NOT_ELIGIBLE (e.g. age mismatch) shows a disabled state with the reason',
    (tester) async {
      final repository = _FakeApplicationsRepository(
        onQuickAccept: () async => throw const MortCodedError(
          'applicant_age_not_allowed',
          'Your age does not match this job requirement.',
        ),
      );
      await tester.pumpWidget(_app(_job(), repository));
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('Not eligible'), findsOneWidget);
      final button = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(button.message, contains('age'));
    },
  );

  testWidgets('NETWORK_ERROR offers Retry, and retry can still succeed', (
    tester,
  ) async {
    var attempt = 0;
    final repository = _FakeApplicationsRepository(
      onQuickAccept: () async {
        attempt += 1;
        if (attempt == 1) throw Exception('socket closed');
        return _application('job-1');
      },
    );
    await tester.pumpWidget(_app(_job(), repository));
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Retry accept'), findsOneWidget);

    await tester.tap(find.text('Retry accept'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);
    expect(repository.quickAcceptCalls, 2);
  });

  testWidgets(
    'EXPIRED shows a real, server-derived expiration, not a fake countdown',
    (tester) async {
      final repository = _FakeApplicationsRepository();
      await tester.pumpWidget(
        _app(
          _job(expiresAt: DateTime.now().subtract(const Duration(minutes: 5))),
          repository,
        ),
      );
      await tester.pump();

      expect(find.text('Offer expired'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(repository.quickAcceptCalls, 0);
    },
  );
}
