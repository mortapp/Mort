import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/jobs/teen_job_screens.dart';

void main() {
  testWidgets('teen Explore follows the current MORT design brief', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openJobsProvider.overrideWith2(_PreviewJobsController.new),
          jobsRepositoryProvider.overrideWithValue(_PreviewJobsRepository()),
          savedJobIdsProvider.overrideWith((ref) async => <String>{}),
          interestedJobIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: MaterialApp(
          theme: MortTheme.light(),
          home: const RepaintBoundary(
            key: ValueKey('teen-explore-preview'),
            child: TeenJobFeedScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find work that fits your day'), findsOneWidget);
    expect(find.text('SUGGESTED SEARCHES'), findsOneWidget);
    expect(find.text('Under 30 min'), findsOneWidget);
    expect(find.text('Yard cleanup'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('teen-explore-preview')),
      matchesGoldenFile('goldens/teen_explore_redesign.png'),
    );
  });
}

class _PreviewJobsController extends OpenJobsController {
  _PreviewJobsController(super.filters);

  @override
  Future<JobFeedState> build() async =>
      const JobFeedState(items: [_quickJob, _nearbyJob], hasMore: false);
}

class _PreviewJobsRepository extends JobsRepository {
  @override
  Future<List<Job>> listSavedJobs() async => const [];
}

const _quickJob = Job(
  id: 'quick-preview-job',
  posterId: 'poster-1',
  title: 'Yard cleanup',
  description: 'Collect leaves and tidy the front garden.',
  category: 'lawn care',
  locationText: '123 Exact Street',
  city: 'Indianapolis',
  state: 'IN',
  neighborhood: 'Broad Ripple area',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Janet',
  posterVerificationStatus: 'approved',
  estimatedDurationMinutes: 20,
  payAmountCents: 2500,
);

const _nearbyJob = Job(
  id: 'nearby-preview-job',
  posterId: 'poster-2',
  title: 'Help organize a garage',
  description: 'Sort boxes and sweep the floor.',
  category: 'organization',
  locationText: '456 Meridian Road',
  city: 'Indianapolis',
  state: 'IN',
  neighborhood: 'Meridian-Kessler area',
  status: 'open',
  requiresGuardianApproval: false,
  posterName: 'Morgan',
  estimatedDurationMinutes: 45,
  payAmountCents: 3200,
);
