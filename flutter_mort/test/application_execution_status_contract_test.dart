import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('completion actions and recent work use job assignment state', () {
    final applications = _read('lib/features/jobs/application_screens.dart');
    final teenProfile = _read('lib/features/teen/teen_profile_screen.dart');
    final executionRepository = _read(
      'lib/data/repositories/job_execution_repository.dart',
    );
    final providers = _read('lib/data/repositories/providers.dart');

    expect(applications, contains("getStatus(application.id)"));
    expect(applications, isNot(contains("application.status == 'completed'")));
    expect(applications, isNot(contains("label: 'Mark complete'")));
    expect(applications, contains(r"'/jobs/progress/${application.id}'"));

    expect(executionRepository, contains(".from('job_assignments')"));
    expect(executionRepository, contains(".eq('status', 'completed')"));
    expect(executionRepository, contains(".eq('teen_user_id', userId)"));
    expect(providers, contains('myCompletedJobsProvider'));
    expect(teenProfile, contains('myCompletedJobsProvider'));
    expect(teenProfile, isNot(contains("application.status == 'completed'")));
  });
}
