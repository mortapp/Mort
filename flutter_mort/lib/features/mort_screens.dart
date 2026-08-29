import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/errors/mort_error.dart';
import '../core/errors/user_facing_error.dart';
import '../core/money/mort_service_fee.dart';
import '../core/theme/mort_colors.dart';
import '../core/theme/mort_spacing.dart';
import '../core/theme/mort_tokens.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../core/utils/date_of_birth.dart';
import '../core/widgets/date_of_birth_field.dart';
import '../core/widgets/mort_widgets.dart';
import '../data/models/application.dart';
import '../data/models/job.dart';
import '../data/models/message.dart';
import '../data/models/onboarding_progress.dart';
import '../data/models/profile.dart';
import '../data/repositories/providers.dart';
import '../data/repositories/messaging_repository.dart';
import '../data/repositories/uploads_repository.dart';
import '../data/services/supabase_service.dart';
import 'ads/widgets/mort_banner_ad.dart';
import 'mission/partner_staff_screens.dart';
import 'onboarding/mort_rules_copy.dart';
import 'profile/profile_avatar_widgets.dart';
import 'teen/teen_shell.dart';

bool get _backendReady => SupabaseService.isInitialized;

final releaseModeStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return ref.read(missionPilotRepositoryProvider).releaseModeStatus();
});

final backendConnectionStatusProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseService.isInitialized) return false;
  try {
    await ref
        .read(missionPilotRepositoryProvider)
        .releaseModeStatus()
        .timeout(const Duration(seconds: 8));
    return true;
  } catch (_) {
    return false;
  }
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const SizedBox(height: MortSpacing.xl),
        const Center(
          child: MortAnimatedBrandMark(size: 176, showWordmark: true),
        ),
        const SizedBox(height: MortSpacing.lg),
        Text(
          AppConfig.slogan,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: MortColors.textSoft),
        ),
        const SizedBox(height: MortSpacing.xl),
        const MortSafetyBanner(
          message: 'Real local work, protected messages, PIN check-in, and free safety tools.',
        ),
        const SizedBox(height: MortSpacing.xl),
        MortButton(
          label: 'Enter MORT',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => context.go('/welcome'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Sign in',
          icon: Icons.person_outline_rounded,
          style: MortButtonStyle.ghost,
          onPressed: () => context.push('/auth/sign-in'),
        ),
        const SizedBox(height: MortSpacing.md),
        Semantics(liveRegion: true, child: _BackendStatusCard()),
      ],
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    infoAccent: title == 'Safety stays free',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: title == 'Safety stays free'
              ? MortColors.lightBlue
              : MortColors.roseGold,
        ),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MortSpacing.xxs),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The primary CTAs are pinned in `bottom:` (matching the same
    // always-visible, safe-area-respecting pattern used for e.g. the job
    // detail Apply button) rather than living inside the scrollable
    // `children`. A real, physically-confirmed bug on a device with a
    // 3-button navigation bar: when content is tall enough that the
    // screen's natural resting (unscrolled) height ends near the
    // viewport height, whichever child happens to fall in that last
    // stretch renders behind -- and receives no touches through -- the
    // system navigation bar, with no visual indication it needs to be
    // scrolled. Scrollable-child trailing SafeArea padding does not
    // protect against this; only content the system bar can never reach
    // (Scaffold.bottomNavigationBar territory) reliably does.
    return MortScreen(
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          MortSpacing.md,
          MortSpacing.xs,
          MortSpacing.md,
          MortSpacing.md,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: MortColors.bg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MortButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () => context.push('/auth/sign-up'),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'I already have an account',
                icon: Icons.login_rounded,
                style: MortButtonStyle.secondary,
                onPressed: () => context.push('/auth/sign-in'),
              ),
            ],
          ),
        ),
      ),
      children: [
        const Center(child: MortBrandMark(size: 96, showWordmark: true)),
        const SizedBox(height: MortSpacing.xl),
        const MortHeader(
          eyebrow: 'Earn nearby. Move smart.',
          title: 'Welcome to MORT',
          subtitle: 'Safe neighborhood jobs for teens, supported by adults, guardians, and accountable moderation.',
        ),
        const _WelcomeFeature(
          icon: Icons.schedule_rounded,
          title: 'Flexible local work',
          body: 'Find age-appropriate jobs that fit your schedule and area.',
        ),
        const SizedBox(height: MortSpacing.sm),
        const _WelcomeFeature(
          icon: Icons.shield_outlined,
          title: 'Safety stays free',
          body: 'Report, block, Safety Ping, and core Guardian Mode are never paywalled.',
        ),
        const SizedBox(height: MortSpacing.sm),
        const _WelcomeFeature(
          icon: Icons.pin_outlined,
          title: 'Verified job handoff',
          body: 'Separate secure start and finish PINs protect the work timeline.',
        ),
        const SizedBox(height: MortSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push('/legal/teen-safety'),
            icon: const Icon(
              Icons.shield_outlined,
              color: MortColors.lightBlue,
            ),
            label: const Text('Read teen safety'),
          ),
        ),
      ],
    );
  }
}

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: const [
        MortHeader(
          eyebrow: 'Service unavailable',
          title: 'MORT cannot connect right now',
          subtitle: 'Close and reopen the app, then try again. Contact MORT Support if the problem continues.',
        ),
        MortErrorState(
          title: 'Connection required',
          message: 'Sign-in and account features are unavailable until MORT reconnects securely.',
        ),
      ],
    );
  }
}

class MaintenanceModeScreen extends ConsumerWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Temporary maintenance',
          title: 'MORT is paused safely',
          subtitle: 'Marketplace and account actions are temporarily unavailable while safety or reliability work is completed.',
        ),
        const MortSafetyBanner(
          message: 'Do not retry job, payment, or upload actions repeatedly. Existing provider events can still reconcile on the server.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Check again',
          icon: Icons.refresh,
          onPressed: () => ref.invalidate(releaseModeStatusProvider),
        ),
        const SizedBox(height: MortSpacing.sm),
        const Text('Support: mortapp.help@gmail.com'),
      ],
    );
  }
}

class AuthRequiredScreen extends StatelessWidget {
  const AuthRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: const [
        MortHeader(
          eyebrow: 'Sign in required',
          title: 'Sign in to continue',
          subtitle: 'Protected screens require an active MORT account session.',
        ),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Sign in',
              icon: Icons.login,
              route: '/auth/sign-in',
            ),
            MortAction(
              label: 'Create account',
              icon: Icons.person_add,
              route: '/auth/sign-up',
            ),
          ],
        ),
      ],
    );
  }
}

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final releaseMode = ref.watch(releaseModeStatusProvider);
    return profile.when(
      loading: () => const MortLoading(),
      error: (error, _) => MortErrorStateScreen(
        title: 'Account status error',
        message: userFacingError(error),
      ),
      data: (profile) {
        if (profile != null && !profile.isActive) {
          return MortScreen(
            children: [
              MortHeader(
                eyebrow: _statusLabel(profile.accountStatus),
                title: 'Account restricted',
                subtitle: 'This account cannot continue into MORT right now. Contact support for next steps.',
              ),
              const MortActionRow(
                actions: [
                  MortAction(
                    label: 'Support',
                    icon: Icons.support_agent,
                    route: '/support',
                  ),
                ],
              ),
              if (profile.accountStatus == 'banned') ...[
                const SizedBox(height: MortSpacing.md),
                const _AccountBanAppealCard(),
              ],
            ],
          );
        }
        if (profile == null || !profile.onboardingCompleted) {
          return const OnboardingRequiredScreen();
        }
        final route = switch (profile.role) {
          UserRole.teen => '/teen/home',
          UserRole.adult => '/adult/home',
          UserRole.guardian => '/guardian/home',
          UserRole.admin => '/admin/home',
          null => '/onboarding',
        };
        return MortScreen(
          children: [
            MortHeader(
              eyebrow: _statusLabel(profile.accountStatus),
              title: profile.displayName ?? 'MORT account',
              subtitle:
                  'Role: ${userRoleToString(profile.role) ?? 'Not set'} · Verification: ${_statusLabel(profile.verificationStatus)}',
            ),
            const SizedBox(height: MortSpacing.md),
            _ReleaseModeCard(status: releaseMode),
            const SizedBox(height: MortSpacing.md),
            if (!profile.isActive)
              const MortErrorState(
                title: 'Account restricted',
                message: 'This account is suspended or banned. Use support for next steps.',
              )
            else
              MortButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: () => context.go(route),
              ),
          ],
        );
      },
    );
  }
}

class _AccountBanAppealCard extends ConsumerStatefulWidget {
  const _AccountBanAppealCard();

  @override
  ConsumerState<_AccountBanAppealCard> createState() =>
      _AccountBanAppealCardState();
}

