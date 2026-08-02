import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _jobOne = Job(
  id: 'job-1',
  posterId: 'adult-1',
  title: 'First job',
  description: 'Safe first job description.',
  category: 'organization',
  locationText: 'General area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
);

const _jobTwo = Job(
  id: 'job-2',
  posterId: 'adult-1',
  title: 'Second job',
  description: 'Safe second job description.',
  category: 'organization',
  locationText: 'General area',
  city: 'Indianapolis',
  state: 'IN',
  status: 'open',
  requiresGuardianApproval: false,
);

class _PagingJobsRepository extends JobsRepository {
  int calls = 0;

  @override
  Future<JobPage> listOpenJobsPage({
    JobSearchFilters filters = const JobSearchFilters(),
    JobPageCursor? cursor,
  }) async {
    calls += 1;
    if (cursor == null) {
      return const JobPage(
        items: [_jobOne],
        hasMore: true,
        nextCursor: JobPageCursor(value: 'first', id: 'job-1'),
      );
    }
    return const JobPage(items: [_jobOne, _jobTwo], hasMore: false);
  }
}

void main() {
  test('job page parses server cursor and honest matching metadata', () {
    final page = JobPage.fromMap({
      'ok': true,
      'items': [
        {
          'id': 'job-1',
          'poster_id': 'adult-1',
          'title': 'Library organizing',
          'description': 'Organize books in a staffed public library.',
          'category': 'organization',
          'location_text': 'Downtown library area',
          'city': 'Indianapolis',
          'state': 'IN',
          'status': 'open',
          'requires_guardian_approval': false,
          'acceptable_transportation_methods': ['walking'],
          'distance_status': 'unavailable',
          'transportation_match': true,
          'match_explanation':
              'A saved travel method matches. Distance is not calculated.',
          'updated_at': '2026-07-30T02:30:00.000Z',
        },
      ],
      'has_more': true,
      'next_cursor': {'value': '2026-07-30T02:30:00.000Z', 'id': 'job-1'},
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.distanceStatus, 'unavailable');
    expect(page.items.single.transportationMatch, isTrue);
    expect(page.items.single.matchExplanation, contains('not calculated'));
    expect(page.items.single.updatedAt, isNotNull);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor?.id, 'job-1');
  });

  test('feed state appends without losing cache and paging signals', () {
    const cursor = JobPageCursor(value: 'cursor-value', id: 'job-1');
    final state = JobFeedState(
      items: const [_jobOne],
      hasMore: true,
      nextCursor: cursor,
    );
    final loading = state.copyWith(loadingMore: true);

    expect(loading.items.single.id, 'job-1');
    expect(loading.nextCursor?.id, 'job-1');
    expect(loading.loadingMore, isTrue);
    expect(loading.hasMore, isTrue);
  });

  test('job sort values match the server contract', () {
    expect(JobSort.newest.apiValue, 'newest');
    expect(JobSort.highestPay.apiValue, 'highest_pay');
    expect(JobSort.soonestStart.apiValue, 'soonest_start');
  });

  test(
    'Riverpod controller accumulates keyset pages without duplicates',
    () async {
      final repository = _PagingJobsRepository();
      final container = ProviderContainer(
        overrides: [jobsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      const filters = JobSearchFilters();

      final first = await container.read(openJobsProvider(filters).future);
      expect(first.items.map((job) => job.id), ['job-1']);
      expect(first.hasMore, isTrue);

      await container.read(openJobsProvider(filters).notifier).loadNext();
      final second = container.read(openJobsProvider(filters)).requireValue;
      expect(second.items.map((job) => job.id), ['job-1', 'job-2']);
      expect(second.hasMore, isFalse);
      expect(repository.calls, 2);
    },
  );
}
