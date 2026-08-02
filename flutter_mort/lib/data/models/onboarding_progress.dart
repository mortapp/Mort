const mortOnboardingAcknowledgementVersion = 'mort-closed-pilot-safety-v1';

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
