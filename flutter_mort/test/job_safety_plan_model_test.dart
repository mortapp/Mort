import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';

void main() {
  test('job safety plan maps the persisted Supabase row', () {
    final plan = JobSafetyPlan.fromMap({
      'expected_people': 'Guardian will be present',
      'public_or_visible_meeting': true,
      'daylight_preferred': false,
      'transportation_plan': 'Guardian pickup',
      'checkin_cadence_minutes': 45,
    });

    expect(plan.expectedPeople, 'Guardian will be present');
    expect(plan.publicOrVisibleMeeting, isTrue);
    expect(plan.daylightPreferred, isFalse);
    expect(plan.transportationPlan, 'Guardian pickup');
    expect(plan.checkinCadenceMinutes, 45);
  });

  test('job safety plan handles nullable text fields', () {
    final plan = JobSafetyPlan.fromMap({
      'expected_people': null,
      'public_or_visible_meeting': true,
      'daylight_preferred': true,
      'transportation_plan': null,
      'checkin_cadence_minutes': 30,
    });

    expect(plan.expectedPeople, isNull);
    expect(plan.transportationPlan, isNull);
    expect(plan.checkinCadenceMinutes, 30);
  });
}
