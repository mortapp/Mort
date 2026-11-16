import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/profile.dart';

void main() {
  test('profile model preserves server timestamps and persisted fields', () {
    final profile = Profile.fromMap({
      'id': '00000000-0000-0000-0000-000000000001',
      'role': 'teen',
      'display_name': 'Persistent User',
      'username': 'persistent_user',
      'dob': '2010-02-28',
      'city': 'Indianapolis',
      'state': 'IN',
      'onboarding_completed': true,
      'account_status': 'active',
      'verification_status': 'not_started',
      'payment_preference': 'cash',
      'preferred_job_categories': ['organization'],
      'created_at': '2026-07-21T12:00:00.000Z',
      'updated_at': '2026-07-21T12:30:00.000Z',
    });

    expect(profile.displayName, 'Persistent User');
    expect(profile.preferredJobCategories, ['organization']);
    expect(profile.createdAt, DateTime.utc(2026, 7, 21, 12));
    expect(profile.updatedAt, DateTime.utc(2026, 7, 21, 12, 30));
  });

  test(
    'profile repository uses production v2 onboarding and guards legacy writes',
    () {
      final source = File(
        'lib/data/repositories/profile_repository.dart',
      ).readAsStringSync();

      expect(source, contains("'save_my_onboarding_account_v2'"));
      expect(source, contains("'save_my_onboarding_work_v2'"));
      expect(source, contains("'save_my_onboarding_safety_v2'"));
      expect(source, contains("'complete_my_onboarding_v2'"));
      for (final missingRpc in const [
        'save_my_profile_setup_v2',
        'save_my_onboarding_profile',
        'save_my_transportation_preferences',
        'update_my_profile',
        'complete_my_onboarding',
        'save_my_onboarding_age',
        'save_my_onboarding_role',
        'save_my_onboarding_progress',
        'record_my_onboarding_acknowledgement',
      ]) {
        expect(source, isNot(contains("'$missingRpc'")));
      }
      expect(source, contains('throw _profileUpdateUnavailable'));
      expect(source, contains('throw _legacyOnboardingUnavailable'));
      expect(source, isNot(contains(".from('profiles').update")));
      expect(source, isNot(contains(".from('profiles').upsert")));
      expect(source, contains("result['ok'] != true"));
      expect(source, contains('profile_conflict_detected'));
    },
  );

  test('recoverable profile errors leave form controllers intact', () {
    final source = File('lib/features/mort_screens.dart').readAsStringSync();
    final profileScreenStart = source.indexOf('class _ProfileSetupScreenState');
    final profileScreenEnd = source.indexOf(
      'class SkillsScreen',
      profileScreenStart,
    );
    expect(profileScreenStart, isNonNegative);
    expect(profileScreenEnd, greaterThan(profileScreenStart));
    final profileSource = source.substring(
      profileScreenStart,
      profileScreenEnd,
    );

    expect(profileSource, contains('if (_busy) return;'));
    expect(profileSource, contains('userFacingError(error)'));
    expect(profileSource, isNot(contains('_name.clear()')));
    expect(profileSource, isNot(contains('_bio.clear()')));
  });
}
