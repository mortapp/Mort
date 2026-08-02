import 'dart:io';

import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding progress parses the server-owned resume cursor', () {
    final progress = OnboardingProgress.fromMap({
      'current_step': 'transportation',
      'resume_path': '/onboarding/transportation',
      'completed_steps': ['age', 'role', 'profile', 'skills', 'availability'],
      'notification_choice': 'ask_later',
      'accessibility_preferences': {
        'reduced_motion': true,
        'larger_text': false,
      },
      'safety_setup_choice': 'declined_optional',
      'acknowledgement_version': mortOnboardingAcknowledgementVersion,
    });

    expect(progress.currentStep, 'transportation');
    expect(progress.resumePath, '/onboarding/transportation');
    expect(progress.completedSteps, containsAll(['age', 'availability']));
    expect(progress.accessibilityPreferences['reduced_motion'], isTrue);
    expect(progress.safetySetupChoice, 'declined_optional');
    expect(
      progress.acknowledgementVersion,
      mortOnboardingAcknowledgementVersion,
    );
    expect(progress.isComplete, isFalse);
  });

  test('server migration owns ordering, RLS, and completion transition', () {
    final migration = File(
      '../supabase/migrations/20260730003000_server_authoritative_resumable_onboarding.sql',
    ).readAsStringSync();

    expect(migration, contains('onboarding_prerequisite_required'));
    expect(migration, contains('onboarding_steps_incomplete'));
    expect(migration, contains('onboarding_acknowledgement_required'));
    expect(migration, contains('published_legal_acceptance_required'));
    expect(migration, contains('production_legal_documents_unavailable'));
    expect(
      migration,
      contains('enforce_server_authoritative_onboarding_completion'),
    );
    expect(migration, contains("set_config('mort.onboarding_completion'"));
    expect(
      migration,
      contains(
        'alter table public.onboarding_progress force row level security',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on table public.onboarding_progress from public, anon, authenticated',
      ),
    );
    expect(
      migration,
      isNot(
        contains(
          'grant select on table public.onboarding_progress to authenticated',
        ),
      ),
    );
  });

  test('client records safety before review-only completion', () {
    final screens = File('lib/features/mort_screens.dart').readAsStringSync();
    final preferences = File(
      'lib/features/onboarding/onboarding_preferences_screens.dart',
    ).readAsStringSync();
    final safetyStart = screens.indexOf('class _SafetyRulesScreenState');
    final safetyEnd = screens.indexOf(
      'class _OnboardingMomentumCard',
      safetyStart,
    );
    final safety = screens.substring(safetyStart, safetyEnd);

    expect(safety, contains('recordOnboardingAcknowledgement'));
    expect(safety, contains("completedStep: 'safety'"));
    expect(safety, contains("context.go('/onboarding/review')"));
    expect(safety, isNot(contains('completeOnboarding()')));
    expect(preferences, contains("completedStep: 'review'"));
    expect(preferences, contains('completeOnboarding()'));
  });

  test('legacy payment values are clamped to non-credential choices', () {
    final source = File('lib/features/mort_screens.dart').readAsStringSync();
    expect(source, contains("const allowed = {'none', 'cash', 'flexible'}"));
    expect(source, isNot(contains("'cash_app': '")));
    expect(source, isNot(contains("'square_link': '")));
  });
}
