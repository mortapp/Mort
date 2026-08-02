import 'dart:io';

import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile parses persisted transportation preferences', () {
    final profile = Profile.fromMap({
      'id': '00000000-0000-0000-0000-000000000001',
      'role': 'teen',
      'display_name': 'Alex',
      'transportation_methods': ['walking', 'bicycle'],
      'max_travel_distance_miles': 4,
      'max_travel_minutes': 25,
      'walking_distance_only': true,
      'guardian_transportation_possible': false,
    });

    expect(profile.transportationMethods, ['walking', 'bicycle']);
    expect(profile.maxTravelDistanceMiles, 4);
    expect(profile.maxTravelMinutes, 25);
    expect(profile.walkingDistanceOnly, isTrue);
    expect(profile.guardianTransportationPossible, isFalse);
  });

  test('transportation RPC remains self-bound and server validated', () {
    final migration = File(
      '../supabase/migrations/20260728183833_teen_transportation_preferences.sql',
    ).readAsStringSync();

    expect(migration, contains('auth.uid()'));
    expect(migration, contains("v_profile.role <> 'teen'"));
    expect(migration, contains('transportation_methods_invalid'));
    expect(migration, contains('profile_update_audit_events'));
    expect(migration, contains('revoke execute'));
    expect(migration, isNot(contains('p_user_id')));
    expect(migration, isNot(contains('add column if not exists address')));
  });

  test('transportation client uses the authenticated RPC write path', () {
    final repository = File(
      'lib/data/repositories/profile_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/onboarding/transportation_screen.dart',
    ).readAsStringSync();

    expect(repository, contains("'save_my_transportation_preferences'"));
    expect(repository, isNot(contains(".from('profiles').update")));
    expect(screen, contains('never guarantee a ride'));
    expect(screen, contains('reveal your home address'));
    expect(screen, contains('MortColors.lightBlue'));
  });

  test('job model and draft preserve transportation compatibility', () {
    final job = Job.fromMap({
      'id': '00000000-0000-0000-0000-000000000010',
      'poster_id': '00000000-0000-0000-0000-000000000020',
      'title': 'Yard cleanup',
      'description': 'Gather leaves in a visible shared yard.',
      'category': 'lawn care',
      'location_text': 'North side',
      'city': 'Indianapolis',
      'state': 'IN',
      'status': 'open',
      'acceptable_transportation_methods': ['walking', 'bicycle'],
      'transportation_considerations': 'Near a public bus stop.',
    });
    final draft =
        JobDraft(clientRequestId: '00000000-0000-0000-0000-000000000030')
          ..acceptableTransportationMethods = ['walking']
          ..transportationConsiderations = 'Public meeting point';

    expect(job.acceptableTransportationMethods, ['walking', 'bicycle']);
    expect(job.transportationConsiderations, 'Near a public bus stop.');
    expect(draft.toMap()['acceptable_transportation_methods'], ['walking']);
    expect(
      draft.toMap()['transportation_considerations'],
      'Public meeting point',
    );
  });

  test('job transportation migration validates public matching fields', () {
    final migration = File(
      '../supabase/migrations/20260728185618_job_transportation_matching.sql',
    ).readAsStringSync();

    expect(migration, contains('acceptable_transportation_methods'));
    expect(migration, contains('job_transportation_invalid'));
    expect(migration, contains('char_length(v_transportation_notes) > 500'));
    expect(migration, contains('public.save_job_draft_or_publish'));
    expect(migration, isNot(contains('exact_address')));
  });
}
