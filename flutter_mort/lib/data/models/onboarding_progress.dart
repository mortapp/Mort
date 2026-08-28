import 'profile.dart';

const mortOnboardingAcknowledgementVersion = 'mort-closed-pilot-safety-v1';

enum OnboardingStepV2 {
  account('account'),
  workPreferences('work_preferences'),
  safetySupport('safety_support'),
  review('review'),
  complete('complete');

  const OnboardingStepV2(this.serverValue);
  final String serverValue;

  static OnboardingStepV2 parse(Object? value) {
    return values.firstWhere(
      (step) => step.serverValue == value,
      orElse: () => throw FormatException(
        'Unknown onboarding step returned by the server.',
      ),
    );
  }
}

class OnboardingProgressV2 {
  const OnboardingProgressV2({
    required this.completed,
    required this.activeStep,
    required this.primarySteps,
    required this.completedSteps,
    required this.missingRequirements,
    required this.role,
    required this.revision,
    this.replayed = false,
  });

  static const contractSteps = <OnboardingStepV2>[
    OnboardingStepV2.account,
    OnboardingStepV2.workPreferences,
    OnboardingStepV2.safetySupport,
    OnboardingStepV2.review,
  ];

  final bool completed;
  final OnboardingStepV2 activeStep;
  final List<OnboardingStepV2> primarySteps;
  final List<OnboardingStepV2> completedSteps;
  final List<String> missingRequirements;
  final UserRole? role;
  final DateTime? revision;
  final bool replayed;

  factory OnboardingProgressV2.fromMap(Map<String, dynamic> map) {
    final primary = (map['primary_steps'] as List? ?? const [])
        .map(OnboardingStepV2.parse)
        .toList(growable: false);
    if (primary.length != contractSteps.length ||
        !List.generate(
          contractSteps.length,
          (index) => primary[index] == contractSteps[index],
        ).every((matches) => matches)) {
      throw const FormatException(
        'The server onboarding contract is not the supported four-step flow.',
      );
    }
    return OnboardingProgressV2(
      completed: map['completed'] == true,
      activeStep: OnboardingStepV2.parse(map['active_step']),
      primarySteps: primary,
      completedSteps: (map['completed_steps'] as List? ?? const [])
          .map(OnboardingStepV2.parse)
          .toList(growable: false),
      missingRequirements: (map['missing_requirements'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      role: userRoleFromString(map['role']?.toString()),
      revision: DateTime.tryParse(map['revision']?.toString() ?? '')?.toUtc(),
      replayed: map['replayed'] == true,
    );
  }
}

class OnboardingProgress {
  const OnboardingProgress({
    required this.currentStep,
    required this.resumePath,
    required this.completedSteps,
    required this.notificationChoice,
    required this.accessibilityPreferences,
    required this.safetySetupChoice,
    this.adultAccountType,
    this.businessName,
    this.acknowledgementVersion,
  });

  final String currentStep;
  final String resumePath;
  final List<String> completedSteps;
  final String notificationChoice;
  final Map<String, bool> accessibilityPreferences;
  final String? adultAccountType;
  final String? businessName;
  final String safetySetupChoice;
  final String? acknowledgementVersion;

  bool get isComplete => currentStep == 'complete';

  factory OnboardingProgress.fromMap(Map<String, dynamic> map) {
    final accessibility = Map<String, dynamic>.from(
      (map['accessibility_preferences'] as Map?) ?? const {},
    );
    return OnboardingProgress(
      currentStep: map['current_step']?.toString() ?? 'age',
      resumePath: map['resume_path']?.toString() ?? '/onboarding/age',
      completedSteps: (map['completed_steps'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      notificationChoice: map['notification_choice']?.toString() ?? 'ask_later',
      accessibilityPreferences: accessibility.map(
        (key, value) => MapEntry(key, value == true),
      ),
      adultAccountType: map['adult_account_type']?.toString(),
      businessName: map['business_name']?.toString(),
      safetySetupChoice:
          map['safety_setup_choice']?.toString() ?? 'review_later',
      acknowledgementVersion: map['acknowledgement_version']?.toString(),
    );
  }
}
