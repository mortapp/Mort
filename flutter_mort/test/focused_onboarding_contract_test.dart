import 'package:flutter_mort/features/onboarding/compact_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teen account setup uses focused visual steps instead of one mega-form', () {
    expect(
      CompactOnboardingVisualStep.values,
      const [
        CompactOnboardingVisualStep.age,
        CompactOnboardingVisualStep.school,
        CompactOnboardingVisualStep.schoolEmail,
        CompactOnboardingVisualStep.identity,
        CompactOnboardingVisualStep.generalArea,
        CompactOnboardingVisualStep.workPreferences,
        CompactOnboardingVisualStep.safetySupport,
        CompactOnboardingVisualStep.review,
      ],
    );

    expect(CompactOnboardingVisualStep.age.title, 'How old are you?');
    expect(CompactOnboardingVisualStep.school.title, 'Find your school');
    expect(
      CompactOnboardingVisualStep.schoolEmail.title,
      'Verify your school email',
    );
    expect(CompactOnboardingVisualStep.identity.title, 'Your MORT identity');
    expect(CompactOnboardingVisualStep.generalArea.title, 'Your general area');
  });
}
