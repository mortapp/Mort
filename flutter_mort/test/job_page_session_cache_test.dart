import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/data/repositories/jobs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evicts the least recently used job page at its entry limit', () {
    var now = DateTime(2026, 1, 1, 12);
    final cache = JobPageSessionCache(maximumEntries: 2, now: () => now);
    const first = JobPage(items: [], hasMore: true);
    const second = JobPage(items: [], hasMore: false);
    const third = JobPage(
      items: [],
      hasMore: false,
      servedFromSessionCache: true,
    );

    cache.write('first', first);
    now = now.add(const Duration(seconds: 1));
    cache.write('second', second);
    expect(cache.read('first'), same(first));

    now = now.add(const Duration(seconds: 1));
    cache.write('third', third);

    expect(cache.length, 2);
    expect(cache.read('second'), isNull);
    expect(cache.read('first'), same(first));
    expect(cache.read('third'), same(third));
  });

  test('expires stale job pages before using the offline fallback', () {
    var now = DateTime(2026, 1, 1, 12);
    final cache = JobPageSessionCache(
      timeToLive: const Duration(minutes: 15),
      now: () => now,
    );
    const page = JobPage(items: [], hasMore: false);

    cache.write('nearby', page);
    now = now.add(const Duration(minutes: 14, seconds: 59));
    expect(cache.read('nearby'), same(page));

    now = now.add(const Duration(seconds: 1));
    expect(cache.read('nearby'), isNull);
    expect(cache.length, 0);
  });
}
