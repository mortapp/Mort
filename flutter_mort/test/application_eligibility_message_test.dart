import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/application.dart';

void main() {
  ApplicationEligibility eligibility(String code) => ApplicationEligibility(
    eligible: false,
    code: code,
    message: 'Complete age verification before applying.',
    guardianRequiredForThisJob: false,
    guardianLinked: false,
  );

  test('explains when age verification is required but unavailable', () {
    expect(
      eligibility('age_verification_required').userFacingMessage(
        ageVerificationAvailable: false,
      ),
      'Age verification is required to apply. MORT is not accepting '
      'verification submissions right now, so you cannot apply yet.',
    );
  });

  test('explains when age verification availability cannot be confirmed', () {
    expect(
      eligibility('age_verification_required').userFacingMessage(
        ageVerificationAvailable: null,
      ),
      'Age verification is required to apply. MORT could not confirm '
      'verification availability, so applications are paused for your account.',
    );
  });

  test('keeps the backend message when age verification is available', () {
    expect(
      eligibility('age_verification_required').userFacingMessage(
        ageVerificationAvailable: true,
      ),
      'Complete age verification before applying.',
    );
  });

  test('does not rewrite unrelated eligibility reasons', () {
    expect(
      eligibility('guardian_approval_required').userFacingMessage(
        ageVerificationAvailable: false,
      ),
      'Complete age verification before applying.',
    );
  });
}
