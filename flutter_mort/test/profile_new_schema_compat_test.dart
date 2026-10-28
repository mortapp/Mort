import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/profile.dart';

void main() {
  test('profile reads the new Supabase date, region, and completion fields', () {
    final profile = Profile.fromMap({
      'id': 'profile-1',
      'role': 'guardian',
      'display_name': 'Jordan',
      'username': 'jordan_guardian',
      'date_of_birth': '1988-02-03',
      'region': 'IN',
      'location_setup_mode': 'city_state',
      'onboarding_completed_at': '2026-10-27T12:00:00Z',
      'account_status': 'pending',
      'guardian_setup_status': 'not_started',
      'verification_status': 'not_started',
      'payment_preference': 'none',
    });

    expect(profile.role, UserRole.guardian);
    expect(profile.dob, DateTime(1988, 2, 3));
    expect(profile.state, 'IN');
    expect(profile.onboardingCompleted, isTrue);
    expect(profile.isActive, isFalse);
  });
}
