import 'dart:io';

import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/features/jobs/job_creation_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('job creation progress has one truthful eight-step source', () {
    expect(jobCreationSteps, hasLength(8));
    expect(jobCreationSteps.map((step) => step.title), [
      'Job basics',
      'Work details',
      'Schedule',
      'Location and travel',
      'Payment',
      'Safety and requirements',
      'Preview',
      'Publish',
    ]);
    expect(jobCreationStepAt(-2), JobCreationStep.basics);
    expect(jobCreationStepAt(99), JobCreationStep.publish);
  });

  test(
    'job draft survives local serialization without changing request ID',
    () {
      final original =
          JobDraft(clientRequestId: '00000000-0000-0000-0000-000000000010')
            ..title = 'Safe yard cleanup'
            ..summary = 'Gather leaves in a visible shared yard.'
            ..estimatedDurationMinutes = 90
            ..acceptableTransportationMethods = ['walking', 'bicycle']
            ..proofExpected = true
            ..specialInstructions = 'Photograph only the bagged leaves.';

      final local = original.toLocalMap(activeStep: 5);
      final recovered = JobDraft.fromLocalMap(local);

      expect(local['active_step'], 5);
      expect(recovered.clientRequestId, original.clientRequestId);
      expect(recovered.title, original.title);
      expect(recovered.estimatedDurationMinutes, 90);
      expect(recovered.acceptableTransportationMethods, ['walking', 'bicycle']);
      expect(recovered.proofExpected, isTrue);
    },
  );

  test('profile setup uses the atomic RPC and encrypted recovery', () {
    final repository = File(
      'lib/data/repositories/profile_repository.dart',
    ).readAsStringSync();
    final screen = File('lib/features/mort_screens.dart').readAsStringSync();
    final start = screen.indexOf('class _ProfileSetupScreenState');
    final end = screen.indexOf('class SkillsScreen', start);
    final profileScreen = screen.substring(start, end);

    expect(repository, contains("'save_my_profile_setup_v2'"));
    expect(profileScreen, contains('.saveProfileSetup('));
    expect(profileScreen, contains('writeProfileDraft'));
    expect(profileScreen, contains('clearProfileDraft'));
    expect(profileScreen, isNot(contains('.requestUsernameChange(')));
    expect(profileScreen, isNot(contains('.updateMyProfile(')));
  });

  test('job composer reports real server publication state', () {
    final source = File(
      'lib/features/jobs/job_screens.dart',
    ).readAsStringSync();

    expect(source, contains('MortSearchableDropdown<String>'));
    expect(source, contains('writeJobDraft'));
    expect(source, contains('publishWithState'));
    expect(source, contains('Job opened for applications.'));
    expect(
      source,
      contains('Saved for closed-pilot review. Applications remain closed.'),
    );
    expect(source, isNot(contains("publish ? 'Job published.'")));
  });

  test('hardening migration keeps RPCs caller-bound and fail-closed', () {
    final migration = File(
      '../supabase/migrations/20260802062226_video_profile_job_hardening.sql',
    ).readAsStringSync();

    expect(migration, contains('auth.uid()'));
    expect(migration, contains('save_my_profile_setup_v2'));
    expect(migration, contains('profile_setup_requests'));
    expect(migration, contains("if v_role <> 'teen' then"));
    expect(migration, contains("if v_role = 'guardian' then"));
    expect(migration, contains("when v_job.status = 'pending_review'"));
    expect(migration, contains("then 'pending_review'"));
    expect(migration, contains('from public, anon'));
    expect(migration, isNot(contains('p_user_id')));
  });

  test(
    'avatar editor previews processed bytes and maps permission failures',
    () {
      final repository = File(
        'lib/data/repositories/avatar_repository.dart',
      ).readAsStringSync();
      final editor = File(
        'lib/features/profile/profile_avatar_widgets.dart',
      ).readAsStringSync();

      expect(repository, contains('avatar_camera_permission_denied'));
      expect(repository, contains('avatar_photo_permission_denied'));
      expect(repository, contains('prepareAvatar'));
      expect(repository, contains('uploadPreparedAvatar'));
      expect(repository, contains('.timeout(const Duration(seconds: 45))'));
      expect(editor, contains('Use this square crop?'));
      expect(editor, contains('Image.memory'));
      expect(editor, contains('uploadPreparedAvatar'));
    },
  );
}
