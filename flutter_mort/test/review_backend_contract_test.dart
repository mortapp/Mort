import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'reviews use completed assignments and application-scoped eligibility',
    () {
      final repository = _read('lib/data/repositories/reviews_repository.dart');
      final screen = _read('lib/features/profile/review_screens.dart');
      final migrationFiles = Directory('../supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('completed_job_star_reviews'))
          .toList();
      expect(migrationFiles, hasLength(1));
      if (migrationFiles.length != 1) return;
      final migration = migrationFiles.single.readAsStringSync();

      expect(repository, contains('reviewForApplicationByCurrentUser'));
      expect(repository, contains("'application_id': applicationId"));
      expect(repository, isNot(contains("'body':")));
      expect(screen, contains('jobExecutionRepositoryProvider'));
      expect(screen, contains("state == 'completed'"));
      expect(screen, isNot(contains('MortTextArea(')));

      expect(migration, contains('create table public.reviews'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('reviews_insert_completed_assignment'));
      expect(migration, contains("ja.status = 'completed'"));
      expect(migration, contains('completed_by_teen_at is not null'));
      expect(migration, contains('completed_by_adult_at is not null'));
      expect(migration, contains('review_body_not_enabled'));
      expect(migration, contains('blind_review_reveal'));
    },
  );
}