class _AccountBanAppealCardState extends ConsumerState<_AccountBanAppealCard> {
  final _reason = TextEditingController();
  bool _busy = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (_busy) return;
    if (reason.length < 20) {
      MortToast.show(context, 'Enter at least 20 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(trustSafetyRepositoryProvider)
          .submitAccountBanAppeal(reason: reason);
      if (!mounted) return;
      setState(() => _submitted = true);
      MortToast.show(context, 'Appeal submitted for independent review.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Appeal this ban',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          const Text(
            'An appeal does not restore access automatically. A different authorized reviewer must claim and decide it.',
          ),
          const SizedBox(height: MortSpacing.sm),
          if (_submitted)
            const MortSafetyBanner(
              message: 'Your appeal is queued. MORT does not promise 24/7 review coverage.',
            )
          else ...[
            MortTextArea(
              label: 'Why should this decision be reviewed?',
              controller: _reason,
              maxLines: 5,
              maxLength: 2000,
              enabled: !_busy,
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: 'Submit appeal',
              icon: Icons.gavel_outlined,
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReleaseModeCard extends StatelessWidget {
  const _ReleaseModeCard({required this.status});

  final AsyncValue<Map<String, dynamic>> status;

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => const MortSkeletonCard(),
      error: (_, _) => const MortSafetyBanner(
        message: 'Marketplace availability cannot be confirmed right now. Try again before posting or accepting work.',
      ),
      data: (data) {
        final release = data['release_mode']?.toString() ?? '';
        final marketplace = data['marketplace_mode']?.toString() ?? '';
        final publicEnabled = data['public_marketplace_enabled'] == true;
        final documentsEnabled = data['real_document_collection'] == true;
        final maintenance = data['maintenance_mode'] == true;
        final paymentsDisabled = data['payments_disabled'] != false;
        final publishingDisabled = data['new_job_publishing_disabled'] == true;
        return MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: MortColors.neon),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(
                    child: Text(
                      'Marketplace availability',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.sm),
              Wrap(
                spacing: MortSpacing.xs,
                runSpacing: MortSpacing.xs,
                children: [
                  MortBadge(label: _statusLabel(release)),
                  MortBadge(label: _statusLabel(marketplace)),
                  MortBadge(
                    label: publicEnabled
                        ? 'Public marketplace enabled'
                        : 'Marketplace access limited',
                    color: publicEnabled
                        ? MortColors.warning
                        : MortColors.safetyBlue,
                  ),
                  MortBadge(
                    label: documentsEnabled
                        ? 'Document collection enabled'
                        : 'Identity verification unavailable',
                    color: documentsEnabled
                        ? MortColors.warning
                        : MortColors.safetyBlue,
                  ),
                  if (maintenance)
                    const MortBadge(
                      label: 'Maintenance active',
                      color: MortColors.warning,
                    ),
                  MortBadge(
                    label: paymentsDisabled
                        ? 'Job payment processing unavailable'
                        : 'Job payment controls available',
                    color: paymentsDisabled
                        ? MortColors.safetyBlue
                        : MortColors.warning,
                  ),
                  if (publishingDisabled)
                    const MortBadge(
                      label: 'New publishing paused',
                      color: MortColors.warning,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _statusLabel(String value) {
  final clean = value.trim().replaceAll('_', ' ');
  if (clean.isEmpty) return 'Not available';
  if (clean.startsWith('closed ')) {
    return 'Limited access';
  }
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}

class OnboardingRequiredScreen extends ConsumerWidget {
  const OnboardingRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Onboarding',
          title: 'Finish setup',
          subtitle: 'MORT will restore the next required account, work, safety, or review step from the server.',
        ),
        MortButton(
          label: 'Continue onboarding',
          icon: Icons.flag,
          onPressed: () => context.go('/onboarding'),
        ),
      ],
    );
  }
}

class WrongRoleScreen extends StatelessWidget {
  const WrongRoleScreen({super.key, required this.requiredRole});

  final UserRole requiredRole;

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Role guard',
          title: 'Wrong account type',
          subtitle:
              'This area is for ${userRoleToString(requiredRole)} accounts.',
        ),
        MortButton(
          label: 'Go to account status',
          onPressed: () => context.go('/account-status'),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_backendReady) {
      MortToast.show(
        context,
        'MORT cannot connect right now. Try again later.',
      );
      return;
    }
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text.trim());
      if (mounted) {
        MortToast.show(
          context,
          'If an account matches that email, a reset link is on the way.',
        );
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const Center(child: MortBrandMark(size: 64)),
        const SizedBox(height: MortSpacing.md),
        const MortHeader(
          title: 'Reset password',
          subtitle: 'Request a secure reset link for your MORT account.',
        ),
        Form(
          key: _form,
          child: MortTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: MortValidators.email,
            onFieldSubmitted: (_) => _busy ? null : _submit(),
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Send reset email',
          busyLabel: 'Sending...',
          busy: _busy,
          icon: Icons.lock_reset,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class OnboardingHubScreen extends ConsumerWidget {
  const OnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingProgressProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Setup',
          title: 'Build your MORT account',
          subtitle: 'Finish age, role, profile, preferences, and the safety agreement. Marketplace access depends on server-verified account eligibility.',
        ),
        const MortStepper(current: 0, total: 12),
        const SizedBox(height: MortSpacing.md),
        progress.when(
          loading: () => const MortLoading(label: 'Loading saved setup'),
          error: (error, _) => MortErrorState(
            title: 'Saved setup unavailable',
            message: userFacingError(error),
          ),
          data: (saved) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OnboardingMomentumCard(progress: saved),
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: saved.isComplete
                    ? 'View account status'
                    : 'Continue saved setup',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go(saved.resumePath),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortActionRow(
          actions: [
            MortAction(
              label: 'Safety rules',
              icon: Icons.shield,
              route: '/onboarding/safety',
            ),
            MortAction(
              label: 'Identity verification',
              icon: Icons.verified_user,
              route: '/settings/identity-verification',
            ),
          ],
        ),
      ],
    );
  }
}

class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  final _form = GlobalKey<FormState>();
  final _dob = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _dob.dispose();
    super.dispose();
  }

  Future<void> _checkAge() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now();
    final dob = DateOfBirthParser.tryParse(_dob.text, today: now)!;
    final age = DateOfBirthParser.ageOn(dob, now);
    if (age < 13) {
      setState(() => _message = 'MORT is blocked for users under 13.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).saveOnboardingAge(dob);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) {
        context.go('/onboarding/role?age=${age < 18 ? 'teen' : 'adult'}');
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Age gate',
          title: 'How old are you?',
          subtitle: 'Teens must be 13-17. Adults and guardians must be 18+.',
        ),
        const MortStepper(current: 1, total: 12),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'Why we ask: age decides which rules apply. Teens get the teen-safe path. Adults and guardians get verification and supervision paths.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        Form(
          key: _form,
          child: DateOfBirthField(
            controller: _dob,
            onChanged: (_) {
              if (_message != null) setState(() => _message = null);
            },
            onSubmitted: (_) => _checkAge(),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: MortSpacing.sm),
          MortErrorState(title: 'Age gate', message: _message!),
        ],
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Continue',
          busyLabel: 'Saving age eligibility...',
          busy: _busy,
          icon: Icons.arrow_forward,
          onPressed: _checkAge,
        ),
      ],
    );
  }
}

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key, this.ageBand});

  final String? ageBand;

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _busyRole;

  Future<void> _select(UserRole role) async {
    if (_busyRole != null) return;
    setState(() => _busyRole = role);
    try {
      await ref.read(profileRepositoryProvider).saveOnboardingRole(role);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) {
        context.go('/onboarding/profile?role=${userRoleToString(role)}');
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyRole = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final age = profile?.dob == null
        ? null
        : DateOfBirthParser.ageOn(profile!.dob!, DateTime.now());
    final ageBand = widget.ageBand;
    final teenAllowed = age != null ? age < 18 : ageBand != 'adult';
    final adultAllowed = age != null ? age >= 18 : ageBand != 'teen';
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Role',
          title: 'Choose your lane',
          subtitle: 'Admins cannot self-select. Admin access must already exist on the backend.',
        ),
        const MortStepper(current: 2, total: 12),
        const SizedBox(height: MortSpacing.md),
        const FeatureChecklist(
          items: [
            'Teen: find nearby jobs, set preferences, learn report/block, and keep safety tools free.',
            'Adult/business: post safe local jobs, verify trust, review applicants, and follow moderation rules.',
            'Guardian: supervise linked teen activity, approvals, alerts, and privacy boundaries.',
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Teen',
              icon: Icons.bolt,
              onPressed: () => _select(UserRole.teen),
              busy: _busyRole == UserRole.teen,
              enabled: teenAllowed,
            ),
            MortAction(
              label: 'Adult / job poster',
              icon: Icons.work_outline,
              onPressed: () => _select(UserRole.adult),
              busy: _busyRole == UserRole.adult,
              enabled: adultAllowed,
            ),
            MortAction(
              label: 'Guardian',
              icon: Icons.family_restroom,
              onPressed: () => _select(UserRole.guardian),
              busy: _busyRole == UserRole.guardian,
              enabled: adultAllowed,
            ),
          ],
        ),
      ],
    );
  }
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _dob = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _bio = TextEditingController();
  final _availability = TextEditingController();
  final _approximateArea = TextEditingController();
  final _goals = TextEditingController();
  final _preferredCategories = TextEditingController();
  UserRole? _role;
  String _locationSetupMode = 'city_state';
  String _adultAccountType = 'individual';
  final _businessName = TextEditingController();
  String _clientRequestId = const Uuid().v4();
  final _fieldErrors = <String, String>{};
  final _focusNodes = <String, FocusNode>{
    for (final field in [
      'display_name',
      'username',
      'dob',
      'city',
      'state',
      'bio',
      'availability',
      'approximate_area',
      'preferred_job_categories',
      'goals',
      'business_name',
    ])
      field: FocusNode(),
  };
  Profile? _existingProfile;
  bool _busy = false;
  Timer? _draftTimer;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    for (final controller in _profileControllers) {
      controller.addListener(_onDraftFieldChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingProfile());
  }

  List<TextEditingController> get _profileControllers => [
    _name,
    _username,
    _dob,
    _city,
    _state,
    _bio,
    _availability,
    _approximateArea,
    _goals,
    _preferredCategories,
    _businessName,
  ];

  bool get _editingExisting => _existingProfile?.onboardingCompleted == true;

  void _onDraftFieldChanged() {
    if (_restoringDraft) return;
    _fieldErrors.clear();
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (!_backendReady) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null || _role == null) return;
    await ref.read(secureDraftStorageProvider).writeProfileDraft(userId, {
      'client_request_id': _clientRequestId,
      'role': userRoleToString(_role),
      'display_name': _name.text,
      'username': _username.text,
      'dob': _dob.text,
      'city': _city.text,
      'state': _state.text,
      'location_setup_mode': _locationSetupMode,
      'bio': _bio.text,
      'availability': _availability.text,
      'approximate_area': _approximateArea.text,
      'goals': _goals.text,
      'preferred_job_categories': _preferredCategories.text,
      'adult_account_type': _adultAccountType,
      'business_name': _businessName.text,
    });
  }

  Future<void> _restoreDraft() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    final draft = await ref
        .read(secureDraftStorageProvider)
        .readProfileDraft(userId);
    if (!mounted || draft == null) return;
    final draftRole = userRoleFromString(draft['role']?.toString());
    if (draftRole != null &&
        _existingProfile?.role != null &&
        draftRole != _existingProfile!.role) {
      await ref.read(secureDraftStorageProvider).clearProfileDraft(userId);
      return;
    }
    _restoringDraft = true;
    setState(() {
      final storedRequestId = draft['client_request_id']?.toString();
      if (storedRequestId != null && storedRequestId.isNotEmpty) {
        _clientRequestId = storedRequestId;
      }
      _role = draftRole ?? _role;
      _name.text = draft['display_name']?.toString() ?? _name.text;
      _username.text = draft['username']?.toString() ?? _username.text;
      _dob.text = draft['dob']?.toString() ?? _dob.text;
      _city.text = draft['city']?.toString() ?? _city.text;
      _state.text = draft['state']?.toString() ?? _state.text;
      _locationSetupMode =
          draft['location_setup_mode']?.toString() ?? _locationSetupMode;
      _bio.text = draft['bio']?.toString() ?? _bio.text;
      _availability.text =
          draft['availability']?.toString() ?? _availability.text;
      _approximateArea.text =
          draft['approximate_area']?.toString() ?? _approximateArea.text;
      _goals.text = draft['goals']?.toString() ?? _goals.text;
      _preferredCategories.text =
          draft['preferred_job_categories']?.toString() ??
          _preferredCategories.text;
      _adultAccountType =
          draft['adult_account_type']?.toString() ?? _adultAccountType;
      _businessName.text =
          draft['business_name']?.toString() ?? _businessName.text;
    });
    _restoringDraft = false;
  }

  Future<void> _loadExistingProfile() async {
    if (!_backendReady) return;
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        await _restoreDraft();
        return;
      }
      final progress = await ref
          .read(profileRepositoryProvider)
          .getOnboardingProgress();
      if (!mounted) return;
      setState(() {
        _existingProfile = profile;
        _role = profile.role ?? _role;
        if (_name.text.isEmpty) _name.text = profile.displayName ?? '';
        if (_username.text.isEmpty) _username.text = profile.username ?? '';
        if (_dob.text.isEmpty && profile.dob != null) {
          _dob.text = DateOfBirthParser.display(profile.dob!);
        }
        if (_city.text.isEmpty) _city.text = profile.city ?? '';
        if (_state.text.isEmpty) _state.text = profile.state ?? '';
        _locationSetupMode = profile.locationSetupMode;
        if (_bio.text.isEmpty) _bio.text = profile.bio ?? '';
        if (_availability.text.isEmpty) {
          _availability.text = profile.availability ?? '';
        }
        if (_approximateArea.text.isEmpty) {
          _approximateArea.text = profile.approximateArea ?? '';
        }
        if (_goals.text.isEmpty) _goals.text = profile.goals ?? '';
        if (_preferredCategories.text.isEmpty) {
          _preferredCategories.text = profile.preferredJobCategories.join(', ');
        }
        _adultAccountType = progress.adultAccountType ?? 'individual';
        if (_businessName.text.isEmpty) {
          _businessName.text = progress.businessName ?? '';
        }
      });
      await _restoreDraft();
    } catch (_) {
      if (mounted) {
        MortToast.show(
          context,
          'Saved profile details could not be loaded. You can still enter them.',
        );
      }
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final controller in _profileControllers) {
      controller.removeListener(_onDraftFieldChanged);
    }
    _name.dispose();
    _username.dispose();
    _dob.dispose();
    _city.dispose();
    _state.dispose();
    _bio.dispose();
    _availability.dispose();
    _approximateArea.dispose();
    _goals.dispose();
    _preferredCategories.dispose();
    _businessName.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_backendReady) {
      MortToast.show(
        context,
        'MORT cannot connect right now. Try again later.',
      );
      return;
    }
    if (!_form.currentState!.validate() || _role == null) return;
    final now = DateTime.now();
    final dob = DateOfBirthParser.tryParse(_dob.text, today: now)!;
    final age = DateOfBirthParser.ageOn(dob, now);
    final roleError = DateOfBirthRules.roleAgeError(
      age: age,
      teenRole: _role == UserRole.teen,
    );
    if (roleError != null) {
      MortToast.show(context, roleError);
      return;
    }
    setState(() {
      _busy = true;
      _fieldErrors.clear();
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveProfileSetup(
            role: _role!,
            displayName: _name.text,
            username: _username.text,
            dob: dob,
            city: _city.text,
            state: _state.text,
            locationSetupMode: _role == UserRole.teen
                ? _locationSetupMode
                : 'city_state',
            bio: _bio.text,
            availability: _role == UserRole.guardian ? '' : _availability.text,
            preferredJobCategories: _role == UserRole.teen
                ? _preferredCategories.text
                      .split(',')
                      .map((value) => value.trim().toLowerCase())
                      .where((value) => value.isNotEmpty)
                      .take(12)
                      .toList()
                : const [],
            approximateArea: _role == UserRole.guardian
                ? ''
                : _approximateArea.text,
            goals: _role == UserRole.teen ? _goals.text : '',
            adultAccountType: _adultAccountType,
            businessName: _businessName.text,
            editExisting: _editingExisting,
            clientRequestId: _clientRequestId,
          );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await ref.read(secureDraftStorageProvider).clearProfileDraft(userId);
      }
      if (!mounted) return;
      if (_editingExisting) {
        MortToast.show(context, 'Profile changes saved.');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/settings');
        }
      } else {
        context.go('/onboarding/skills');
      }
    } catch (error) {
      if (!mounted) return;
      if (error is MortFieldCodedError) {
        _showFieldError(error);
      }
      MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFieldError(MortFieldCodedError error) {
    final field = error.field == 'city_state' ? 'city' : error.field;
    setState(() => _fieldErrors[field] = error.message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[field]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: MortBrandMark(size: 46),
        ),
        const SizedBox(height: MortSpacing.xs),
        MortHeader(
          eyebrow: 'Profile',
          title: _editingExisting ? 'Edit your profile' : 'Set your basics',
          subtitle: _role == UserRole.teen
              ? 'A permanent address is not required. MORT never asks why you choose a partner-supported or deferred setup.'
              : 'Only safe, general location fields are used here. Exact addresses do not belong in chat.',
        ),
        if (!_editingExisting) const MortStepper(current: 3, total: 12),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Text(
            _role == UserRole.teen
                ? 'Housing status, shelter use, family status, and the reason for your location choice are not collected or shown to job posters.'
                : 'Use city and state only. Exact locations do not belong in profiles or messages.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (_existingProfile != null) ...[
          ProfileAvatarEditor(profile: _existingProfile!),
          const SizedBox(height: MortSpacing.md),
        ],
        Form(
          key: _form,
          child: Column(
            children: [
              if (_existingProfile?.role != null)
                MortGlassCard(
                  infoAccent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account type: ${switch (_existingProfile!.role!) {
                          UserRole.teen => 'Teen',
                          UserRole.adult => 'Adult / job poster',
                          UserRole.guardian => 'Guardian',
                          UserRole.admin => 'Admin',
                        }}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      const Text(
                        'For account safety, Support confirms any correction to account type or date of birth.',
                      ),
                    ],
                  ),
                )
              else
                MortDropdown<UserRole>(
                  label: 'Role',
                  value: _role,
                  items: const {
                    UserRole.teen: 'Teen 13-17',
                    UserRole.adult: 'Adult / business',
                    UserRole.guardian: 'Guardian',
                  },
                  onChanged: (value) {
                    setState(() => _role = value);
                    _onDraftFieldChanged();
                  },
                ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Display name',
                controller: _name,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                focusNode: _focusNodes['display_name'],
                errorText: _fieldErrors['display_name'],
                validator: (value) =>
                    MortValidators.requiredText(value, maximumLength: 80),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Username',
                controller: _username,
                hint: 'alex_jobs',
                maxLength: 24,
                autocorrect: false,
                enableSuggestions: false,
                focusNode: _focusNodes['username'],
                errorText: _fieldErrors['username'],
                validator: (value) {
                  final username = value?.trim().toLowerCase() ?? '';
                  if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
                    return 'Use 3-24 lowercase letters, numbers, or underscores.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: MortSpacing.sm),
              DateOfBirthField(
                controller: _dob,
                enabled: !_editingExisting,
                focusNode: _focusNodes['dob'],
                errorText: _fieldErrors['dob'],
                onChanged: (_) => _onDraftFieldChanged(),
              ),
              const SizedBox(height: MortSpacing.sm),
              if (_role == UserRole.teen) ...[
                MortDropdown<String>(
                  label: 'General location setup',
                  value: _locationSetupMode,
                  items: const {
                    'city_state': 'Use city and state',
                    'partner_supported': 'Use approved partner support',
                    'location_deferred': 'Safely defer location',
                  },
                  onChanged: (value) {
                    setState(() => _locationSetupMode = value ?? 'city_state');
                    _onDraftFieldChanged();
                  },
                ),
                const SizedBox(height: MortSpacing.sm),
                if (_locationSetupMode != 'city_state') ...[
                  const MortCard(
                    child: Text(
                      'No permanent address is required. The hosted profile stores only this setup mode, not a housing circumstance. A general job area may still be needed for safe matching.',
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
              if (_role == UserRole.adult) ...[
                MortDropdown<String>(
                  label: 'Posting as',
                  value: _adultAccountType,
                  items: const {
                    'individual': 'Individual adult',
                    'business': 'Business',
                  },
                  onChanged: (value) {
                    setState(() => _adultAccountType = value ?? 'individual');
                    _onDraftFieldChanged();
                  },
                ),
                const SizedBox(height: MortSpacing.sm),
                if (_adultAccountType == 'business') ...[
                  MortTextField(
                    label: 'Business name',
                    controller: _businessName,
                    maxLength: 120,
                    focusNode: _focusNodes['business_name'],
                    errorText: _fieldErrors['business_name'],
                    validator: (value) =>
                        MortValidators.requiredText(value, maximumLength: 120),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                const MortVerificationDisclaimer(),
                const SizedBox(height: MortSpacing.sm),
              ],
              if (_locationSetupMode == 'city_state' ||
                  _role != UserRole.teen) ...[
                MortTextField(
                  label: 'City',
                  controller: _city,
                  textInputAction: TextInputAction.next,
                  focusNode: _focusNodes['city'],
                  errorText: _fieldErrors['city'],
                  validator: (value) {
                    if (_role == UserRole.teen &&
                        _locationSetupMode != 'city_state') {
                      return null;
                    }
                    return MortValidators.requiredText(
                      value,
                      maximumLength: 120,
                    );
                  },
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextField(
                  label: 'State',
                  hint: 'IN',
                  controller: _state,
                  textInputAction: TextInputAction.done,
                  maxLength: 2,
                  focusNode: _focusNodes['state'],
                  errorText: _fieldErrors['state'],
                  validator: (value) {
                    if (_role == UserRole.teen &&
                        _locationSetupMode != 'city_state') {
                      return null;
                    }
                    return MortValidators.stateCode(value);
                  },
                ),
                const SizedBox(height: MortSpacing.sm),
              ],
              MortTextArea(
                label: 'Bio',
                controller: _bio,
                maxLength: 500,
                focusNode: _focusNodes['bio'],
                errorText: _fieldErrors['bio'],
                hint: 'Share safe experience and interests without contact details.',
              ),
              const SizedBox(height: MortSpacing.sm),
              if (_role == UserRole.teen) ...[
                MortTextField(
                  label: 'Availability',
                  controller: _availability,
                  hint: 'Weekends and weekday afternoons',
                  maxLength: 240,
                  focusNode: _focusNodes['availability'],
                  errorText: _fieldErrors['availability'],
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextField(
                  label: 'Approximate work area',
                  controller: _approximateArea,
                  hint: 'General neighborhood or side of town',
                  maxLength: 120,
                  focusNode: _focusNodes['approximate_area'],
                  errorText: _fieldErrors['approximate_area'],
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextField(
                  label: 'Preferred job categories',
                  controller: _preferredCategories,
                  hint: 'cleaning, tutoring, pet care',
                  focusNode: _focusNodes['preferred_job_categories'],
                  errorText: _fieldErrors['preferred_job_categories'],
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextArea(
                  label: 'Goals',
                  controller: _goals,
                  maxLength: 500,
                  focusNode: _focusNodes['goals'],
                  errorText: _fieldErrors['goals'],
                ),
              ] else if (_role == UserRole.adult) ...[
                MortTextField(
                  label: 'Scheduling and contact preference',
                  controller: _availability,
                  hint: 'For example, weekday evenings in MORT messages',
                  maxLength: 240,
                  focusNode: _focusNodes['availability'],
                  errorText: _fieldErrors['availability'],
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextField(
                  label: 'Approximate service area',
                  controller: _approximateArea,
                  hint: 'General neighborhood or side of town',
                  maxLength: 120,
                  focusNode: _focusNodes['approximate_area'],
                  errorText: _fieldErrors['approximate_area'],
                ),
              ] else if (_role == UserRole.guardian) ...[
                const MortSafetyBanner(
                  message: 'Guardian Mode is optional. Teen linking and safety notification choices are handled in the next private setup steps.',
                ),
              ],
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: 'Save profile',
                busyLabel: 'Saving...',
                busy: _busy,
                icon: Icons.save,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'skills');
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/availability');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentProfileProvider).asData?.value?.role;
    final title = switch (role) {
      UserRole.adult => 'Set safe posting expectations',
      UserRole.guardian => 'Choose supervision boundaries',
      _ => 'Show what you can do safely',
    };
    final description = switch (role) {
      UserRole.adult =>
        'Review what adults and businesses must provide before posting a job.',
      UserRole.guardian =>
        'Guardian Mode is optional and limited to linked safety information.',
      _ => 'Start with common, safe local categories. You can update interests later.',
    };
    final checklist = switch (role) {
      UserRole.adult => const [
        'Describe the work, schedule, offered compensation, equipment, and supervision clearly.',
        'Never ask a teen to move off-platform, pay an upfront fee, or share private contact details.',
        'Verification and account review remain required before applications can open.',
      ],
      UserRole.guardian => const [
        'Teen linking is optional and requires a valid invitation or approval flow.',
        'Guardians receive only permitted safety and job-status details.',
        'Private message content and exact location are not exposed by default.',
      ],
      _ => const [
        'Yard help, pet care, tutoring, cleaning, errands, creative help, and event setup are safe starting categories.',
        'Avoid unsafe tools, overnight work, isolated work, or off-platform pressure.',
        'Stop, block, report, or send a Safety Ping whenever something feels wrong.',
      ],
    };
    return FeatureScaffoldScreen(
      eyebrow: role == UserRole.teen ? 'Skills' : 'Safety setup',
      title: title,
      description: description,
      children: [
        const MortStepper(current: 4, total: 12),
        const SizedBox(height: MortSpacing.md),
        FeatureChecklist(items: checklist),
      ],
      actions: [
        if (role == UserRole.teen) ...[
          const MortAction(
            label: 'Discreet Mode',
            icon: Icons.visibility_off_outlined,
            route: '/mission/discreet-mode',
          ),
          const MortAction(
            label: 'Optional Support Circle',
            icon: Icons.groups_outlined,
            route: '/mission/support-circle',
          ),
        ],
        const MortAction(
          label: 'Job safety',
          icon: Icons.work_outline,
          route: '/mission/pilot-job-safety',
        ),
        MortAction(
          label: 'Continue',
          icon: Icons.arrow_forward,
          busy: _busy,
          onPressed: _continue,
        ),
      ],
    );
  }
}

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'availability');
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/transportation');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentProfileProvider).asData?.value?.role;
    return FeatureScaffoldScreen(
      eyebrow: 'Availability',
      title: switch (role) {
        UserRole.adult => 'Set clear scheduling habits',
        UserRole.guardian => 'Choose notification timing',
        _ => 'Pick safe time windows',
      },
      description: switch (role) {
        UserRole.adult => 'Jobs need clear start, end, flexibility, and supervision expectations.',
        UserRole.guardian =>
          'Safety alerts and approvals can be adjusted after optional linking.',
        _ => 'Use daylight-first windows that fit school and local rules.',
      },
      children: [
        const MortStepper(current: 5, total: 12),
        const SizedBox(height: MortSpacing.md),
        FeatureChecklist(
          items: switch (role) {
            UserRole.adult => const [
              'Use future dates and clear start/end expectations.',
              'Allow enough time for safe travel and check-in.',
              'Never pressure a teen to accept last-minute off-platform changes.',
            ],
            UserRole.guardian => const [
              'Choose which optional approvals and safety alerts you want.',
              'Quiet hours never disable urgent in-app safety actions.',
              'Guardian Mode does not provide continuous monitoring.',
            ],
            _ => const [
              'Prefer after-school, weekend, and daylight-first windows.',
              'Leave enough time for safe transportation and check-ins.',
              'Decline work that conflicts with school, local rules, or safety.',
            ],
          },
        ),
      ],
      actions: [
        MortAction(
          label: 'Continue',
          icon: Icons.arrow_forward,
          busy: _busy,
          onPressed: _continue,
        ),
      ],
    );
  }
}

class PaymentPreferenceScreen extends ConsumerStatefulWidget {
  const PaymentPreferenceScreen({super.key});

  @override
  ConsumerState<PaymentPreferenceScreen> createState() =>
      _PaymentPreferenceScreenState();
}

class _PaymentPreferenceScreenState
    extends ConsumerState<PaymentPreferenceScreen> {
  String _choice = 'none';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(currentProfileProvider).asData?.value;
      if (mounted && saved != null) {
        const allowed = {'none', 'cash', 'flexible'};
        setState(
          () => _choice = allowed.contains(saved.paymentPreference)
              ? saved.paymentPreference
              : 'none',
        );
      }
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile({
        'payment_preference': _choice,
      });
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'payment');
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/guardian');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Job payments',
          title: 'Payments are not handled by MORT',
          subtitle: 'This build does not collect payment handles, process money, hold escrow, guarantee payment, or charge a service fee.',
        ),
        const MortStepper(current: 7, total: 12),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'Do not enter a Cash App tag, Square link, card, bank account, or other payment credential in your profile, messages, proof, or support requests.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortPaymentDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Off-platform payment preference',
          value: _choice,
          items: const {
            'none': 'Decide with the other person later',
            'cash': 'Cash after completed work',
            'flexible': 'Flexible - no payment details stored',
          },
          onChanged: (value) => setState(() => _choice = value ?? 'none'),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save preference and continue',
          busyLabel: 'Saving preference...',
          busy: _busy,
          icon: Icons.arrow_forward,
          onPressed: _continue,
        ),
      ],
    );
  }
}

class SafetyRulesScreen extends ConsumerStatefulWidget {
  const SafetyRulesScreen({super.key});

  @override
  ConsumerState<SafetyRulesScreen> createState() => _SafetyRulesScreenState();
}

class _SafetyRulesScreenState extends ConsumerState<SafetyRulesScreen> {
  bool _busy = false;
  bool _pilotTermsNotice = false;
  bool _privacyNotice = false;
  bool _communityRules = false;
  bool _prohibitedWork = false;
  bool _safetyRules = false;
  bool _antiGroomingAcknowledged = false;
  final _signature = TextEditingController();

  bool get _allAcknowledged =>
      _pilotTermsNotice &&
      _privacyNotice &&
      _communityRules &&
      _prohibitedWork &&
      _safetyRules &&
      _antiGroomingAcknowledged;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) return;
    if (!_allAcknowledged) {
      MortToast.show(context, 'Review and check every safety notice first.');
      return;
    }
    if (!_backendReady) {
      MortToast.show(
        context,
        'MORT cannot connect right now. Try again later.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      // Record the exact-version, hash-bound legal acceptance first --
      // complete_my_onboarding() requires an active legal_acceptances row
      // for every legal_role_requirements match, and nothing in this flow
      // called that RPC before this fix.
      final legalRepo = ref.read(legalContractRepositoryProvider);
      final requirements =
          (await legalRepo.legalRequirements())['requirements'] as List? ??
          const [];
      final outstanding = requirements
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['acceptance_id'] == null)
          .toList(growable: false);
      final needsSignature = outstanding.any(
        (item) => item['requires_electronic_signature'] == true,
      );
      if (needsSignature && _signature.text.trim().length < 3) {
        setState(() => _busy = false);
        if (mounted) {
          MortToast.show(
            context,
            'Type your name to electronically sign the required document.',
          );
        }
        return;
      }
      for (final item in outstanding) {
        await legalRepo.acceptLegalVersion(
          versionId: item['version_id'].toString(),
          teenSummaryViewed: true,
          signature: item['requires_electronic_signature'] == true
              ? _signature.text
              : null,
        );
      }

      final package = await PackageInfo.fromPlatform();
      final platform = kIsWeb
          ? 'flutter_web'
          : 'flutter_${defaultTargetPlatform.name}';
      await ref
          .read(profileRepositoryProvider)
          .recordOnboardingAcknowledgement(
            version: mortOnboardingAcknowledgementVersion,
            platform: platform,
            appVersion: '${package.version}+${package.buildNumber}',
          );
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'safety');
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/review');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Safety',
          title: 'Review MORT safety rules',
          subtitle: 'These product and safety notices are required for MORT. They are not a substitute for published legal terms.',
        ),
        const MortStepper(current: 10, total: 12),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(),
        const SizedBox(height: MortSpacing.md),
        const FeatureChecklist(
          items: [
            'Identity verification is required for marketplace participation; Guardian Mode is still optional.',
            'Report, block, and Safety Ping stay free.',
            'Guardian Mode basics stay free.',
            'Boosts, badges, and premium perks never bypass safety review.',
            'If a job feels wrong, stop and report it before continuing.',
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortGlassCard(
          infoAccent: true,
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _pilotTermsNotice,
                title: const Text(MortRulesCopy.pilotTermsTitle),
                subtitle: const Text(MortRulesCopy.pilotTermsBody),
                onChanged: (value) =>
                    setState(() => _pilotTermsNotice = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _privacyNotice,
                title: const Text(MortRulesCopy.privacyTitle),
                subtitle: const Text(MortRulesCopy.privacyBody),
                onChanged: (value) =>
                    setState(() => _privacyNotice = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _communityRules,
                title: const Text(MortRulesCopy.communityTitle),
                subtitle: const Text(MortRulesCopy.communityBody),
                onChanged: (value) =>
                    setState(() => _communityRules = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _prohibitedWork,
                title: const Text(MortRulesCopy.prohibitedTitle),
                subtitle: const Text(MortRulesCopy.prohibitedBody),
                onChanged: (value) =>
                    setState(() => _prohibitedWork = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _safetyRules,
                title: const Text(MortRulesCopy.safetyRulesTitle),
                subtitle: const Text(MortRulesCopy.safetyRulesBody),
                onChanged: (value) =>
                    setState(() => _safetyRules = value ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gpp_bad_outlined, color: MortColors.danger),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(
                    child: Text(
                      MortRulesCopy.antiGroomingTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: MortColors.danger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.xs),
              SizedBox(
                height: 180,
                child: SingleChildScrollView(
                  child: Text(
                    MortRulesCopy.antiGroomingBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: MortSpacing.xs),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _antiGroomingAcknowledged,
                title: const Text(MortRulesCopy.antiGroomingAcceptLabel),
                subtitle: const Text(MortRulesCopy.antiGroomingAcceptSubtitle),
                onChanged: (value) =>
                    setState(() => _antiGroomingAcknowledged = value ?? false),
              ),
              const SizedBox(height: MortSpacing.xs),
              TextField(
                controller: _signature,
                decoration: const InputDecoration(
                  labelText:
                      'Signature (only if a document below requires one)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Terms notice',
              icon: Icons.article_outlined,
              onPressed: () => context.push('/legal/terms'),
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: 'Privacy notice',
              icon: Icons.privacy_tip_outlined,
              onPressed: () => context.push('/legal/privacy'),
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: 'Community rules',
              icon: Icons.groups_outlined,
              onPressed: () => context.push('/legal/community-rules'),
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: 'Teen safety',
              icon: Icons.health_and_safety_outlined,
              onPressed: () => context.push('/legal/teen-safety'),
              style: MortButtonStyle.ghost,
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save acknowledgments and review',
          busyLabel: 'Saving acknowledgments...',
          busy: _busy,
          icon: Icons.check_circle,
          onPressed: _allAcknowledged ? _finish : null,
        ),
      ],
    );
  }
}

class _OnboardingMomentumCard extends StatelessWidget {
  const _OnboardingMomentumCard({required this.progress});

  final OnboardingProgress progress;

  @override
  Widget build(BuildContext context) {
    final completed = progress.completedSteps
        .where((step) => step != 'complete')
        .length
        .clamp(0, 11);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(
            label: progress.isComplete
                ? 'Setup complete'
                : '$completed of 11 steps saved',
            color: MortColors.neon,
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(
            progress.isComplete
                ? 'Your saved setup passed the server checks. Marketplace access still depends on account and release restrictions.'
                : 'Your next saved step is ${progress.currentStep.replaceAll('_', ' ')}. You can safely resume after signing out or closing the app.',
          ),
        ],
      ),
    );
  }
}

class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final partnerContexts = role == UserRole.adult
        ? ref.watch(partnerStaffContextsProvider)
        : null;
    final hasPartnerWorkspace =
        partnerContexts?.asData?.value.isNotEmpty ?? false;
    final title = switch (role) {
      UserRole.teen => 'Teen home',
      UserRole.adult => 'Adult dashboard',
      UserRole.guardian => 'Guardian dashboard',
      UserRole.admin => 'Admin dashboard',
    };
    final actions = switch (role) {
      UserRole.teen => const [
        MortAction(
          label: 'Browse jobs',
          icon: Icons.search,
          route: '/teen/jobs',
        ),
        MortAction(
          label: 'Applications',
          icon: Icons.assignment,
          route: '/teen/applications',
        ),
        MortAction(
          label: 'Saved jobs',
          icon: Icons.bookmarks_outlined,
          route: '/teen/saved',
        ),
        MortAction(
          label: 'Profile',
          icon: Icons.person_outline,
          route: '/teen/profile',
        ),
        MortAction(
          label: 'Safety Ping',
          icon: Icons.shield,
          route: '/teen/safety',
        ),
        MortAction(label: 'Messages', icon: Icons.chat, route: '/messages'),
      ],
      UserRole.adult => [
        const MortAction(
          label: 'Post job',
          icon: Icons.add_business,
          route: '/adult/post-job',
        ),
        const MortAction(
          label: 'My jobs',
          icon: Icons.work,
          route: '/adult/jobs',
        ),
        const MortAction(
          label: 'Applicants',
          icon: Icons.groups,
          route: '/adult/applicants',
        ),
        const MortAction(
          label: 'Verification',
          icon: Icons.verified,
          route: '/adult/verification',
        ),
        if (hasPartnerWorkspace)
          const MortAction(
            label: 'Partner workspace',
            icon: Icons.account_balance_outlined,
            route: '/partner/home',
          ),
      ],
      UserRole.guardian => const [
        MortAction(
          label: 'Linked teens',
          icon: Icons.family_restroom,
          route: '/guardian/linked-teens',
        ),
        MortAction(
          label: 'Approvals',
          icon: Icons.fact_check,
          route: '/guardian/approvals',
        ),
        MortAction(
          label: 'Permissions',
          icon: Icons.tune,
          route: '/guardian/permissions',
        ),
        MortAction(
          label: 'Safety pings',
          icon: Icons.health_and_safety,
          route: '/guardian/safety-pings',
        ),
        MortAction(
          label: 'Activity',
          icon: Icons.history,
          route: '/guardian/activity',
        ),
      ],
      UserRole.admin => const [
        MortAction(
          label: 'Reports',
          icon: Icons.report,
          route: '/admin/reports',
        ),
        MortAction(
          label: 'Verifications',
          icon: Icons.verified_user,
          route: '/admin/verifications',
        ),
        MortAction(
          label: 'Restricted queues',
          icon: Icons.admin_panel_settings_outlined,
          route: '/admin/restricted-queues',
        ),
        MortAction(
          label: 'Incident cases',
          icon: Icons.folder_shared_outlined,
          route: '/admin/incidents',
        ),
        MortAction(
          label: 'Jobs',
          icon: Icons.work_history,
          route: '/admin/jobs',
        ),
        MortAction(
          label: 'Monetization',
          icon: Icons.payments,
          route: '/admin/monetization',
        ),
        MortAction(
          label: 'Payment operations',
          icon: Icons.account_balance_wallet_outlined,
          route: '/admin/payment-operations',
        ),
        MortAction(
          label: 'Operational alerts',
          icon: Icons.monitor_heart_outlined,
          route: '/admin/operational-alerts',
        ),
        MortAction(
          label: 'Reviews',
          icon: Icons.rate_review_outlined,
          route: '/admin/reviews',
        ),
        MortAction(
          label: 'Support',
          icon: Icons.support_agent,
          route: '/admin/support',
        ),
      ],
    };
    final dashboard = _roleDashboardDefinition(role, hasPartnerWorkspace);
    return MortScreen(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: MortBrandMark(size: 46),
        ),
        const SizedBox(height: MortSpacing.xs),
        MortGlassHeader(
          eyebrow: profile?.displayName ?? userRoleToString(role) ?? 'MORT',
          title: title,
          subtitle: 'Safety-first workflows and optional perks without paywalling core safety.',
          trailing: MortNotificationBell(
            onPressed: () => context.push('/notifications'),
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (role == UserRole.teen)
          MortProfileCompletionMeter(
            value: profile?.completionRatio ?? 0,
            items: [
              for (final item in profile?.completionChecklist ?? const [])
                (label: item.label, complete: item.complete),
            ],
            onTap: () => context.push('/teen/profile'),
          ),
        if (role == UserRole.adult) const MortVerificationDisclaimer(),
        if (role == UserRole.guardian) const MortGuardianBanner(),
        if (role == UserRole.admin)
          const MortSafetyBanner(
            message:
                'Admin tools are limited to authorized moderation accounts.',
          ),
        if (role == UserRole.adult || role == UserRole.admin) ...[
          const SizedBox(height: MortSpacing.md),
          _ReleaseModeCard(status: ref.watch(releaseModeStatusProvider)),
        ],
        const SizedBox(height: MortSpacing.lg),
        if (role == UserRole.teen) ...[
          const _TeenActiveJobSection(),
          const SizedBox(height: MortSpacing.md),
          const _TeenNearbyWorkSection(),
          const SizedBox(height: MortSpacing.md),
          MortSafetyPulse(
            title: 'Safety',
            status: 'Tap for the Safety Center, check-ins, and help.',
            onPressed: () => context.push('/teen/safety'),
          ),
          const SizedBox(height: MortSpacing.md),
          const _TeenLeaderboardSection(),
          const SizedBox(height: MortSpacing.md),
          MortSectionLabel(label: 'Quick links'),
          MortQuickActionGrid(actions: actions),
        ] else ...[
          MortGlassButton(
            label: dashboard.primary.label,
            icon: dashboard.primary.icon,
            primary: true,
            onPressed: () => context.push(dashboard.primary.route),
          ),
          for (final group in dashboard.groups) ...[
            MortSectionLabel(label: group.label),
            for (final action in group.actions) ...[
              MortDashboardActionTile(
                label: action.label,
                description: action.description,
                icon: action.icon,
                onPressed: () => context.push(action.route),
              ),
              const SizedBox(height: MortSpacing.sm),
            ],
          ],
        ],
        const SizedBox(height: MortSpacing.md),
        if (role == UserRole.teen || role == UserRole.adult)
          MortBannerAd(
            placement: role == UserRole.teen ? 'job_feed' : 'adult_dashboard',
          ),
      ],
    );
  }
}

class _TeenActiveJobSection extends ConsumerWidget {
  const _TeenActiveJobSection();

  static const _activeStatuses = ['in_progress', 'proof_submitted', 'accepted'];
  static const _pendingStatuses = [
    'submitted',
    'adult_review',
    'viewed',
    'guardian_pending',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);
    return applicationsAsync.when(
      loading: () => const MortSkeletonCard(),
      error: (_, _) => const SizedBox.shrink(),
      data: (applications) {
        MortApplication? featured;
        for (final status in [..._activeStatuses, ..._pendingStatuses]) {
          for (final app in applications) {
            if (app.status == status) {
              featured = app;
              break;
            }
          }
          if (featured != null) break;
        }
        if (featured == null) return const SizedBox.shrink();
        final job = featured.job;
        final isActive = _activeStatuses.contains(featured.status);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MortSectionLabel(label: isActive ? 'Active job' : 'Upcoming job'),
            MortDashboardActionTile(
              label: job?.title ?? 'Job details',
              description: job == null
                  ? _statusLabel(featured.status)
                  : '${_statusLabel(featured.status)} · ${job.city}, ${job.state}'
                        '${job.payAmountCents != null ? ' · ${formatCents(job.payAmountCents!)}' : ''}',
              icon: isActive
                  ? Icons.directions_run_rounded
                  : Icons.schedule_rounded,
              onPressed: () =>
                  context.push('/teen/applications/${featured!.id}'),
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(String status) => switch (status) {
    'in_progress' => 'In progress',
    'proof_submitted' => 'Proof submitted',
    'accepted' => 'Accepted — not started yet',
    'submitted' => 'Application submitted',
    'adult_review' => 'Waiting on poster review',
    'viewed' => 'Viewed by poster',
    'guardian_pending' => 'Waiting on guardian approval',
    _ => status,
  };
}

class _TeenNearbyWorkSection extends ConsumerWidget {
  const _TeenNearbyWorkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(
      openJobsProvider(const JobSearchFilters(limit: 3)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MortSectionLabel(label: 'Available nearby work'),
        feedAsync.when(
          loading: () => const MortSkeletonCard(),
          error: (_, _) => const SizedBox.shrink(),
          data: (state) {
            if (state.items.isEmpty) {
              return const MortEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No open jobs right now',
                message: 'Check back soon, or widen your search filters.',
              );
            }
            return Column(
              children: [
                for (final job in state.items) ...[
                  MortDashboardActionTile(
                    label: job.title,
                    description:
                        '${job.payAmountCents != null ? formatCents(job.payAmountCents!) : job.payLabel ?? 'Pay varies'}'
                        ' · ${job.city}, ${job.state} · ${job.category}',
                    icon: Icons.work_outline_rounded,
                    onPressed: () => context.push('/teen/jobs/${job.id}'),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        MortSecondaryButton(
          label: 'Browse all nearby jobs',
          onPressed: () => context.push('/teen/jobs'),
        ),
      ],
    );
  }
}

/// Podium coloring for the top 3 leaderboard ranks only -- rose gold and
/// silver, per MORT's brand (no yellow/gold). Every other rank stays on
/// the standard rose-gold accent.
Color _podiumColor(int rank) => switch (rank) {
  1 => MortColors.roseGold,
  2 => MortColors.silverBright,
  3 => MortColors.roseGoldDeep,
  _ => MortColors.roseGoldLight,
};

class _TeenLeaderboardSection extends ConsumerWidget {
  const _TeenLeaderboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRankAsync = ref.watch(myLeaderboardRankProvider);
    final boardAsync = ref.watch(leaderboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MortSectionLabel(label: 'Leaderboard'),
        myRankAsync.when(
          loading: () => const MortSkeletonCard(),
          error: (_, _) => const SizedBox.shrink(),
          data: (rank) => MortGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rank.tierLabel,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: MortColors.roseGoldLight),
                          ),
                          Text(
                            rank.completedCount == 0
                                ? 'Complete a job to join the leaderboard.'
                                : '${rank.completedCount} verified completed jobs'
                                      '${rank.reviewCount > 0 ? ' · ${rank.averageRating.toStringAsFixed(1)}★ avg' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (rank.rank > 0 && !rank.leaderboardOptOut)
                      Column(
                        children: [
                          Text(
                            '#${rank.rank}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Text('your rank'),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: MortSpacing.xs),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(leaderboardRepositoryProvider)
                          .setOptOut(!rank.leaderboardOptOut);
                      ref.invalidate(myLeaderboardRankProvider);
                      ref.invalidate(leaderboardProvider);
                      if (context.mounted) {
                        MortToast.show(
                          context,
                          rank.leaderboardOptOut
                              ? 'You are visible on the public leaderboard again.'
                              : 'You are hidden from the public leaderboard. Your own rank is still visible to you.',
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        MortToast.show(context, userFacingError(error));
                      }
                    }
                  },
                  child: Text(
                    rank.leaderboardOptOut
                        ? 'Show me on the public leaderboard'
                        : 'Hide me from the public leaderboard',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        boardAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (entries) {
            if (entries.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top community workers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.xs),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MortSpacing.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#${entry.rank}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: _podiumColor(entry.rank)),
                          ),
                        ),
                        MortAvatar(label: entry.displayName, radius: 16),
                        const SizedBox(width: MortSpacing.xs),
                        Expanded(
                          child: Text(
                            entry.displayName ?? 'MORT worker',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        MortStatusPill(
                          label: entry.tierLabel,
                          icon: Icons.military_tech_outlined,
                          color: _podiumColor(entry.rank),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardActionDefinition {
  const _DashboardActionDefinition({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
}

class _DashboardGroupDefinition {
  const _DashboardGroupDefinition({required this.label, required this.actions});

  final String label;
  final List<_DashboardActionDefinition> actions;
}

class _RoleDashboardDefinition {
  const _RoleDashboardDefinition({required this.primary, required this.groups});

  final _DashboardActionDefinition primary;
  final List<_DashboardGroupDefinition> groups;
}

_RoleDashboardDefinition _roleDashboardDefinition(
  UserRole role,
  bool hasPartnerWorkspace,
) => switch (role) {
  UserRole.teen => const _RoleDashboardDefinition(
    primary: _DashboardActionDefinition(
      label: 'Browse jobs',
      description: 'Find approved local work.',
      icon: Icons.search_rounded,
      route: '/teen/jobs',
    ),
    groups: [],
  ),
  UserRole.adult => _RoleDashboardDefinition(
    primary: const _DashboardActionDefinition(
      label: 'Post a job',
      description: 'Create and publish an age-appropriate local job.',
      icon: Icons.add_business_rounded,
      route: '/adult/post-job',
    ),
    groups: [
      const _DashboardGroupDefinition(
        label: 'Work',
        actions: [
          _DashboardActionDefinition(
            label: 'My jobs',
            description: 'Manage drafts, open listings, assignments, and completed work.',
            icon: Icons.work_outline_rounded,
            route: '/adult/jobs',
          ),
          _DashboardActionDefinition(
            label: 'Applicants',
            description:
                'Review real applications and protected lifecycle actions.',
            icon: Icons.groups_outlined,
            route: '/adult/applicants',
          ),
          _DashboardActionDefinition(
            label: 'Messages',
            description: 'Use scanner-protected job conversations.',
            icon: Icons.chat_bubble_outline_rounded,
            route: '/messages',
          ),
          _DashboardActionDefinition(
            label: 'Contracts and payment status',
            description:
                'Review agreements and the current fail-closed payment state.',
            icon: Icons.receipt_long_outlined,
            route: '/contracts',
          ),
        ],
      ),
      const _DashboardGroupDefinition(
        label: 'Business and account',
        actions: [
          _DashboardActionDefinition(
            label: 'Verification',
            description: 'Review the current internal verification state and requirements.',
            icon: Icons.verified_user_outlined,
            route: '/adult/verification',
          ),
          _DashboardActionDefinition(
            label: 'Business profile',
            description: 'Update public-safe poster and business information.',
            icon: Icons.storefront_outlined,
            route: '/adult/profile',
          ),
          _DashboardActionDefinition(
            label: 'Notifications',
            description: 'Review job, application, and security updates.',
            icon: Icons.notifications_outlined,
            route: '/notifications',
          ),
          _DashboardActionDefinition(
            label: 'Settings',
            description:
                'Manage privacy, security, account, and legal controls.',
            icon: Icons.settings_outlined,
            route: '/settings',
          ),
        ],
      ),
      _DashboardGroupDefinition(
        label: 'Safety and support',
        actions: [
          const _DashboardActionDefinition(
            label: 'Teen safety standards',
            description:
                'Review posting, communication, and prohibited-work rules.',
            icon: Icons.health_and_safety_outlined,
            route: '/legal/teen-safety',
          ),
          const _DashboardActionDefinition(
            label: 'Support',
            description: 'Open MORT Support or escalate a real account issue.',
            icon: Icons.support_agent_outlined,
            route: '/support',
          ),
          if (hasPartnerWorkspace)
            const _DashboardActionDefinition(
              label: 'Partner workspace',
              description: 'Manage authorized organization participants.',
              icon: Icons.account_balance_outlined,
              route: '/partner/home',
            ),
        ],
      ),
    ],
  ),
  UserRole.guardian => const _RoleDashboardDefinition(
    primary: _DashboardActionDefinition(
      label: 'Review approvals',
      description: 'Review linked-teen requests that require Guardian Mode.',
      icon: Icons.fact_check_outlined,
      route: '/guardian/approvals',
    ),
    groups: [
      _DashboardGroupDefinition(
        label: 'Linked teen safety',
        actions: [
          _DashboardActionDefinition(
            label: 'Linked teens',
            description: 'Manage optional, consent-based Guardian Mode links.',
            icon: Icons.family_restroom_outlined,
            route: '/guardian/linked-teens',
          ),
          _DashboardActionDefinition(
            label: 'Permissions',
            description:
                'Control authorized alerts without opening private messages.',
            icon: Icons.tune_rounded,
            route: '/guardian/permissions',
          ),
          _DashboardActionDefinition(
            label: 'Safety Pings',
            description: 'View only pings shared through an active link.',
            icon: Icons.health_and_safety_outlined,
            route: '/guardian/safety-pings',
          ),
          _DashboardActionDefinition(
            label: 'Activity',
            description: 'Review permitted linked-account safety activity.',
            icon: Icons.history_rounded,
            route: '/guardian/activity',
          ),
        ],
      ),
      _DashboardGroupDefinition(
        label: 'Privacy and account',
        actions: [
          _DashboardActionDefinition(
            label: 'Guardian Mode settings',
            description:
                'Review link status, privacy boundaries, and unlinking.',
            icon: Icons.shield_outlined,
            route: '/settings/guardian-mode',
          ),
          _DashboardActionDefinition(
            label: 'Privacy',
            description: 'Review data visibility and location protections.',
            icon: Icons.privacy_tip_outlined,
            route: '/settings/privacy',
          ),
          _DashboardActionDefinition(
            label: 'Notifications',
            description: 'Review enabled safety and account updates.',
            icon: Icons.notifications_outlined,
            route: '/notifications',
          ),
          _DashboardActionDefinition(
            label: 'Settings',
            description: 'Manage security, legal, and account controls.',
            icon: Icons.settings_outlined,
            route: '/settings',
          ),
          _DashboardActionDefinition(
            label: 'Support',
            description: 'Ask for help without claiming 24/7 staffing.',
            icon: Icons.support_agent_outlined,
            route: '/support',
          ),
        ],
      ),
    ],
  ),
  UserRole.admin => const _RoleDashboardDefinition(
    primary: _DashboardActionDefinition(
      label: 'Review reports',
      description: 'Open the authorized report moderation queue.',
      icon: Icons.report_outlined,
      route: '/admin/reports',
    ),
    groups: [
      _DashboardGroupDefinition(
        label: 'Moderation',
        actions: [
          _DashboardActionDefinition(
            label: 'Restricted queues',
            description: 'Open scoped high-sensitivity moderation queues.',
            icon: Icons.admin_panel_settings_outlined,
            route: '/admin/restricted-queues',
          ),
          _DashboardActionDefinition(
            label: 'Incident cases',
            description: 'Review restricted safety incidents and assignments.',
            icon: Icons.folder_shared_outlined,
            route: '/admin/incidents',
          ),
          _DashboardActionDefinition(
            label: 'Verifications',
            description:
                'Review internal verification state and evidence gates.',
            icon: Icons.verified_user_outlined,
            route: '/admin/verifications',
          ),
          _DashboardActionDefinition(
            label: 'Jobs',
            description:
                'Moderate marketplace listings under server authority.',
            icon: Icons.work_history_outlined,
            route: '/admin/jobs',
          ),
          _DashboardActionDefinition(
            label: 'Reviews',
            description: 'Moderate reputation content and reported reviews.',
            icon: Icons.rate_review_outlined,
            route: '/admin/reviews',
          ),
          _DashboardActionDefinition(
            label: 'Users',
            description: 'Open authorized account controls and restrictions.',
            icon: Icons.manage_accounts_outlined,
            route: '/admin/users',
          ),
        ],
      ),
      _DashboardGroupDefinition(
        label: 'Operations',
        actions: [
          _DashboardActionDefinition(
            label: 'Message moderation',
            description: 'Review only messages exposed by moderation policy.',
            icon: Icons.forum_outlined,
            route: '/admin/messages',
          ),
          _DashboardActionDefinition(
            label: 'Safety Pings',
            description: 'Review authorized urgent safety cases and state.',
            icon: Icons.health_and_safety_outlined,
            route: '/admin/safety-pings',
          ),
          _DashboardActionDefinition(
            label: 'Support',
            description: 'Manage support tickets, assignment, and escalation.',
            icon: Icons.support_agent_outlined,
            route: '/admin/support',
          ),
          _DashboardActionDefinition(
            label: 'Operational alerts',
            description: 'Review backend and provider health alerts.',
            icon: Icons.monitor_heart_outlined,
            route: '/admin/operational-alerts',
          ),
          _DashboardActionDefinition(
            label: 'Payment operations',
            description: 'Review fail-closed payment operation records.',
            icon: Icons.account_balance_wallet_outlined,
            route: '/admin/payment-operations',
          ),
        ],
      ),
      _DashboardGroupDefinition(
        label: 'Governance',
        actions: [
          _DashboardActionDefinition(
            label: 'Audit logs',
            description: 'Review server-recorded administrative actions.',
            icon: Icons.history_edu_outlined,
            route: '/admin/action-logs',
          ),
          _DashboardActionDefinition(
            label: 'Marketplace and monetization gates',
            description: 'Review current server-controlled release gates.',
            icon: Icons.toggle_on_outlined,
            route: '/admin/monetization',
          ),
          _DashboardActionDefinition(
            label: 'Account trust',
            description: 'Open multi-signal trust and appeal operations.',
            icon: Icons.policy_outlined,
            route: '/admin/account-trust',
          ),
          _DashboardActionDefinition(
            label: 'Settings',
            description: 'Review this account, legal material, and security.',
            icon: Icons.settings_outlined,
            route: '/settings',
          ),
        ],
      ),
    ],
  ),
};

class JobFeedScreen extends ConsumerStatefulWidget {
  const JobFeedScreen({super.key});

  @override
  ConsumerState<JobFeedScreen> createState() => _JobFeedScreenState();
}

class _JobFeedScreenState extends ConsumerState<JobFeedScreen> {
  String _category = 'All';
  static const _categories = [
    'All',
    'dog walking',
    'pet sitting',
    'yard cleanup',
    'tutoring',
    'car washing',
    'tech help',
    'errands',
  ];

  @override
  Widget build(BuildContext context) {
    if (!_backendReady) return const SetupRequiredScreen();
    final future = ref
        .watch(jobsRepositoryProvider)
        .listOpenJobs(category: _category);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Teen-safe feed',
          title: 'Nearby jobs',
          subtitle: 'General area only. Use reports and Safety Ping if anything feels off.',
        ),
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            for (final category in _categories)
              MortCategoryPill(
                label: category,
                selected: _category == category,
                onTap: () => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Job>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                children: [
                  MortSkeletonCard(),
                  SizedBox(height: MortSpacing.sm),
                  MortSkeletonCard(),
                ],
              );
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Job feed error',
                message: userFacingError(snapshot.error),
              );
            }
            final jobs = snapshot.data ?? const [];
            if (jobs.isEmpty) {
              return const MortEmptyState(
                title: 'No open jobs yet',
                message: 'Try another category or check back soon.',
              );
            }
            return Column(
              children: [
                for (final job in jobs) ...[
                  _JobCard(job: job),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const MortAdBannerSlot(placement: 'job_feed'),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      onTap: () => context.go('/teen/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              MortJobStatusBadge(status: job.status),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            '${job.payDisplay} · ${job.locationText}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.xs,
            children: [
              MortBadge(label: job.category),
              MortTrustBadge(
                label: job.posterVerified
                    ? 'Verified poster'
                    : 'Verification visible',
                verified: job.posterVerified,
              ),
              if (job.requiresGuardianApproval)
                const MortBadge(
                  label: 'Guardian approval',
                  color: MortColors.safetyBlue,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_busy) return;
    if (_note.text.trim().length > 500) {
      MortToast.show(context, 'Keep the proposal under 500 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .applyToJob(widget.jobId, note: _note.text.trim());
      if (mounted) context.go('/teen/applications');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_backendReady) return const SetupRequiredScreen();
    return FutureBuilder<Job?>(
      future: ref.watch(jobsRepositoryProvider).getJob(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const MortLoading();
        if (snapshot.hasError)
          return MortErrorStateScreen(
            title: 'Job detail error',
            message: userFacingError(snapshot.error),
          );
        final job = snapshot.data;
        if (job == null) {
          return const MortErrorStateScreen(
            title: 'Job unavailable',
            message: 'This job was removed or is no longer visible.',
          );
        }
        return MortScreen(
          children: [
            MortHeader(
              eyebrow: job.category,
              title: job.title,
              subtitle: '${job.payDisplay} · ${job.locationText}',
            ),
            MortCard(
              child: Text(
                job.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: MortSpacing.md),
            Wrap(
              spacing: MortSpacing.xs,
              runSpacing: MortSpacing.xs,
              children: [
                MortTrustBadge(
                  label: job.posterVerified
                      ? 'Verified poster'
                      : 'Verification not approved',
                  verified: job.posterVerified,
                ),
                if (job.requiresGuardianApproval)
                  const MortBadge(
                    label: 'Guardian approval required',
                    color: MortColors.safetyBlue,
                  ),
                MortBadge(label: 'Starts ${formatDateTime(job.startsAt)}'),
              ],
            ),
            const SizedBox(height: MortSpacing.md),
            const MortPaymentDisclaimer(),
            const SizedBox(height: MortSpacing.md),
            MortTextArea(
              label: 'Proposal note',
              controller: _note,
              hint: 'Share safe availability, no private contact info.',
              maxLength: 500,
            ),
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: 'Apply',
                  icon: Icons.send,
                  onPressed: _apply,
                  busy: _busy,
                  busyLabel: 'Applying...',
                  style: MortButtonStyle.primary,
                ),
                const MortAction(
                  label: 'Save job',
                  icon: Icons.bookmark,
                  enabled: false,
                ),
                MortAction(
                  label: 'Report job',
                  icon: Icons.report,
                  route: '/report/job/${job.id}',
                  style: MortButtonStyle.danger,
                ),
                MortAction(
                  label: 'Block poster',
                  icon: Icons.block,
                  route: '/block/user/${job.posterId}',
                  style: MortButtonStyle.danger,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({
    super.key,
    this.adultReview = false,
    this.guardianReview = false,
  });

  final bool adultReview;
  final bool guardianReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_backendReady) return const SetupRequiredScreen();
    final future = adultReview
        ? ref.watch(applicationsRepositoryProvider).listApplicationsForMyJobs()
        : ref.watch(applicationsRepositoryProvider).listMyApplications();
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: adultReview
              ? 'Adult review'
              : guardianReview
              ? 'Guardian approval'
              : 'Teen tracker',
          title: adultReview
              ? 'Applicants'
              : guardianReview
              ? 'Approval requests'
              : 'Applications',
          subtitle: adultReview
              ? 'Accept, reject, and review proof for jobs you manage.'
              : guardianReview
              ? 'Approve only linked-teen applications. Basic approvals stay free.'
              : 'Track guardian approval, adult review, proof, and completion.',
        ),
        FutureBuilder<List<MortApplication>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Applications error',
                message: userFacingError(snapshot.error),
              );
            final apps = snapshot.data ?? const [];
            if (apps.isEmpty)
              return const MortEmptyState(
                title: 'Nothing here yet',
                message: 'Applications will appear after a teen applies or an adult posts jobs.',
              );
            return Column(
              children: [
                for (final app in apps) ...[
                  _ApplicationCard(
                    application: app,
                    adultReview: adultReview,
                    guardianReview: guardianReview,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({
    required this.application,
    required this.adultReview,
    required this.guardianReview,
  });

  final MortApplication application;
  final bool adultReview;
  final bool guardianReview;

  Future<void> _status(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .updateStatus(application.id, status);
      if (context.mounted)
        MortToast.show(context, 'Application marked $status.');
    } catch (error) {
      if (context.mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            application.job?.title ?? 'Application',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          MortBadge(
            label: application.status,
            color: application.status == 'accepted'
                ? MortColors.neon
                : MortColors.safetyBlue,
          ),
          if (application.note != null) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(
              application.note!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: adultReview
                ? [
                    MortAction(
                      label: 'Accept',
                      icon: Icons.check,
                      onPressed: () => _status(context, ref, 'accepted'),
                    ),
                    MortAction(
                      label: 'Reject',
                      icon: Icons.close,
                      onPressed: () => _status(context, ref, 'rejected'),
                      style: MortButtonStyle.danger,
                    ),
                  ]
                : guardianReview
                ? application.status == 'guardian_pending'
                      ? [
                          MortAction(
                            label: 'Approve',
                            icon: Icons.check,
                            onPressed: () =>
                                _status(context, ref, 'adult_review'),
                          ),
                          MortAction(
                            label: 'Reject',
                            icon: Icons.close,
                            onPressed: () =>
                                _status(context, ref, 'guardian_rejected'),
                            style: MortButtonStyle.danger,
                          ),
                        ]
                      : const [
                          MortAction(
                            label: 'Decision recorded',
                            icon: Icons.verified,
                            enabled: false,
                          ),
                        ]
                : [
                    MortAction(
                      label: 'Upload proof',
                      icon: Icons.upload,
                      route: '/teen/proof/${application.id}',
                    ),
                    const MortAction(
                      label: 'Message',
                      icon: Icons.chat,
                      route: '/messages',
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'general help');
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pay = TextEditingController();
  bool _guardianApproval = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _area.dispose();
    _city.dispose();
    _state.dispose();
    _pay.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (!_form.currentState!.validate() || _busy) return;
    final unsafe = MortValidators.teenSafeJobText(
      '${_title.text}\n${_description.text}',
    );
    if (unsafe != null) {
      MortToast.show(context, unsafe);
      return;
    }
    setState(() => _busy = true);
    try {
      final cents = MortServiceFee.tryParseAdultAmount(_pay.text);
      await ref
          .read(jobsRepositoryProvider)
          .createJob(
            title: _title.text,
            description: _description.text,
            category: _category.text,
            locationText: _area.text,
            city: _city.text,
            state: _state.text,
            adultJobAmountCents: cents,
            requiresGuardianApproval: _guardianApproval,
          );
      if (mounted) context.go('/adult/jobs');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Post safely',
          title: 'Create a teen-safe job',
          subtitle: 'No hazardous work, no private contact pressure, no exact-location sharing in chat.',
        ),
        const MortVerificationDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        Form(
          key: _form,
          child: Column(
            children: [
              MortTextField(
                label: 'Title',
                controller: _title,
                maxLength: 100,
                validator: (value) =>
                    MortValidators.requiredText(value, maximumLength: 100),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextArea(
                label: 'Description',
                controller: _description,
                maxLength: 2000,
                validator: (value) => MortValidators.requiredText(
                  value,
                  message: 'Add at least 20 characters of detail.',
                  minimumLength: 20,
                  maximumLength: 2000,
                ),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Category',
                controller: _category,
                validator: (value) =>
                    MortValidators.requiredText(value, maximumLength: 80),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'General area',
                controller: _area,
                validator: (value) =>
                    MortValidators.requiredText(value, maximumLength: 120),
              ),
              const SizedBox(height: MortSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MortTextField(
                      label: 'City',
                      controller: _city,
                      validator: (value) => MortValidators.requiredText(
                        value,
                        maximumLength: 120,
                      ),
                    ),
                  ),
                  const SizedBox(width: MortSpacing.sm),
                  SizedBox(
                    width: 110,
                    child: MortTextField(
                      label: 'State',
                      controller: _state,
                      maxLength: 2,
                      validator: MortValidators.stateCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Pay amount dollars',
                controller: _pay,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: MortServiceFee.validateAdultAmount,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _guardianApproval,
                title: const Text('Require guardian approval'),
                subtitle: const Text('Recommended for teen work.'),
                onChanged: (value) => setState(() => _guardianApproval = value),
              ),
              const SizedBox(height: MortSpacing.md),
              const MortPaymentDisclaimer(),
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: 'Publish job',
                busyLabel: 'Publishing...',
                busy: _busy,
                icon: Icons.publish,
                onPressed: _post,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProofUploadScreen extends ConsumerStatefulWidget {
  const ProofUploadScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<ProofUploadScreen> createState() => _ProofUploadScreenState();
}

class _ProofUploadScreenState extends ConsumerState<ProofUploadScreen> {
  final _picker = ImagePicker();
  final _note = TextEditingController();
  PreparedProofImage? _proof;
  String? _fileName;
  String? _submissionId;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _choose(ImageSource source) async {
    if (_busy) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final repository = ref.read(uploadsRepositoryProvider);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final prepared = UploadsRepository.prepareProof(bytes);
      setState(() {
        _proof = prepared;
        _fileName = file.name;
        _submissionId = repository.newProofSubmissionId();
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _submit() async {
    final proof = _proof;
    final submissionId = _submissionId;
    if (_busy || proof == null || submissionId == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(uploadsRepositoryProvider)
          .uploadProof(
            applicationId: widget.applicationId,
            submissionId: submissionId,
            proof: proof,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      MortToast.show(context, 'Proof submitted for review.');
      context.go('/teen/applications');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proof = _proof;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private storage',
          title: 'Upload proof',
          subtitle: 'Choose one clear completion photo. MORT re-encodes it as a private JPEG before upload.',
        ),
        const MortSafetyBanner(
          message: 'Proof should show job completion only. Do not upload private IDs, exact addresses, or unrelated people.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proof == null ? 'Choose completion photo' : 'Proof preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MortSpacing.sm),
              if (proof == null)
                const Text(
                  'JPEG, PNG, and WebP are supported. Source images must be under 10 MB.',
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(
                      proof.bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  '${_fileName ?? 'Selected photo'} - ${_formatBytes(proof.bytes)} after privacy processing',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: MortSpacing.md),
              MortActionRow(
                actions: [
                  MortAction(
                    label: proof == null ? 'Choose photo' : 'Replace photo',
                    icon: Icons.photo_library_outlined,
                    busy: _busy,
                    onPressed: () => _choose(ImageSource.gallery),
                  ),
                  if (!kIsWeb)
                    MortAction(
                      label: 'Take photo',
                      icon: Icons.photo_camera_outlined,
                      busy: _busy,
                      onPressed: () => _choose(ImageSource.camera),
                    ),
                ],
              ),
              if (kIsWeb) ...[
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Browser photo selection is available here. Native camera and permission behavior require Android or iPhone device testing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MortTextArea(
                label: 'Optional note',
                hint: 'Briefly explain what the photo shows.',
                controller: _note,
                maxLength: 500,
              ),
              const SizedBox(height: MortSpacing.sm),
              const Text(
                'The adult who posted the job and safety admins can review submitted proof. Attached proof cannot be deleted by the uploader.',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Submit proof',
          busyLabel: 'Submitting proof...',
          busy: _busy,
          icon: Icons.cloud_upload_outlined,
          onPressed: proof == null ? null : _submit,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Back to applications',
          icon: Icons.assignment_outlined,
          style: MortButtonStyle.ghost,
          onPressed: _busy ? null : () => context.go('/teen/applications'),
        ),
      ],
    );
  }

  static String _formatBytes(Uint8List bytes) {
    if (bytes.length >= 1024 * 1024) {
      return '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes.length / 1024).ceil()} KB';
  }
}

class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Adult/business trust',
          title: 'Verification',
          subtitle: 'Business checks will use an approved provider workflow. Verification does not guarantee another user or job.',
          trailing: MortBadge(
            label: (profile?.verificationStatus ?? 'not_started').replaceAll(
              '_',
              ' ',
            ),
            color: profile?.verificationStatus == 'approved'
                ? MortColors.neon
                : MortColors.warning,
          ),
        ),
        const MortSafetyBanner(
          message: 'Do not upload an ID, tax document, bank record, or business document to MORT. New submissions are closed until provider, privacy, legal, and reviewer controls are approved.',
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline),
            title: Text('Provider workflow not connected'),
            subtitle: Text(
              'Existing request history remains visible, but MORT is not accepting or approving new business evidence.',
            ),
          ),
        ),
        const MortSectionTitle(title: 'Request history'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: ref
              .watch(uploadsRepositoryProvider)
              .listMyVerificationRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Verification history unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return const MortEmptyState(
                title: 'No verification requests',
                message: 'Your private request history will appear here.',
              );
            }
            return MortCard(
              child: Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(row['business_name'].toString()),
                      subtitle: Text(
                        '${row['business_type'].toString().replaceAll('_', ' ')} - ${row['status'].toString()}',
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _search = TextEditingController();
  final List<MessageThread> _threads = [];
  MessageThreadPageCursor? _nextCursor;
  Object? _loadError;
  String _activeQuery = '';
  bool _initialLoading = true;
  bool _loadingMore = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final int generation;
    final String query;
    final MessageThreadPageCursor? cursor;
    if (reset) {
      generation = ++_loadGeneration;
      query = _search.text.trim();
      cursor = null;
      setState(() {
        _initialLoading = true;
        _loadingMore = false;
        _loadError = null;
        _activeQuery = query;
      });
    } else {
      if (_nextCursor == null || _loadingMore) return;
      generation = _loadGeneration;
      query = _activeQuery;
      cursor = _nextCursor;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref
          .read(messagingRepositoryProvider)
          .listThreadsPage(query: query, cursor: cursor);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        if (reset) _threads.clear();
        final knownIds = _threads.map((thread) => thread.id).toSet();
        _threads.addAll(page.items.where((thread) => knownIds.add(thread.id)));
        _nextCursor = page.nextCursor;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loadError = error);
      if (!reset && _threads.isNotEmpty) {
        MortToast.show(context, userFacingError(error));
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _initialLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _reload() {
    if (_initialLoading) return;
    unawaited(_load(reset: true));
  }

  void _clearSearch() {
    _search.clear();
    _reload();
  }

  Widget _threadCard(
    BuildContext context,
    MessageThread thread, {
    required bool inTeenShell,
  }) {
    final name = thread.counterpartyDisplayName?.trim();
    final displayName = name?.isNotEmpty == true ? name! : 'MORT participant';
    final avatarLabel = displayName.characters.first.toUpperCase();
    final jobTitle = thread.jobTitle?.trim();
    final preview = thread.lastMessagePreview?.trim();
    return MortCard(
      onTap: () => context.push(
        '${inTeenShell ? '/teen/messages' : '/messages'}/${thread.id}',
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortAvatar(label: avatarLabel),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (jobTitle?.isNotEmpty == true)
                  Text(
                    jobTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: MortColors.lightBlue),
                  ),
                if (preview?.isNotEmpty == true) ...[
                  const SizedBox(height: MortSpacing.xxs),
                  Text(
                    preview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: MortSpacing.xs),
                Wrap(
                  spacing: MortSpacing.xs,
                  runSpacing: MortSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MortStatusPill(
                      label: thread.lifecycleStatus == 'active'
                          ? 'Protected'
                          : 'Read only',
                      icon: Icons.shield_outlined,
                      color: thread.lifecycleStatus == 'active'
                          ? MortColors.lightBlue
                          : MortColors.silver,
                    ),
                    Text(
                      formatDateTime(thread.lastMessageAt ?? thread.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (thread.unreadCount > 0) ...[
            const SizedBox(width: MortSpacing.xs),
            MortBadge(
              label: thread.unreadCount > 99
                  ? '99+ unread'
                  : '${thread.unreadCount} unread',
              color: MortColors.warning,
            ),
          ],
          const SizedBox(width: MortSpacing.xxs),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(supabaseReadyProvider)) {
      return const SetupRequiredScreen();
    }
    final inTeenShell = TeenNavigationScope.maybeOf(context) != null;
    final header = inTeenShell
        ? MortTeenDestinationHeader(
            eyebrow: 'Protected chat',
            title: 'Messages',
            subtitle:
                'No ads in chat. Messages pass through MORT safety checks.',
            trailing: MortIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh conversations',
              onPressed: _reload,
            ),
          )
        : MortHeader(
            eyebrow: 'Safety scanner',
            title: 'Messages',
            subtitle:
                'No ads in chat. Messages pass through MORT safety checks.',
            trailing: MortIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh conversations',
              onPressed: _reload,
            ),
          );
    return MortScreen(
      children: [
        header,
        if (inTeenShell) const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message: 'Protected chat blocks unsafe contact sharing and keeps report tools close by.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortSearchField(
          controller: _search,
          hint: 'Search by participant or job',
          onSubmitted: (_) => _reload(),
        ),
        const SizedBox(height: MortSpacing.sm),
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            MortGlassButton(
              label: 'Search conversations',
              icon: Icons.search_rounded,
              primary: true,
              onPressed: _initialLoading ? null : _reload,
            ),
            if (_activeQuery.isNotEmpty)
              MortGlassButton(
                label: 'Clear search',
                icon: Icons.clear_rounded,
                onPressed: _initialLoading ? null : _clearSearch,
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        if (_initialLoading)
          const MortSkeletonCard()
        else if (_loadError != null && _threads.isEmpty)
          MortErrorState(
            title: 'Messages unavailable',
            message: userFacingError(_loadError),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _reload,
            ),
          )
        else if (_threads.isEmpty)
          MortEmptyState(
            title: _activeQuery.isEmpty
                ? 'No conversations yet'
                : 'No matching conversations',
            message: _activeQuery.isEmpty
                ? 'A protected thread appears when a job application creates one.'
                : 'Try a different participant or job name.',
          )
        else ...[
          for (final thread in _threads) ...[
            _threadCard(context, thread, inTeenShell: inTeenShell),
            const SizedBox(height: MortSpacing.sm),
          ],
          if (_nextCursor != null)
            MortGlassButton(
              label: 'Load more conversations',
              icon: Icons.expand_more_rounded,
              onPressed: _loadingMore
                  ? null
                  : () => unawaited(_load(reset: false)),
            ),
          if (_loadingMore)
            const MortLoading(
              label: 'Loading conversations',
              fullScreen: false,
            ),
        ],
      ],
    );
  }
}

class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  final _body = TextEditingController();
  final _scrollController = ScrollController();
  final List<MortMessage> _messages = [];
  MessagePageCursor? _nextCursor;
  MortMessageSubscription? _subscription;
  Timer? _markReadDebounce;
  MessageThread? _thread;
  Object? _loadError;
  String? _sendError;
  String _lifecycleStatus = 'active';
  String? _pendingSendId;
  String? _pendingBody;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool _markReadInFlight = false;
  bool _markReadQueued = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _markReadDebounce?.cancel();
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _scrollController.dispose();
    _body.dispose();
    super.dispose();
  }

  void _subscribe() {
    final repository = ref.read(messagingRepositoryProvider);
    _subscription = repository.subscribeToMessages(widget.threadId, (message) {
      if (!mounted) return;
      _mergeMessages([message], scrollToLatest: true);
      _scheduleMarkRead();
    });
  }

  void _scheduleMarkRead({Duration delay = const Duration(milliseconds: 250)}) {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(delay, () => unawaited(_markRead()));
  }

  Future<void> _markRead() async {
    if (_markReadInFlight) {
      _markReadQueued = true;
      return;
    }
    _markReadInFlight = true;
    do {
      _markReadQueued = false;
      try {
        await ref
            .read(messagingRepositoryProvider)
            .markThreadRead(widget.threadId);
      } catch (error) {
        if (mounted) MortToast.show(context, userFacingError(error));
      }
    } while (mounted && _markReadQueued);
    _markReadInFlight = false;
  }

  static int _compareMessages(MortMessage left, MortMessage right) {
    final time = (left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    return time != 0 ? time : left.id.compareTo(right.id);
  }

  int _messageInsertionIndex(MortMessage message) {
    var low = 0;
    var high = _messages.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_compareMessages(_messages[middle], message) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  void _mergeMessages(
    Iterable<MortMessage> incoming, {
    bool scrollToLatest = false,
  }) {
    final incomingMessages = incoming.toList(growable: false);
    if (incomingMessages.isEmpty) return;
    if (incomingMessages.length == 1) {
      final message = incomingMessages.single;
      setState(() {
        final existingIndex = _messages.indexWhere(
          (existing) => existing.id == message.id,
        );
        if (existingIndex >= 0) {
          _messages.removeAt(existingIndex);
        }
        _messages.insert(_messageInsertionIndex(message), message);
      });
      if (scrollToLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showLatest());
      }
      return;
    }
    final byId = <String, MortMessage>{
      for (final message in _messages) message.id: message,
      for (final message in incomingMessages) message.id: message,
    };
    final merged = byId.values.toList()..sort(_compareMessages);
    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
    });
    if (scrollToLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLatest());
    }
  }

  void _showLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: MortMotion.standard,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _loadInitial() async {
    if (mounted) {
      setState(() {
        _initialLoading = true;
        _loadError = null;
      });
    }
    try {
      final repository = ref.read(messagingRepositoryProvider);
      final page = await repository.listMessagesPage(widget.threadId);
      if (!mounted) return;
      setState(() {
        _nextCursor = page.nextCursor;
        _lifecycleStatus = page.lifecycleStatus;
        _thread = page.thread;
      });
      _mergeMessages(page.items, scrollToLatest: true);
      _scheduleMarkRead(delay: Duration.zero);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(messagingRepositoryProvider)
          .listMessagesPage(widget.threadId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _nextCursor = page.nextCursor;
        _lifecycleStatus = page.lifecycleStatus;
      });
      _mergeMessages(page.items);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _reload() => unawaited(_loadInitial());

  Future<void> _send() async {
    final messageBody = _body.text.trim();
    if (messageBody.isEmpty || _busy || _lifecycleStatus != 'active') return;
    if (messageBody.length > 2000) {
      MortToast.show(context, 'Keep messages under 2,000 characters.');
      return;
    }
    if (_pendingBody != messageBody || _pendingSendId == null) {
      _pendingBody = messageBody;
      _pendingSendId = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _sendError = null;
    });
    try {
      final saved = await ref
          .read(messagingRepositoryProvider)
          .sendSafeMessage(
            widget.threadId,
            messageBody,
            clientRequestId: _pendingSendId,
          );
      if (!mounted) return;
      _mergeMessages([saved], scrollToLatest: true);
      _body.clear();
      _pendingBody = null;
      _pendingSendId = null;
      if (mounted) MortToast.show(context, 'Message sent through scanner.');
    } catch (error) {
      if (mounted) {
        setState(() => _sendError = userFacingError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.id;
    final currentRole = ref.watch(currentProfileProvider).asData?.value?.role;
    final thread = _thread;
    final counterpartyName = thread?.counterpartyDisplayName?.trim();
    final jobTitle = thread?.jobTitle?.trim();
    return MortScreen(
      scrollController: _scrollController,
      children: [
        MortHeader(
          eyebrow: 'Keep chat in MORT',
          title: counterpartyName?.isNotEmpty == true
              ? counterpartyName!
              : 'Protected conversation',
          subtitle: jobTitle?.isNotEmpty == true ? 'Job: $jobTitle' : 'Phone numbers, social handles, exact addresses, and off-platform pressure can be blocked.',
        ),
        const MortSafetyBanner(
          message: 'Use quick replies and report anything unsafe. No ads appear in messages.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (thread != null) ...[
          MortGlassCard(
            infoAccent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: MortSpacing.xs,
                  runSpacing: MortSpacing.xs,
                  children: [
                    const MortStatusPill(
                      label: 'Protected chat',
                      icon: Icons.shield_outlined,
                      color: MortColors.lightBlue,
                    ),
                    if (thread.counterpartyRole?.isNotEmpty == true)
                      MortBadge(
                        label: thread.counterpartyRole!.replaceAll('_', ' '),
                      ),
                    if (thread.counterpartyVerificationStatus?.isNotEmpty ==
                        true)
                      MortBadge(
                        label:
                            'Verification: ${thread.counterpartyVerificationStatus!.replaceAll('_', ' ')}',
                        color: MortColors.silver,
                      ),
                  ],
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Only job participants can open this thread. Guardian Mode does not grant unrestricted message access.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: MortSpacing.sm),
                Wrap(
                  spacing: MortSpacing.xs,
                  runSpacing: MortSpacing.xs,
                  children: [
                    if (thread.jobId?.isNotEmpty == true &&
                        (currentRole == UserRole.teen ||
                            currentRole == UserRole.adult))
                      MortGlassButton(
                        label: 'Job details',
                        icon: Icons.work_outline_rounded,
                        onPressed: () => context.push(
                          currentRole == UserRole.teen
                              ? '/teen/jobs/${thread.jobId}'
                              : '/adult/jobs/${thread.jobId}',
                        ),
                      ),
                    if (thread.counterpartyId?.isNotEmpty == true) ...[
                      MortGlassButton(
                        label: 'Report participant',
                        icon: Icons.report_outlined,
                        onPressed: () => context.push(
                          '/report/user/${thread.counterpartyId}',
                        ),
                      ),
                      MortGlassButton(
                        label: 'Block participant',
                        icon: Icons.block_outlined,
                        danger: true,
                        onPressed: () => context.push(
                          '/block/user/${thread.counterpartyId}',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        if (_initialLoading)
          const MortSkeletonCard()
        else if (_loadError != null)
          MortErrorState(
            title: 'Thread error',
            message: userFacingError(_loadError),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _reload,
            ),
          )
        else ...[
          if (_nextCursor != null) ...[
            MortButton(
              label: 'Load earlier messages',
              icon: Icons.history,
              onPressed: _loadMore,
              busy: _loadingMore,
              busyLabel: 'Loading...',
              style: MortButtonStyle.secondary,
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
          if (_messages.isEmpty)
            const MortEmptyState(
              title: 'No messages yet',
              message: 'Start with a safe, on-platform note.',
            ),
          for (final message in _messages) ...[
            Align(
              alignment: message.senderId == currentUserId
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.84,
                child: MortGlassCard(
                  color: message.blocked
                      ? MortColors.danger.withValues(alpha: 0.1)
                      : message.senderId == currentUserId
                      ? MortColors.roseGoldDeep.withValues(alpha: 0.34)
                      : MortColors.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The safety-scanner badge only earns its place on a
                      // bubble when it actually flagged or blocked
                      // something -- showing it on every clean message
                      // both clutters the thread and dilutes the signal
                      // for the messages that genuinely need attention.
                      if (message.blocked || message.flagged) ...[
                        Row(
                          children: [
                            MortBadge(
                              label: message.scannerStatus,
                              icon: message.blocked
                                  ? Icons.block_rounded
                                  : Icons.shield_outlined,
                              color: message.blocked
                                  ? MortColors.danger
                                  : MortColors.warning,
                            ),
                            const Spacer(),
                            Text(
                              formatDateTime(message.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: MortSpacing.xs),
                      ],
                      Text(
                        message.blocked ? 'Blocked by scanner' : message.body,
                      ),
                      if (!message.blocked && !message.flagged) ...[
                        const SizedBox(height: MortSpacing.xxs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatDateTime(message.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: MortColors.textMuted),
                          ),
                        ),
                      ],
                      if (message.scannerReason != null) ...[
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          message.scannerReason!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (message.senderId != currentUserId) ...[
                        const SizedBox(height: MortSpacing.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () =>
                                context.go('/report/message/${message.id}'),
                            icon: const Icon(Icons.report_outlined),
                            label: const Text('Report'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
        ],
        if (_lifecycleStatus != 'active') ...[
          const MortSafetyBanner(
            message: 'This job conversation is read-only. Use the structured dispute or Support flow for any next step.',
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            for (final reply in const [
              'I am available.',
              'Thanks, I will review this.',
              'Can we confirm the schedule?',
            ])
              MortFilterChip(
                label: reply,
                selected: _body.text == reply,
                onSelected: _lifecycleStatus == 'active'
                    ? (_) => setState(() {
                        _body.text = reply;
                        _sendError = null;
                      })
                    : null,
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Message',
          controller: _body,
          maxLines: 3,
          maxLength: 2000,
          enabled: _lifecycleStatus == 'active',
          onChanged: (value) {
            if (_sendError != null && value.trim() != _pendingBody) {
              setState(() => _sendError = null);
            }
          },
        ),
        const SizedBox(height: MortSpacing.sm),
        if (_sendError != null) ...[
          MortErrorState(
            title: 'Message not sent',
            message: _sendError!,
            action: MortButton(
              label: 'Retry send',
              icon: Icons.refresh_rounded,
              onPressed: _busy ? null : _send,
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        MortActionRow(
          actions: [
            MortAction(
              label: 'Send message',
              icon: Icons.send,
              onPressed: _lifecycleStatus == 'active' ? _send : null,
              busy: _busy,
              busyLabel: 'Sending...',
              style: MortButtonStyle.primary,
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        const MortGlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: MortColors.silver),
              SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Text(
                  'Job chat is text-only by design. Use the job proof flow for completion evidence or Support for authorized case evidence.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SafetyCenterScreen extends ConsumerStatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  ConsumerState<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    super.key,
    this.targetUserId,
    this.targetJobId,
    this.targetMessageId,
    this.targetReviewId,
  });

  final String? targetUserId;
  final String? targetJobId;
  final String? targetMessageId;
  final String? targetReviewId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _details = TextEditingController();
  String _reason = 'unsafe_job';
  bool _busy = false;
  bool _submitted = false;
  bool _immediateDanger = false;
  String? _requestId;
  String? _requestPayload;
  Map<String, dynamic>? _result;

  String _stableRequestId() {
    final payload = '$_reason|$_immediateDanger|${_details.text.trim()}';
    if (_requestId == null || _requestPayload != payload) {
      _requestId = const Uuid().v4();
      _requestPayload = payload;
    }
    return _requestId!;
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_details.text.trim().length < 10) {
      MortToast.show(context, 'Add at least 10 characters of useful detail.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(safetyRepositoryProvider)
          .createReport(
            targetUserId: widget.targetUserId,
            targetJobId: widget.targetJobId,
            targetMessageId: widget.targetMessageId,
            targetReviewId: widget.targetReviewId,
            reason: _reason,
            details: _details.text.trim(),
            immediateDanger: _immediateDanger,
            clientRequestId: _stableRequestId(),
          );
      if (mounted) {
        setState(() {
          _result = result;
          _submitted = true;
        });
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return MortScreen(
        children: [
          const MortHeader(
            eyebrow: 'Report received',
            title: 'Thanks for speaking up',
            subtitle: 'MORT records the report for moderation. Immediate danger still requires local emergency services.',
          ),
          if (_result?['report_id'] != null) ...[
            MortCard(
              child: Text(
                'Case reference: ${_result!['report_id']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: MortSpacing.md),
          ],
          if (_immediateDanger) ...[
            const MortSafetyBanner(
              message: 'MORT created an urgent human-review case but did not dispatch physical help. Contact local emergency services now.',
            ),
            const SizedBox(height: MortSpacing.md),
          ],
          MortButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/account-status'),
          ),
        ],
      );
    }

    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Free safety tool',
          title: 'Send a report',
          subtitle: 'Reports are reviewed without blaming the reporter. MORT is not an emergency service.',
        ),
        const MortSafetyBanner(
          message: 'For immediate danger, contact local emergency services and a trusted adult.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Reason',
          value: _reason,
          items: const {
            'unsafe_job': 'Unsafe or prohibited job',
            'scam': 'Scam or upfront fee',
            'contact_sharing': 'Off-platform contact pressure',
            'harassment': 'Harassment',
            'threats': 'Threats or coercion',
            'stalking': 'Stalking or repeated contact',
            'sexual_content': 'Sexual content',
            'grooming_exploitation': 'Grooming or exploitation concern',
            'private_images': 'Private or inappropriate images',
            'weapons_substances': 'Weapons, substances, or dangerous tools',
            'other': 'Other',
          },
          onChanged: (value) => setState(() {
            _reason = value ?? 'other';
            _requestId = null;
          }),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'What happened?',
          controller: _details,
          maxLines: 5,
          maxLength: 1000,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _immediateDanger,
          title: const Text('Someone may be in immediate danger'),
          subtitle: const Text(
            'This prioritizes human review. MORT cannot dispatch emergency help.',
          ),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  _immediateDanger = value ?? false;
                  _requestId = null;
                }),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Submit report',
          busyLabel: 'Submitting...',
          busy: _busy,
          icon: Icons.report,
          style: MortButtonStyle.danger,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class BlockUserScreen extends ConsumerStatefulWidget {
  const BlockUserScreen({super.key, required this.targetUserId});

  final String? targetUserId;

  @override
  ConsumerState<BlockUserScreen> createState() => _BlockUserScreenState();
}

class _BlockUserScreenState extends ConsumerState<BlockUserScreen> {
  bool _busy = false;
  bool _blocked = false;

  Future<void> _block() async {
    final targetId = widget.targetUserId;
    if (_busy || targetId == null || targetId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(safetyRepositoryProvider).blockUser(targetId);
      if (mounted) setState(() => _blocked = true);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Free safety tool',
          title: _blocked ? 'User blocked' : 'Block this user?',
          subtitle: _blocked
              ? 'The block is active across messaging and account interactions.'
              : 'Blocking limits normal interaction. You can still submit a separate report for moderation.',
        ),
        if (_blocked)
          MortButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: () => context.go('/account-status'),
          )
        else ...[
          const MortSafetyBanner(
            message: 'Blocking does not contact emergency services. Report urgent safety concerns too.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Block user',
            busyLabel: 'Blocking...',
            busy: _busy,
            icon: Icons.block,
            style: MortButtonStyle.danger,
            onPressed: _block,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Cancel',
            style: MortButtonStyle.ghost,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/account-status'),
          ),
        ],
      ],
    );
  }
}

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(safetyRepositoryProvider).listBlockedUsers();
      if (mounted)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _unblock(String blockedId) async {
    if (_busyId != null) return;
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Unblock this account?',
      message: 'Normal MORT interactions may become available again.',
      confirmLabel: 'Unblock',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = blockedId);
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(blockedId);
      await _load();
      if (mounted) MortToast.show(context, 'Account unblocked.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Privacy and safety',
          title: 'Blocked accounts',
          subtitle: 'Blocking limits normal interaction. Reports and preserved safety evidence remain separate.',
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_rows.isEmpty)
          const MortEmptyState(
            title: 'No blocked accounts',
            message: 'Accounts you block will appear here.',
            icon: Icons.block,
          )
        else
          ..._rows.map((row) {
            final blockedId = row['blocked_id']?.toString() ?? '';
            final shortId = blockedId.length > 8
                ? blockedId.substring(blockedId.length - 8)
                : blockedId;
            return Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.sm),
              child: MortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blocked account ...$shortId',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    Text('Blocked ${formatDateTime(row['created_at'])}'),
                    const SizedBox(height: MortSpacing.sm),
                    MortButton(
                      label: 'Unblock',
                      icon: Icons.lock_open,
                      style: MortButtonStyle.secondary,
                      busy: _busyId == blockedId,
                      onPressed: _busyId == null
                          ? () => _unblock(blockedId)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SafetyCenterScreenState extends ConsumerState<SafetyCenterScreen> {
  final _note = TextEditingController();
  bool _busy = false;
  bool _loading = true;
  bool _immediateDanger = false;
  String? _loadError;
  Map<String, dynamic>? _config;
  List<Map<String, dynamic>> _checkins = const [];
  String? _selectedJobId = '';
  String? _pingRequestId;
  String? _pingPayload;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_loading || _loadError != null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final repository = ref.read(safetyRepositoryProvider);
      final values = await Future.wait<dynamic>([
        repository.getSafetyCenterConfig(),
        repository.listActiveJobCheckins(),
      ]);
      if (!mounted) return;
      final checkins = List<Map<String, dynamic>>.from(values[1] as List);
      setState(() {
        _config = Map<String, dynamic>.from(values[0] as Map);
        _checkins = checkins;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = userFacingError(error);
        _loading = false;
      });
    }
  }

  String _stablePingRequestId() {
    final payload = '${_note.text.trim()}|$_selectedJobId|$_immediateDanger';
    if (_pingRequestId == null || _pingPayload != payload) {
      _pingRequestId = const Uuid().v4();
      _pingPayload = payload;
    }
    return _pingRequestId!;
  }

  Future<void> _callEmergencyServices() async {
    final rawUri = _config?['emergency_phone_uri']?.toString();
    final uri = rawUri?.isNotEmpty == true
        ? Uri.tryParse(rawUri!)
        : Uri(scheme: 'tel', path: '911');
    if (uri == null || !await launchUrl(uri)) {
      if (mounted) {
        MortToast.show(context, 'Open your Phone app and call 911.');
      }
    }
  }

  Future<void> _confirmEmergencyCall() async {
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Open the emergency dialer?',
      message: 'Use this only for immediate danger. MORT will open the Phone app with 911 ready, but will not place the call for you.',
      confirmLabel: 'Open dialer',
    );
    if (confirmed && mounted) await _callEmergencyServices();
  }

  Future<void> _ping() async {
    if (_busy) return;
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Send Safety Ping?',
      message: 'This alerts enabled Guardian or Safety Circle contacts and authorized safety staff where configured. MORT does not dispatch physical help.',
      confirmLabel: 'Send Safety Ping',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(safetyRepositoryProvider)
          .createSafetyPing(
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            jobId: _selectedJobId?.isNotEmpty == true ? _selectedJobId : null,
            immediateDanger: _immediateDanger,
            clientRequestId: _stablePingRequestId(),
          );
      if (mounted) {
        MortToast.show(
          context,
          result['immediate_danger'] == true
              ? 'Urgent review case created. MORT did not dispatch physical help.'
              : 'Safety Ping created.',
        );
        setState(() => _pingRequestId = null);
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeCheckin(String checkinId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .completeActiveJobCheckin(checkinId: checkinId);
      if (mounted) MortToast.show(context, 'Check-in completed.');
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scheduleCheckin(String applicationId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .scheduleActiveJobCheckin(
            applicationId: applicationId,
            minutesFromNow: 60,
          );
      if (mounted)
        MortToast.show(context, 'Next check-in scheduled for 60 minutes.');
      await _load();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inTeenShell = TeenNavigationScope.maybeOf(context) != null;
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isTeen = profile?.role == UserRole.teen;
    final currentCheckin = _checkins.isEmpty ? null : _checkins.first;
    final activeJobs = <String, String>{'': 'Do not attach an active job'};
    for (final checkin in _checkins) {
      final jobId = checkin['job_id']?.toString();
      if (jobId != null && jobId.isNotEmpty) {
        activeJobs[jobId] = checkin['job_title']?.toString() ?? 'Active job';
      }
    }
    final header = inTeenShell
        ? MortTeenDestinationHeader(
            eyebrow: 'Free safety tools',
            title: 'Safety',
            subtitle: 'Check in, reach trusted support, or send a Safety Ping without a paywall.',
            trailing: MortIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh Safety Center',
              onPressed: _loading ? null : _load,
            ),
          )
        : const MortHeader(
            eyebrow: 'Safety Center',
            title: 'Get help inside MORT',
            subtitle: 'Safety Ping is not an emergency service. Call local emergency services for immediate danger.',
          );
    return MortScreen(
      children: [
        header,
        if (inTeenShell) const SizedBox(height: MortSpacing.md),
        MortSafetyBanner(
          message: _config?['emergency_guidance']?.toString() ?? 'Report, block, and Safety Ping stay free. Contact local emergency services for immediate danger.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_loadError != null) ...[
          MortErrorState(
            title: 'Safety status unavailable',
            message: 'MORT could not refresh active check-ins. Emergency calling, reporting, and support remain available.',
            action: MortButton(
              label: 'Retry safety status',
              icon: Icons.refresh_rounded,
              style: MortButtonStyle.secondary,
              onPressed: _loading ? null : _load,
            ),
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        MortSafetyPulse(
          title: isTeen && currentCheckin != null
              ? 'I am okay'
              : 'Safety ready',
          status: _loadError != null
              ? 'Active check-in status needs a refresh'
              : _loading
              ? 'Loading active check-ins'
              : !isTeen
              ? 'Emergency, report, and support tools are available'
              : currentCheckin == null
              ? 'No active job check-in'
              : 'Due ${formatDateTime(currentCheckin['expected_at'])}',
          icon: !isTeen || currentCheckin == null
              ? Icons.shield_rounded
              : Icons.touch_app_rounded,
          onPressed: !isTeen || currentCheckin == null || _busy
              ? null
              : () => _completeCheckin(currentCheckin['checkin_id'].toString()),
        ),
        const MortSectionLabel(label: 'Immediate help'),
        // Call 911 stands alone as the one unmissable action -- everything
        // else here is a lower-urgency tool and reads that way now,
        // instead of five identically-weighted stacked buttons.
        MortButton(
          label: 'Call 911',
          icon: Icons.call,
          style: MortButtonStyle.danger,
          onPressed: _confirmEmergencyCall,
        ),
        const SizedBox(height: MortSpacing.md),
        MortQuickActionGrid(
          actions: [
            MortAction(
              label: 'Urgent support',
              icon: Icons.support_agent,
              onPressed: () => context.push('/support/chat'),
            ),
            MortAction(
              label: 'Report a concern',
              icon: Icons.report_outlined,
              onPressed: () => context.push('/report'),
            ),
            MortAction(
              label: 'Safety Circle',
              icon: Icons.group_outlined,
              onPressed: () => context.push('/settings/safety-circle'),
            ),
            MortAction(
              label: 'Case history',
              icon: Icons.folder_shared_outlined,
              onPressed: () => context.push('/settings/safety-cases'),
            ),
          ],
        ),
        if (isTeen && _checkins.isNotEmpty) ...[
          const SizedBox(height: MortSpacing.lg),
          const MortSectionTitle(title: 'Active job check-ins'),
          ..._checkins.map(
            (checkin) => Padding(
              padding: const EdgeInsets.only(top: MortSpacing.sm),
              child: MortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkin['job_title']?.toString() ?? 'Active job',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    Text(
                      '${titleCase(checkin['status']?.toString() ?? 'pending')} - due ${formatDateTime(checkin['expected_at'])}',
                    ),
                    const SizedBox(height: MortSpacing.sm),
                    MortActionRow(
                      actions: [
                        MortAction(
                          label: 'I am okay',
                          icon: Icons.check_circle_outline,
                          onPressed: _busy
                              ? null
                              : () => _completeCheckin(
                                  checkin['checkin_id'].toString(),
                                ),
                        ),
                        MortAction(
                          label: 'Add 60-minute check-in',
                          icon: Icons.add_alarm,
                          onPressed: _busy
                              ? null
                              : () => _scheduleCheckin(
                                  checkin['application_id'].toString(),
                                ),
                        ),
                        MortAction(
                          label: 'Open job safety',
                          icon: Icons.health_and_safety_outlined,
                          onPressed: () => context.push(
                            '/teen/safety/applications/${checkin['application_id']}',
                          ),
                        ),
                        MortAction(
                          label: 'Message',
                          icon: Icons.chat_outlined,
                          onPressed: () => context.push('/messages'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortDropdown<String>(
            label: 'Attach Safety Ping to job (optional)',
            value: _selectedJobId,
            items: activeJobs,
            onChanged: _busy
                ? (_) {}
                : (value) => setState(() {
                    _selectedJobId = value ?? '';
                    _pingRequestId = null;
                  }),
          ),
        ],
        if (isTeen) ...[
          const SizedBox(height: MortSpacing.lg),
          MortTextArea(
            label: 'Optional Safety Ping note',
            controller: _note,
            maxLines: 3,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _immediateDanger,
            title: const Text('Someone may be in immediate danger'),
            subtitle: const Text(
              'Creates an urgent restricted case. MORT cannot dispatch help.',
            ),
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _immediateDanger = value ?? false;
                    _pingRequestId = null;
                  }),
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: _immediateDanger ? 'Send urgent Safety Ping' : 'Safety Ping',
            busyLabel: 'Sending Safety Ping...',
            busy: _busy,
            icon: Icons.health_and_safety,
            style: MortButtonStyle.danger,
            onPressed: _ping,
          ),
        ] else ...[
          const SizedBox(height: MortSpacing.md),
          const MortEmptyState(
            title: 'Safety Ping is for Teen accounts',
            message: 'Adults, Guardians, and staff can still call emergency services, report concerns, contact Support, and use role-authorized safety tools.',
            icon: Icons.shield_outlined,
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        const FeatureChecklist(
          items: [
            'Guardian Mode is optional and shares only enabled safety alerts.',
            'No exact address in chat.',
            'No unsafe tools or late-night jobs.',
            'No off-platform pressure.',
            'No upfront fees.',
          ],
        ),
      ],
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_backendReady) return const SetupRequiredScreen();
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Push queue',
          title: 'Notifications',
          subtitle: 'Review account and job activity in one place. Device alerts require notification permission.',
          trailing: MortIconButton(
            icon: Icons.done_all,
            tooltip: 'Mark all read',
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(currentProfileProvider);
              if (context.mounted)
                MortToast.show(context, 'Notifications marked read.');
            },
          ),
        ),
        FutureBuilder(
          future: ref.watch(notificationsRepositoryProvider).listMine(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Notifications error',
                message: userFacingError(snapshot.error),
              );
            final items = snapshot.data ?? const [];
            if (items.isEmpty)
              return const MortEmptyState(
                title: 'No notifications',
                message:
                    'Safety, approval, message, and proof updates appear here.',
              );
            return Column(
              children: [
                for (final item in items) ...[
                  MortCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text(item.body),
                      trailing: item.isUnread
                          ? IconButton(
                              icon: const Icon(Icons.mark_email_read),
                              onPressed: () async {
                                await ref
                                    .read(notificationsRepositoryProvider)
                                    .markRead(item.id);
                                if (context.mounted)
                                  MortToast.show(context, 'Marked read.');
                              },
                            )
                          : const MortBadge(label: 'read'),
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

enum AdminSensitiveQueueAction { none, incident }

enum AdminModerationQueueAction { none, rejectJob, approveReview }

class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({
    super.key,
    required this.title,
    required this.table,
    this.subtitle,
    this.statusField = 'status',
    this.moderationAction = AdminModerationQueueAction.none,
    this.equals = const {},
    this.notEquals = const {},
    this.orFilter,
    this.sensitiveAction = AdminSensitiveQueueAction.none,
    this.detailRoutePrefix,
  });

  final String title;
  final String table;
  final String? subtitle;
  final String statusField;
  final AdminModerationQueueAction moderationAction;
  final Map<String, String> equals;
  final Map<String, String> notEquals;
  final String? orFilter;
  final AdminSensitiveQueueAction sensitiveAction;
  final String? detailRoutePrefix;

  @override
  ConsumerState<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends ConsumerState<AdminQueueScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref
        .read(adminRepositoryProvider)
        .queue(
          widget.table,
          equals: widget.equals,
          notEquals: widget.notEquals,
          orFilter: widget.orFilter,
        );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Admin',
          title: widget.title,
          subtitle:
              widget.subtitle ??
              'Only authorized moderation accounts can access this queue.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh ${widget.title}',
            onPressed: _reload,
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: '${widget.title} error',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return MortEmptyState(
                title: 'No ${widget.title} records',
                message: 'The queue is empty or unavailable to this account.',
              );
            }
            return Column(
              children: [
                for (final row in rows.take(30)) ...[
                  _AdminRowCard(
                    table: widget.table,
                    row: row,
                    statusField: widget.statusField,
                    moderationAction: widget.moderationAction,
                    sensitiveAction: widget.sensitiveAction,
                    detailRoutePrefix: widget.detailRoutePrefix,
                    onUpdated: _reload,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdminBanAppealsScreen extends ConsumerStatefulWidget {
  const AdminBanAppealsScreen({super.key});

  @override
  ConsumerState<AdminBanAppealsScreen> createState() =>
      _AdminBanAppealsScreenState();
}

class _AdminBanAppealsScreenState extends ConsumerState<AdminBanAppealsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _busyAppealId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(adminRepositoryProvider).banAppeals();

  void _reload() => setState(() => _future = _load());

  Future<String?> _reason(String title) async {
    final controller = TextEditingController();
    String? error;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: 'Required internal reason',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final result = controller.text.trim();
                if (result.length < 10) {
                  setDialogState(() => error = 'Enter at least 10 characters.');
                  return;
                }
                Navigator.pop(dialogContext, result);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _claim(String appealId) async {
    final reason = await _reason('Claim this appeal for two hours?');
    if (reason == null || !mounted) return;
    setState(() => _busyAppealId = appealId);
    try {
      await ref
          .read(adminRepositoryProvider)
          .claimBanAppeal(appealId: appealId, reason: reason);
      if (!mounted) return;
      MortToast.show(context, 'Appeal assigned with a two-hour expiry.');
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyAppealId = null);
    }
  }

  Future<void> _review(String appealId, String decision) async {
    final reason = await _reason(
      decision == 'approve' ? 'Reverse this account ban?' : 'Deny this appeal?',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyAppealId = appealId);
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewBanAppeal(
            appealId: appealId,
            decision: decision,
            reason: reason,
          );
      if (!mounted) return;
      MortToast.show(context, 'The independent appeal decision was recorded.');
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyAppealId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Independent review',
          title: 'Account ban appeals',
          subtitle: 'A reviewer cannot reverse their own enforcement. Claims expire after two hours and every action is audited.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh account ban appeals',
            onPressed: _reload,
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Ban appeal queue unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final appeals = snapshot.data ?? const [];
            if (appeals.isEmpty) {
              return const MortEmptyState(
                title: 'No open ban appeals',
                message: 'No submitted or assigned appeals are visible.',
              );
            }
            return Column(
              children: [
                for (final appeal in appeals) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Appeal ${appeal['id']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            MortBadge(label: '${appeal['status']}'),
                          ],
                        ),
                        const SizedBox(height: MortSpacing.sm),
                        Text('${appeal['reason']}'),
                        const SizedBox(height: MortSpacing.sm),
                        Text('Submitted: ${appeal['created_at']}'),
                        Text('Appeal expires: ${appeal['expires_at']}'),
                        if (appeal['assignment_expires_at'] != null)
                          Text(
                            'Assignment expires: ${appeal['assignment_expires_at']}',
                          ),
                        const SizedBox(height: MortSpacing.md),
                        if (appeal['status'] == 'submitted')
                          MortButton(
                            label: 'Claim appeal',
                            icon: Icons.assignment_ind_outlined,
                            busy: _busyAppealId == appeal['id'],
                            onPressed: _busyAppealId == null
                                ? () => _claim('${appeal['id']}')
                                : null,
                          )
                        else
                          MortActionRow(
                            actions: [
                              MortAction(
                                label: 'Approve reversal',
                                icon: Icons.restore,
                                busy: _busyAppealId == appeal['id'],
                                onPressed: _busyAppealId == null
                                    ? () =>
                                          _review('${appeal['id']}', 'approve')
                                    : null,
                              ),
                              MortAction(
                                label: 'Deny appeal',
                                icon: Icons.block,
                                busy: _busyAppealId == appeal['id'],
                                onPressed: _busyAppealId == null
                                    ? () => _review('${appeal['id']}', 'deny')
                                    : null,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdminRowCard extends ConsumerStatefulWidget {
  const _AdminRowCard({
    required this.table,
    required this.row,
    required this.statusField,
    required this.moderationAction,
    required this.sensitiveAction,
    required this.detailRoutePrefix,
    required this.onUpdated,
  });

  final String table;
  final Map<String, dynamic> row;
  final String statusField;
  final AdminModerationQueueAction moderationAction;
  final AdminSensitiveQueueAction sensitiveAction;
  final String? detailRoutePrefix;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AdminRowCard> createState() => _AdminRowCardState();
}

class _AdminRowCardState extends ConsumerState<_AdminRowCard> {
  bool _busy = false;

  List<String> get _reasonCodes => switch (widget.moderationAction) {
    AdminModerationQueueAction.rejectJob => const [
      'prohibited_job',
      'scam_fraud',
      'unsafe_contact',
      'harassment',
      'child_safety',
      'duplicate_spam',
      'policy_violation',
    ],
    AdminModerationQueueAction.approveReview => const [
      'content_review_completed',
      'harassment',
      'sexual_content',
      'personal_information',
      'threats',
      'scam_fraud',
      'discrimination',
      'retaliation',
      'policy_violation',
    ],
    AdminModerationQueueAction.none => const [],
  };

  String get _actionLabel => switch (widget.moderationAction) {
    AdminModerationQueueAction.rejectJob => 'Reject job',
    AdminModerationQueueAction.approveReview => 'Approve review',
    AdminModerationQueueAction.none => 'Update',
  };

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<({String reasonCode, String note})?> _moderationDecision() async {
    final noteController = TextEditingController();
    var selectedReason = _reasonCodes.isEmpty ? null : _reasonCodes.first;
    String? error;
    final result = await showDialog<({String reasonCode, String note})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$_actionLabel?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Reason code'),
                items: [
                  for (final code in _reasonCodes)
                    DropdownMenuItem(value: code, child: Text(titleCase(code))),
                ],
                onChanged: (value) => selectedReason = value,
              ),
              const SizedBox(height: MortSpacing.sm),
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Internal decision note',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final note = noteController.text.trim();
                if (selectedReason == null || note.length < 10) {
                  setDialogState(
                    () => error =
                        'Select a reason and enter at least 10 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, (
                  reasonCode: selectedReason!,
                  note: note,
                ));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    return result;
  }

  Future<void> _update(String id) async {
    if (_busy || widget.moderationAction == AdminModerationQueueAction.none) {
      return;
    }
    final decision = await _moderationDecision();
    if (decision == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(adminRepositoryProvider);
      switch (widget.moderationAction) {
        case AdminModerationQueueAction.rejectJob:
          await repository.moderateJob(
            jobId: id,
            action: 'reject',
            reasonCode: decision.reasonCode,
            note: decision.note,
          );
        case AdminModerationQueueAction.approveReview:
          await repository.moderateReview(
            reviewId: id,
            action: 'approve',
            reasonCode: decision.reasonCode,
            note: decision.note,
          );
        case AdminModerationQueueAction.none:
          return;
      }
      if (!mounted) return;
      MortToast.show(context, '$_actionLabel completed.');
      widget.onUpdated();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateIncident(String id, String status) async {
    if (_busy) return;
    final publicNote = switch (status) {
      'triage' => 'A restricted safety reviewer began triage.',
      'investigating' =>
        'The safety team is reviewing the available information.',
      _ => 'The current safety review is resolved. Appeal options remain available where applicable.',
    };
    final confirmed = await _confirm(
      'Update restricted incident?',
      'This audited action changes the participant-visible case status. It does not publish allegations or raw evidence.',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateIncident(
            incidentId: id,
            status: status,
            publicNote: publicNote,
          );
      if (!mounted) return;
      MortToast.show(context, 'Incident status updated.');
      widget.onUpdated();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.row['id']?.toString();
    final summary = widget.row.entries
        .where(
          (entry) => [
            'title',
            'reason',
            'business_name',
            'subject',
            'event_type',
            'action',
          ].contains(entry.key),
        )
        .map((entry) => '${titleCase(entry.key)}: ${entry.value}')
        .join(' · ');
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.isEmpty ? '${widget.table} record' : summary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          MortBadge(label: '${widget.row[widget.statusField] ?? 'queued'}'),
          if (id != null && widget.detailRoutePrefix != null) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: 'Open authorized detail',
                  icon: Icons.open_in_new,
                  onPressed: () =>
                      context.push('${widget.detailRoutePrefix}/$id'),
                ),
              ],
            ),
          ] else if (id != null &&
              widget.sensitiveAction == AdminSensitiveQueueAction.incident) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: 'Begin triage',
                  icon: Icons.rule_folder_outlined,
                  busy: _busy,
                  onPressed: () => _updateIncident(id, 'triage'),
                ),
                MortAction(
                  label: 'Investigate',
                  icon: Icons.manage_search,
                  busy: _busy,
                  onPressed: () => _updateIncident(id, 'investigating'),
                ),
                MortAction(
                  label: 'Resolve',
                  icon: Icons.task_alt,
                  busy: _busy,
                  onPressed: () => _updateIncident(id, 'resolved'),
                ),
              ],
            ),
          ] else if (id != null &&
              widget.moderationAction != AdminModerationQueueAction.none) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: _actionLabel,
                  icon: Icons.check,
                  busy: _busy,
                  onPressed: () => _update(id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class GuardianConnectionsScreen extends ConsumerWidget {
  const GuardianConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Guardian Mode',
          title: 'Linked teens',
          subtitle: 'Create, review, and revoke Guardian Mode links securely.',
        ),
        MortButton(
          label: 'Create teen invite',
          icon: Icons.qr_code,
          onPressed: () async {
            try {
              final result = await ref
                  .read(guardianRepositoryProvider)
                  .createInvite();
              if (context.mounted)
                MortToast.show(
                  context,
                  'Invite: ${result['invite_code'] ?? 'created'}',
                );
            } catch (error) {
              if (context.mounted) {
                MortToast.show(context, userFacingError(error));
              }
            }
          },
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: ref.watch(guardianRepositoryProvider).listConnections(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Guardian links error',
                message: userFacingError(snapshot.error),
              );
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty)
              return const MortEmptyState(
                title: 'No linked teens',
                message: 'Create or accept an invite to link accounts.',
              );
            return Column(
              children: [
                for (final row in rows) ...[
                  MortCard(
                    child: Text(
                      'Status: ${row['status']} · Invite: ${row['invite_code']}',
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class UsernameSettingsScreen extends ConsumerStatefulWidget {
  const UsernameSettingsScreen({super.key});

  @override
  ConsumerState<UsernameSettingsScreen> createState() =>
      _UsernameSettingsScreenState();
}

class _UsernameSettingsScreenState
    extends ConsumerState<UsernameSettingsScreen> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final result = await ref
          .read(profileRepositoryProvider)
          .requestUsernameChange(_username.text.trim());
      if (mounted)
        MortToast.show(
          context,
          result['message']?.toString() ?? 'Username request complete.',
        );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Username',
          title: 'Change username',
          subtitle: 'Three free lifetime changes, then Plus allowance, token, or admin credit.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _backendReady
              ? ref.watch(profileRepositoryProvider).getUsernameChangeStatus()
              : null,
          builder: (context, snapshot) {
            if (!_backendReady) return const _BackendStatusCard();
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Username status error',
                message: userFacingError(snapshot.error),
              );
            final status = snapshot.data ?? const {};
            return MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free changes used: ${status['free_changes_used'] ?? 0}/3',
                  ),
                  Text('Token credits: ${status['token_credits'] ?? 0}'),
                  Text('Allowed now: ${status['can_change'] ?? false}'),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortTextField(label: 'New username', controller: _username),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Save username',
              icon: Icons.save,
              onPressed: _save,
            ),
            const MortAction(
              label: 'Buy username token',
              icon: Icons.token,
              route: '/monetization/username-change',
            ),
          ],
        ),
      ],
    );
  }
}

class AdPreferencesScreen extends ConsumerStatefulWidget {
  const AdPreferencesScreen({super.key});

  @override
  ConsumerState<AdPreferencesScreen> createState() =>
      _AdPreferencesScreenState();
}

class _AdPreferencesScreenState extends ConsumerState<AdPreferencesScreen> {
  bool _personalized = false;
  bool _consentReady = false;
  bool _ageRestricted = true;

  Future<void> _save() async {
    try {
      await ref
          .read(monetizationRepositoryProvider)
          .saveAdPreferences(
            personalizedAdsAllowed: _personalized,
            adsConsentReady: _consentReady,
            ageRestrictedAds: _ageRestricted,
          );
      if (mounted) MortToast.show(context, 'Ad preferences saved.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Ads',
          title: 'Ad preferences',
          subtitle:
              'Teen-safe conservative ad handling. Ads are off by default.',
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _personalized,
          title: const Text('Personalized ads allowed'),
          onChanged: (value) => setState(() => _personalized = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _consentReady,
          title: const Text('Consent prompt complete'),
          onChanged: (value) => setState(() => _consentReady = value),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _ageRestricted,
          title: const Text('Age-restricted ads'),
          subtitle: const Text('Recommended for teen safety.'),
          onChanged: (value) => setState(() => _ageRestricted = value),
        ),
        MortButton(
          label: 'Toggle ad preferences',
          icon: Icons.save,
          onPressed: _save,
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortGlassHeader(
        eyebrow: 'Settings',
        title: 'Control your account',
        subtitle: 'Privacy, safety, accessibility, security, support, and legal controls in one place.',
      ),
      for (final group in _settingsGroups) ...[
        MortSectionLabel(label: group.label),
        for (final action in group.actions) ...[
          MortDashboardActionTile(
            label: action.label,
            description: action.description,
            icon: action.icon,
            onPressed: () => context.push(action.route),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
      ],
      const MortSectionLabel(label: 'Account closure'),
      MortGlassButton(
        label: 'Request account deletion',
        icon: Icons.delete_outline,
        danger: true,
        onPressed: () => context.push('/settings/account-deletion'),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortSafetyBanner(
        message: 'Report, block, Safety Ping, Guardian Mode basics, and account security are never paywalled.',
      ),
    ],
  );
}

const _settingsGroups = <_SettingsGroup>[
  _SettingsGroup(
    label: 'Account',
    actions: [
      _SettingsAction(
        label: 'Profile',
        description: 'Edit public-safe profile details and approximate area.',
        icon: Icons.person_outline_rounded,
        route: '/settings/profile',
      ),
      _SettingsAction(
        label: 'Username',
        description: 'Review your current username and available changes.',
        icon: Icons.alternate_email_rounded,
        route: '/settings/username',
      ),
      _SettingsAction(
        label: 'Connected accounts',
        description: 'Review email/password and Google sign-in methods.',
        icon: Icons.link_rounded,
        route: '/settings/connected-accounts',
      ),
      _SettingsAction(
        label: 'Security and sessions',
        description:
            'Review active sessions, device lock, and sign-out controls.',
        icon: Icons.phonelink_lock_outlined,
        route: '/settings/security-sessions',
      ),
      _SettingsAction(
        label: 'Account trust',
        description: 'Review verified signals, limitations, and appeals.',
        icon: Icons.shield_outlined,
        route: '/settings/account-trust',
      ),
    ],
  ),
  _SettingsGroup(
    label: 'Privacy and safety',
    actions: [
      _SettingsAction(
        label: 'Privacy',
        description:
            'Control approximate location, visibility, sharing, and blocks.',
        icon: Icons.privacy_tip_outlined,
        route: '/settings/privacy',
      ),
      _SettingsAction(
        label: 'Safety',
        description: 'Open Safety Center, Safety Circle, cases, reporting, and standards.',
        icon: Icons.health_and_safety_outlined,
        route: '/settings/safety',
      ),
      _SettingsAction(
        label: 'Device permissions',
        description:
            'Review camera, photos, foreground location, and notifications.',
        icon: Icons.admin_panel_settings_outlined,
        route: '/settings/native-permissions',
      ),
      _SettingsAction(
        label: 'Guardian Mode',
        description: 'Review optional links and privacy boundaries.',
        icon: Icons.family_restroom_outlined,
        route: '/settings/guardian-mode',
      ),
    ],
  ),
  _SettingsGroup(
    label: 'Notifications and accessibility',
    actions: [
      _SettingsAction(
        label: 'Notifications',
        description:
            'Control categories, quiet hours, permission, and delivery status.',
        icon: Icons.notifications_outlined,
        route: '/notifications',
      ),
      _SettingsAction(
        label: 'Accessibility',
        description: 'Control motion, contrast, transparency, and haptics.',
        icon: Icons.accessibility_new_rounded,
        route: '/settings/accessibility',
      ),
      _SettingsAction(
        label: 'Appearance',
        description: 'Review the active theme and performance fallback.',
        icon: Icons.palette_outlined,
        route: '/settings/appearance',
      ),
    ],
  ),
  _SettingsGroup(
    label: 'Data and history',
    actions: [
      _SettingsAction(
        label: 'Data controls',
        description: 'Review activity, privacy requests, and deletion.',
        icon: Icons.data_usage_outlined,
        route: '/settings/data',
      ),
      _SettingsAction(
        label: 'Reviews received',
        description: 'Review real marketplace reputation records.',
        icon: Icons.star_outline_rounded,
        route: '/settings/reviews',
      ),
      _SettingsAction(
        label: 'Activity history',
        description: 'Review account-visible job and safety activity.',
        icon: Icons.history_rounded,
        route: '/settings/activity',
      ),
    ],
  ),
  _SettingsGroup(
    label: 'Support and optional perks',
    actions: [
      _SettingsAction(
        label: 'Support',
        description: 'Open help, MORT Support, and human escalation paths.',
        icon: Icons.support_agent_outlined,
        route: '/support',
      ),
      _SettingsAction(
        label: 'MORT Guide',
        description: 'Use the bounded, safety-aware help assistant.',
        icon: Icons.assistant_outlined,
        route: '/guide',
      ),
      _SettingsAction(
        label: 'Optional subscription',
        description: 'Review voluntary perks without safety paywalls.',
        icon: Icons.workspace_premium_outlined,
        route: '/settings/subscription',
      ),
      _SettingsAction(
        label: 'Ad preferences',
        description: 'Review age-restricted ad and consent controls.',
        icon: Icons.ads_click_outlined,
        route: '/settings/ad-preferences',
      ),
    ],
  ),
  _SettingsGroup(
    label: 'Legal and about',
    actions: [
      _SettingsAction(
        label: 'Legal center',
        description: 'Review current documents, versions, and clickwrap.',
        icon: Icons.policy_outlined,
        route: '/legal-center',
      ),
      _SettingsAction(
        label: 'Teen safety standards',
        description: 'Review child-safety and prohibited-work standards.',
        icon: Icons.verified_user_outlined,
        route: '/legal/teen-safety',
      ),
      _SettingsAction(
        label: 'Release diagnostics',
        description: 'Review release configuration without exposing secrets.',
        icon: Icons.monitor_heart_outlined,
        route: '/settings/release-diagnostics',
      ),
      _SettingsAction(
        label: 'About MORT',
        description: 'Review version, build, environment, and licenses.',
        icon: Icons.info_outline_rounded,
        route: '/settings/about',
      ),
    ],
  ),
];

class _SettingsGroup {
  const _SettingsGroup({required this.label, required this.actions});

  final String label;
  final List<_SettingsAction> actions;
}

class _SettingsAction {
  const _SettingsAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
}

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffoldScreen(
      eyebrow: 'Legal draft',
      title: title,
      description: 'Review MORT policies, safety standards, and support options. Account access does not replace legal or safety review.',
      children: const [
        MortPaymentDisclaimer(),
        SizedBox(height: MortSpacing.sm),
        MortSafetyBanner(),
      ],
      actions: [
        MortAction(
          label: 'Back',
          icon: Icons.arrow_back_rounded,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/legal-center');
            }
          },
        ),
      ],
    );
  }
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _ticketId;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      final ticketId = await ref
          .read(supportRepositoryProvider)
          .createTicket(subject: _subject.text, message: _message.text);
      if (mounted) setState(() => _ticketId = ticketId);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authRepositoryProvider).currentUser != null;
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Support',
          title: _ticketId == null ? 'Get help' : 'Ticket created',
          subtitle: _ticketId == null
              ? 'Account access, restriction appeals, privacy, and marketplace support start here.'
              : 'Your ticket was sent securely to MORT Support.',
        ),
        const MortCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('Common help topics'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('Safety, reports, blocking, and Safety Ping'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.manage_accounts_outlined),
                title: Text('Account access, profile, or verification'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.work_outline),
                title: Text('Jobs, applications, proof, and reviews'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.payments_outlined),
                title: Text('Payment preference and scam guidance'),
                subtitle: Text(
                  'MORT does not process, hold, escrow, split, or guarantee job payments.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('Optional purchases and ad settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (_ticketId != null) ...[
          const MortCard(
            child: Text(
              'Support can review the ticket without exposing it to other users.',
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Back to account',
            icon: Icons.account_circle,
            onPressed: () => context.go('/account-status'),
          ),
        ] else if (!signedIn) ...[
          const MortEmptyState(
            title: 'Sign in to open a ticket',
            message: 'Support tickets are tied to your MORT account and are not public.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Sign in',
            icon: Icons.login,
            onPressed: () => context.go('/auth/sign-in'),
          ),
        ] else ...[
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.watch(supportRepositoryProvider).listMyTickets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const MortSkeletonCard();
              }
              if (snapshot.hasError) {
                return MortErrorState(
                  title: 'Ticket history unavailable',
                  message: userFacingError(snapshot.error),
                );
              }
              final tickets = snapshot.data ?? const [];
              if (tickets.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MortSectionTitle(title: 'Your existing tickets'),
                  for (final ticket in tickets) ...[
                    MortCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticket['subject']?.toString() ??
                                      'Support ticket',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  'Created ${ticket['created_at']?.toString() ?? 'time unavailable'}',
                                ),
                              ],
                            ),
                          ),
                          MortBadge(
                            label: ticket['status']?.toString() ?? 'open',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MortSpacing.sm),
                  ],
                  const MortSectionTitle(title: 'Open another ticket'),
                ],
              );
            },
          ),
          Form(
            key: _form,
            child: Column(
              children: [
                MortTextField(
                  label: 'Subject',
                  controller: _subject,
                  maxLength: 120,
                  validator: (value) => MortValidators.requiredText(
                    value,
                    minimumLength: 4,
                    maximumLength: 120,
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextArea(
                  label: 'How can support help?',
                  controller: _message,
                  maxLines: 6,
                  maxLength: 2000,
                  validator: (value) => MortValidators.requiredText(
                    value,
                    minimumLength: 10,
                    maximumLength: 2000,
                  ),
                ),
                const SizedBox(height: MortSpacing.md),
                MortButton(
                  label: 'Create support ticket',
                  busyLabel: 'Creating ticket...',
                  busy: _busy,
                  icon: Icons.support_agent,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class FeatureChecklist extends StatelessWidget {
  const FeatureChecklist({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: MortColors.neon,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class FeatureScaffoldScreen extends StatelessWidget {
  const FeatureScaffoldScreen({
    super.key,
    required this.title,
    required this.description,
    this.eyebrow,
    this.actions = const [],
    this.children = const [],
  });

  final String title;
  final String description;
  final String? eyebrow;
  final List<MortAction> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(eyebrow: eyebrow, title: title, subtitle: description),
        ...children,
        if (children.isNotEmpty) const SizedBox(height: MortSpacing.md),
        if (actions.isEmpty) ...[
          const MortEmptyState(
            title: 'Unavailable in this release',
            message: 'This area is not available for your account. Core account and safety tools remain available.',
          ),
          const SizedBox(height: MortSpacing.md),
          const MortActionRow(
            actions: [
              MortAction(
                label: 'Back to account status',
                icon: Icons.home_outlined,
                route: '/account-status',
              ),
              MortAction(
                label: 'Contact support',
                icon: Icons.support_agent,
                route: '/support',
              ),
            ],
          ),
        ] else
          MortActionRow(actions: actions),
      ],
    );
  }
}

class MortErrorStateScreen extends StatelessWidget {
  const MortErrorStateScreen({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [MortErrorState(title: title, message: message)],
    );
  }
}

class _BackendStatusCard extends ConsumerWidget {
  const _BackendStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backendConnectionStatusProvider);
    final connected = switch (status) {
      AsyncData(value: final value) => value,
      _ => false,
    };
    final checking = status.isLoading;
    return MortCard(
      color: connected ? MortColors.neonDeep : MortColors.cardAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            connected
                ? Icons.cloud_done
                : checking
                ? Icons.cloud_sync
                : Icons.cloud_off,
            color: connected ? MortColors.neon : MortColors.warning,
          ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'Connected securely. Marketplace actions may still require account eligibility or verification.'
                      : checking
                      ? 'Checking the secure service connection...'
                      : 'MORT cannot connect right now. Account features remain unavailable until service returns.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!connected && !checking) ...[
                  const SizedBox(height: MortSpacing.sm),
                  TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(backendConnectionStatusProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry connection'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
