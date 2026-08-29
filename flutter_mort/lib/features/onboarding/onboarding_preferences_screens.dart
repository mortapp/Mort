import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/preferences/mort_experience_preferences.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

class OnboardingPreferencesScreen extends ConsumerStatefulWidget {
  const OnboardingPreferencesScreen({super.key});

  @override
  ConsumerState<OnboardingPreferencesScreen> createState() =>
      _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState
    extends ConsumerState<OnboardingPreferencesScreen> {
  String _notificationChoice = 'ask_later';
  bool _reducedMotion = false;
  bool _largerText = false;
  bool _highContrast = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final progress = await ref
          .read(profileRepositoryProvider)
          .getOnboardingProgress();
      if (!mounted) return;
      setState(() {
        _notificationChoice = progress.notificationChoice;
        _reducedMotion =
            progress.accessibilityPreferences['reduced_motion'] ?? false;
        _largerText = progress.accessibilityPreferences['larger_text'] ?? false;
        _highContrast =
            progress.accessibilityPreferences['high_contrast'] ?? false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(
            completedStep: 'preferences',
            preferences: {
              'notification_choice': _notificationChoice,
              'accessibility_preferences': {
                'reduced_motion': _reducedMotion,
                'larger_text': _largerText,
                'high_contrast': _highContrast,
              },
            },
          );
      await ref
          .read(mortExperiencePreferencesProvider.notifier)
          .applyOnboardingPreferences(
            reducedMotion: _reducedMotion,
            highContrast: _highContrast,
          );
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/safety');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const MortLoading(label: 'Loading preferences');
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Preferences',
          title: 'Choose how MORT should feel',
          subtitle:
              'These choices are private. Notification permission is requested by the operating system later and can be changed in Settings.',
        ),
        const MortStepper(current: 9, total: 12),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Notifications',
          value: _notificationChoice,
          items: const {
            'ask_later': 'Ask me later',
            'enabled': 'I want safety and job notifications',
            'disabled': 'Do not ask right now',
          },
          onChanged: (value) =>
              setState(() => _notificationChoice = value ?? 'ask_later'),
        ),
        const SizedBox(height: MortSpacing.md),
        MortGlassCard(
          infoAccent: true,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduce MORT motion'),
                subtitle: const Text(
                  'MORT also honors the device reduced-motion setting.',
                ),
                value: _reducedMotion,
                onChanged: (value) => setState(() => _reducedMotion = value),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prefer larger text'),
                subtitle: const Text(
                  'Your device text-size setting remains the source of truth.',
                ),
                value: _largerText,
                onChanged: (value) => setState(() => _largerText = value),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prefer higher contrast'),
                value: _highContrast,
                onChanged: (value) => setState(() => _highContrast = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save preferences and continue',
          busyLabel: 'Saving preferences...',
          busy: _busy,
          icon: Icons.accessibility_new_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}

class OnboardingReviewScreen extends ConsumerStatefulWidget {
  const OnboardingReviewScreen({super.key});

  @override
  ConsumerState<OnboardingReviewScreen> createState() =>
      _OnboardingReviewScreenState();
}

class _OnboardingReviewScreenState
    extends ConsumerState<OnboardingReviewScreen> {
  bool _busy = false;

  Future<void> _complete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'review');
      await ref.read(profileRepositoryProvider).completeOnboarding();
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/account-status');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final progress = ref.watch(onboardingProgressProvider);
    if (profile.isLoading || progress.isLoading) {
      return const MortLoading(label: 'Reviewing saved setup');
    }
    if (profile.hasError || progress.hasError) {
      return MortScreen(
        children: [
          MortErrorState(
            title: 'Setup review unavailable',
            message: userFacingError(profile.error ?? progress.error),
          ),
        ],
      );
    }
    final savedProfile = profile.value;
    final savedProgress = progress.value;
    if (savedProfile == null || savedProgress == null) {
      return const MortScreen(
        children: [
          MortErrorState(
            title: 'Profile required',
            message: 'Return to profile setup before finishing onboarding.',
          ),
        ],
      );
    }
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Final review',
          title: 'Check your saved setup',
          subtitle:
              'MORT will ask you to fix any missing mandatory step. Completion never grants verification or a privileged role.',
        ),
        const MortStepper(current: 11, total: 12),
        const SizedBox(height: MortSpacing.md),
        MortGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewLine(label: 'Role', value: _roleLabel(savedProfile.role)),
              _ReviewLine(
                label: 'Display',
                value: savedProfile.displayName ?? 'Missing',
              ),
              _ReviewLine(
                label: 'Username',
                value: savedProfile.username ?? 'Missing',
              ),
              _ReviewLine(
                label: 'Area',
                value: savedProfile.locationSetupMode == 'city_state'
                    ? '${savedProfile.city ?? ''}, ${savedProfile.state ?? ''}'
                    : 'Private ${savedProfile.locationSetupMode.replaceAll('_', ' ')} setup',
              ),
              _ReviewLine(
                label: 'Notifications',
                value: savedProgress.notificationChoice.replaceAll('_', ' '),
              ),
              _ReviewLine(
                label: 'Guardian Mode',
                value: savedProfile.isTeen
                    ? savedProgress.safetySetupChoice.replaceAll('_', ' ')
                    : 'Not required for this role',
              ),
              _ReviewLine(
                label: 'Verification',
                value: savedProfile.verificationStatus.replaceAll('_', ' '),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Finishing setup does not mean your identity is verified, payment is protected, or every marketplace action is available.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Finish saved setup',
          busyLabel: 'Verifying every step...',
          busy: _busy,
          icon: Icons.fact_check_rounded,
          onPressed: _complete,
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MortSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _roleLabel(UserRole? role) => switch (role) {
  UserRole.teen => 'Teen',
  UserRole.adult => 'Adult / job poster',
  UserRole.guardian => 'Guardian',
  UserRole.admin => 'Admin (server assigned)',
  null => 'Missing',
};
