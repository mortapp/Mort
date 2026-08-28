import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeJobsRepository extends JobsRepository {
  int listCalls = 0;

  @override
  Future<List<Job>> listMyJobs() async {
    listCalls += 1;
    return const [];
  }
}

void main() {
  test(
    'account data providers cache reads until explicitly invalidated',
    () async {
      final repository = _FakeJobsRepository();
      final container = ProviderContainer(
        overrides: [jobsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(myJobsProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(myJobsProvider.future);
      await container.read(myJobsProvider.future);

      expect(repository.listCalls, 1);

      container.invalidate(myJobsProvider);
      await container.read(myJobsProvider.future);

      expect(repository.listCalls, 2);
    },
  );
}
