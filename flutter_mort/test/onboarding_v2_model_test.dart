import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 progress parses the exact four-step server contract', () {
    final progress = OnboardingProgressV2.fromMap({
      'completed': false,
      'active_step': 'work_preferences',
      'primary_steps': const [
        'account',
        'work_preferences',
        'safety_support',
        'review',
      ],
      'completed_steps': const ['account'],
      'missing_requirements': const ['preferred_job_categories'],
      'role': 'teen',
      'revision': '2026-08-28T02:30:00.000Z',
    });

    expect(progress.completed, isFalse);
    expect(progress.activeStep, OnboardingStepV2.workPreferences);
    expect(progress.primarySteps, const [
      OnboardingStepV2.account,
      OnboardingStepV2.workPreferences,
      OnboardingStepV2.safetySupport,
      OnboardingStepV2.review,
    ]);
    expect(progress.completedSteps, const [OnboardingStepV2.account]);
    expect(progress.missingRequirements, const ['preferred_job_categories']);
    expect(progress.role, UserRole.teen);
    expect(progress.revision, DateTime.utc(2026, 8, 28, 2, 30));
  });

  test('v2 progress rejects a fifth primary user-facing step', () {
    expect(
      () => OnboardingProgressV2.fromMap({
        'completed': false,
        'active_step': 'account',
        'primary_steps': const [
          'account',
          'work_preferences',
          'safety_support',
          'review',
          'legal',
        ],
        'completed_steps': const [],
        'missing_requirements': const ['profile'],
      }),
      throwsFormatException,
    );
  });
}
