import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/app_config.dart';
import '../core/errors/user_facing_error.dart';
import '../core/theme/mort_colors.dart';
import '../core/theme/mort_spacing.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../core/utils/date_of_birth.dart';
import '../core/widgets/date_of_birth_field.dart';
import '../core/widgets/mort_widgets.dart';
import '../data/models/application.dart';
import '../data/models/job.dart';
import '../data/models/message.dart';
import '../data/models/profile.dart';
import '../data/repositories/providers.dart';
import '../data/repositories/uploads_repository.dart';
import '../data/services/supabase_service.dart';
import 'ads/widgets/mort_banner_ad.dart';
import 'mission/partner_staff_screens.dart';
import 'profile/profile_avatar_widgets.dart';

bool get _backendReady => SupabaseService.isInitialized;

final releaseModeStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return ref.read(missionPilotRepositoryProvider).releaseModeStatus();
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const SizedBox(height: MortSpacing.xxl),
        MortHeader(
          eyebrow: 'Local work. Safer connections.',
          title: AppConfig.appName,
          subtitle: AppConfig.slogan,
          trailing: const MortAvatar(radius: 28),
        ),
        const MortSafetyBanner(),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Local jobs for eligible teens',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: MortSpacing.sm),
              Text(
                'Browse approved opportunities, build experience, and use safety tools throughout each job.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: MortSpacing.md),
              MortActionRow(
                actions: const [
                  MortAction(
                    label: 'Enter MORT',
                    icon: Icons.login,
                    route: '/welcome',
                  ),
                  MortAction(
                    label: 'Sign in',
                    icon: Icons.person,
                    route: '/auth/sign-in',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        _BackendStatusCard(),
      ],
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: const [
        MortHeader(
          eyebrow: 'Earn nearby. Move smart.',
          title: 'MORT',
          subtitle:
              'A darker, cleaner local hustle app for teens, adults, guardians, and safety moderation.',
        ),
        MortSafetyBanner(),
        SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MortBadge(
                label: 'Free safety tools stay free',
                color: MortColors.neon,
              ),
              SizedBox(height: MortSpacing.sm),
              Text(
                'Jobs, approvals, messages, reports, proof, and safety review stay together in MORT.',
              ),
              SizedBox(height: MortSpacing.md),
              MortActionRow(
                actions: [
                  MortAction(
                    label: 'Create account',
                    icon: Icons.person_add,
                    route: '/auth/sign-up',
                  ),
                  MortAction(
                    label: 'Sign in',
                    icon: Icons.login,
                    route: '/auth/sign-in',
                  ),
                  MortAction(
                    label: 'Read teen safety',
                    icon: Icons.shield,
                    route: '/legal/teen-safety',
                  ),
                ],
              ),
            ],
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
          subtitle:
              'Close and reopen the app, then try again. Contact MORT Support if the problem continues.',
        ),
        MortErrorState(
          title: 'Connection required',
          message:
              'Sign-in and account features are unavailable until MORT reconnects securely.',
        ),
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
                eyebrow: profile.accountStatus,
                title: 'Account restricted',
                subtitle:
                    'This account cannot continue into MORT right now. Contact support for next steps.',
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
          null => '/onboarding/role',
        };
        return MortScreen(
          children: [
            MortHeader(
              eyebrow: profile.accountStatus,
              title: profile.displayName ?? 'MORT account',
              subtitle:
                  'Role: ${userRoleToString(profile.role) ?? 'not set'} · Verification: ${profile.verificationStatus}',
            ),
            const SizedBox(height: MortSpacing.md),
            _ReleaseModeCard(status: releaseMode),
            const SizedBox(height: MortSpacing.md),
            if (!profile.isActive)
              const MortErrorState(
                title: 'Account restricted',
                message:
                    'This account is suspended or banned. Use support for next steps.',
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

class _ReleaseModeCard extends StatelessWidget {
  const _ReleaseModeCard({required this.status});

  final AsyncValue<Map<String, dynamic>> status;

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => const MortSkeletonCard(),
      error: (_, _) => const MortSafetyBanner(
        message:
            'MORT is operating as a closed pilot. Marketplace access stays restricted while the server status is unavailable.',
      ),
      data: (data) {
        final release = data['release_mode']?.toString() ?? 'closed_test';
        final marketplace =
            data['marketplace_mode']?.toString() ?? 'closed_pilot';
        final publicEnabled = data['public_marketplace_enabled'] == true;
        final documentsEnabled = data['real_document_collection'] == true;
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
                      'Server-controlled access',
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
                        : 'Approved participants only',
                    color: publicEnabled
                        ? MortColors.warning
                        : MortColors.safetyBlue,
                  ),
                  MortBadge(
                    label: documentsEnabled
                        ? 'Document collection enabled'
                        : 'Real ID collection disabled',
                    color: documentsEnabled
                        ? MortColors.warning
                        : MortColors.safetyBlue,
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
  if (clean.isEmpty) return 'Closed pilot';
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}

class OnboardingRequiredScreen extends StatelessWidget {
  const OnboardingRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Onboarding',
          title: 'Finish setup',
          subtitle:
              'MORT needs age, role, city/state, safety acknowledgement, and payment preference.',
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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      if (mounted) context.go('/account-status');
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
          eyebrow: 'Welcome back',
          title: 'Sign in',
          subtitle: 'Use your MORT account.',
        ),
        if (!_backendReady) const _BackendStatusCard(),
        Form(
          key: _form,
          child: Column(
            children: [
              MortTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: MortValidators.email,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Password',
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                validator: (value) =>
                    MortValidators.password(value, minimumLength: 6),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: 'Sign in',
                busyLabel: 'Signing in...',
                busy: _busy,
                icon: Icons.login,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: const [
            MortAction(
              label: 'Create account',
              icon: Icons.person_add,
              route: '/auth/sign-up',
            ),
            MortAction(
              label: 'Forgot password',
              icon: Icons.lock_reset,
              route: '/auth/forgot-password',
            ),
          ],
        ),
      ],
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final response = await ref
          .read(authRepositoryProvider)
          .signUp(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      if (response.session == null) {
        MortToast.show(
          context,
          'Check your email to confirm the account, then sign in.',
        );
        context.go('/auth/sign-in');
      } else {
        context.go('/onboarding/age');
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
          eyebrow: 'Age-gated',
          title: 'Create account',
          subtitle:
              'MORT requires age eligibility and email confirmation before onboarding.',
        ),
        Form(
          key: _form,
          child: Column(
            children: [
              MortTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                autocorrect: false,
                validator: MortValidators.email,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Password',
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                validator: MortValidators.password,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: 'Create account',
                busyLabel: 'Creating...',
                busy: _busy,
                icon: Icons.person_add,
                onPressed: _submit,
              ),
            ],
          ),
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

class OnboardingHubScreen extends StatelessWidget {
  const OnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: const [
        MortHeader(
          eyebrow: 'Setup',
          title: 'Build your MORT account',
          subtitle:
              'Finish age, role, profile, preferences, and the safety agreement. Marketplace access stays limited to approved closed-pilot participants.',
        ),
        MortStepper(current: 0, total: 9),
        SizedBox(height: MortSpacing.md),
        _OnboardingMomentumCard(),
        SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Start age gate',
              icon: Icons.cake,
              route: '/onboarding/age',
            ),
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

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  final _form = GlobalKey<FormState>();
  final _dob = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _dob.dispose();
    super.dispose();
  }

  void _checkAge() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final now = DateTime.now();
    final dob = DateOfBirthParser.tryParse(_dob.text, today: now)!;
    final age = DateOfBirthParser.ageOn(dob, now);
    if (age < 13) {
      setState(() => _message = 'MORT is blocked for users under 13.');
    } else if (age < 18) {
      context.go('/onboarding/role?age=teen');
    } else {
      context.go('/onboarding/role?age=adult');
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
        const MortStepper(current: 1, total: 9),
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
          icon: Icons.arrow_forward,
          onPressed: _checkAge,
        ),
      ],
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, this.ageBand});

  final String? ageBand;

  @override
  Widget build(BuildContext context) {
    final teenAllowed = ageBand != 'adult';
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Role',
          title: 'Choose your lane',
          subtitle:
              'Admins cannot self-select. Admin access must already exist on the backend.',
        ),
        const MortStepper(current: 2, total: 9),
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
              route: '/onboarding/profile?role=teen',
              enabled: teenAllowed,
            ),
            MortAction(
              label: 'Adult / job poster',
              icon: Icons.work_outline,
              route: '/onboarding/profile?role=adult',
              enabled: ageBand != 'teen',
            ),
            MortAction(
              label: 'Guardian',
              icon: Icons.family_restroom,
              route: '/onboarding/profile?role=guardian',
              enabled: ageBand != 'teen',
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
  Profile? _existingProfile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingProfile());
  }

  Future<void> _loadExistingProfile() async {
    if (!_backendReady) return;
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _existingProfile = profile;
        _role = profile.role ?? _role;
        if (_name.text.isEmpty) _name.text = profile.displayName ?? '';
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
      });
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
    _name.dispose();
    _dob.dispose();
    _city.dispose();
    _state.dispose();
    _bio.dispose();
    _availability.dispose();
    _approximateArea.dispose();
    _goals.dispose();
    _preferredCategories.dispose();
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
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveProfile(
            role: _role!,
            displayName: _name.text,
            dob: dob,
            city: _city.text,
            state: _state.text,
            locationSetupMode: _role == UserRole.teen
                ? _locationSetupMode
                : 'city_state',
            completeOnboarding: false,
          );
      await ref
          .read(profileRepositoryProvider)
          .saveProfileDetails(
            displayName: _name.text,
            bio: _bio.text,
            availability: _availability.text,
            preferredJobCategories: _preferredCategories.text
                .split(',')
                .map((value) => value.trim().toLowerCase())
                .where((value) => value.isNotEmpty)
                .take(12)
                .toList(),
            approximateArea: _approximateArea.text,
            goals: _goals.text,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) context.go('/onboarding/skills');
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
          eyebrow: 'Profile',
          title: 'Set your basics',
          subtitle: _role == UserRole.teen
              ? 'A permanent address is not required. MORT never asks why you choose a partner-supported or deferred setup.'
              : 'Only safe, general location fields are used here. Exact addresses do not belong in chat.',
        ),
        const MortStepper(current: 3, total: 9),
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
              MortDropdown<UserRole>(
                label: 'Role',
                value: _role,
                items: const {
                  UserRole.teen: 'Teen 13-17',
                  UserRole.adult: 'Adult / business',
                  UserRole.guardian: 'Guardian',
                },
                onChanged: (value) => setState(() {
                  _role = value;
                  if (value != UserRole.teen) {
                    _locationSetupMode = 'city_state';
                  }
                }),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Display name',
                controller: _name,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    MortValidators.requiredText(value, maximumLength: 80),
              ),
              const SizedBox(height: MortSpacing.sm),
              DateOfBirthField(controller: _dob),
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
                  onChanged: (value) => setState(
                    () => _locationSetupMode = value ?? 'city_state',
                  ),
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
              if (_locationSetupMode == 'city_state' ||
                  _role != UserRole.teen) ...[
                MortTextField(
                  label: 'City',
                  controller: _city,
                  textInputAction: TextInputAction.next,
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
                hint:
                    'Share safe experience and interests without contact details.',
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Availability',
                controller: _availability,
                hint: 'Weekends and weekday afternoons',
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Approximate area',
                controller: _approximateArea,
                hint: 'General neighborhood or side of town',
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Preferred job categories',
                controller: _preferredCategories,
                hint: 'cleaning, tutoring, pet care',
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextArea(label: 'Goals', controller: _goals, maxLength: 500),
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

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffoldScreen(
      eyebrow: 'Skills',
      title: 'Show what you can do safely',
      description:
          'Start with common, safe local categories. You can continue now; richer saved skill editing can be added later without blocking onboarding.',
      children: [
        MortStepper(current: 4, total: 9),
        SizedBox(height: MortSpacing.md),
        FeatureChecklist(
          items: [
            'Yard help, pet care, tutoring, cleaning, errands, creative help, and event setup are safe starting categories.',
            'Avoid unsafe tools, overnight work, private homes without guardian awareness, or off-platform pressure.',
            'Adults should describe the job clearly so teens and guardians can decide quickly.',
          ],
        ),
      ],
      actions: [
        MortAction(
          label: 'Closed-pilot access',
          icon: Icons.verified_user_outlined,
          route: '/mission/pilot-eligibility',
        ),
        MortAction(
          label: 'Partner affiliation',
          icon: Icons.account_balance_outlined,
          route: '/mission/partner-affiliation',
        ),
        MortAction(
          label: 'Discreet Mode',
          icon: Icons.visibility_off_outlined,
          route: '/mission/discreet-mode',
        ),
        MortAction(
          label: 'Optional Support Circle',
          icon: Icons.groups_outlined,
          route: '/mission/support-circle',
        ),
        MortAction(
          label: 'Earnings and goals',
          icon: Icons.savings_outlined,
          route: '/mission/earnings-goals',
        ),
        MortAction(
          label: 'Future Independence Plan',
          icon: Icons.route_outlined,
          route: '/mission/future-independence',
        ),
        MortAction(
          label: 'Private resource directory',
          icon: Icons.menu_book_outlined,
          route: '/mission/resources',
        ),
        MortAction(
          label: 'Pilot job safety',
          icon: Icons.work_outline,
          route: '/mission/pilot-job-safety',
        ),
        MortAction(
          label: 'What verification means',
          icon: Icons.fact_check_outlined,
          route: '/mission/verification-wording',
        ),
        MortAction(
          label: 'Document review status',
          icon: Icons.document_scanner_outlined,
          route: '/mission/document-review',
        ),
        MortAction(
          label: 'Continue',
          icon: Icons.arrow_forward,
          route: '/onboarding/availability',
        ),
      ],
    );
  }
}

class AvailabilityScreen extends StatelessWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureScaffoldScreen(
      eyebrow: 'Availability',
      title: 'Pick safe time windows',
      description:
          'MORT should recommend safe, general windows instead of making users invent a schedule from a blank page.',
      children: [
        MortStepper(current: 5, total: 9),
        SizedBox(height: MortSpacing.md),
        FeatureChecklist(
          items: [
            'Teen default: after school, weekends, daylight-first.',
            'Adult default: flexible windows with clear start/end expectations.',
            'Guardian default: alerts for approvals, check-ins, and unusual message/report activity.',
          ],
        ),
      ],
      actions: [
        MortAction(
          label: 'Continue',
          icon: Icons.arrow_forward,
          route: '/onboarding/payment',
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
  String _preference = 'none';
  final _cashApp = TextEditingController();
  final _squareUrl = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _cashApp.dispose();
    _squareUrl.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_backendReady) {
      MortToast.show(
        context,
        'MORT cannot connect right now. Try again later.',
      );
      return;
    }
    if (_busy) return;
    if (_preference == 'cash_app' && _cashApp.text.trim().isEmpty) {
      MortToast.show(context, 'Enter a Cash App tag or choose another option.');
      return;
    }
    if (_preference == 'square_link') {
      final uri = Uri.tryParse(_squareUrl.text.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        MortToast.show(context, 'Enter a secure https Square link.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .savePaymentPreference(
            preference: _preference,
            cashAppTag: _cashApp.text.trim().isEmpty
                ? null
                : _cashApp.text.trim(),
            squareUrl: _squareUrl.text.trim().isEmpty
                ? null
                : _squareUrl.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
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
          eyebrow: 'Payment preference only',
          title: 'How do you prefer to arrange payment?',
          subtitle:
              'MORT does not process job payments, cards, payouts, escrow, splits, or guarantees.',
        ),
        const MortStepper(current: 6, total: 9),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'Smart default: Not set. You can keep using MORT without adding a payment handle, and payment must still be arranged safely outside MORT.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Preference',
          value: _preference,
          items: const {
            'none': 'Not set',
            'cash': 'Cash',
            'cash_app': 'Cash App tag',
            'square_link': 'Square invoice/payment link',
            'flexible': 'Flexible',
          },
          onChanged: (value) => setState(() => _preference = value ?? 'none'),
        ),
        const SizedBox(height: MortSpacing.sm),
        if (_preference == 'cash_app') ...[
          MortTextField(
            label: 'Cash App tag',
            controller: _cashApp,
            maxLength: 40,
            autocorrect: false,
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        if (_preference == 'square_link') ...[
          MortTextField(
            label: 'Square URL',
            controller: _squareUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(label: 'Notes', controller: _note, maxLines: 3),
        const SizedBox(height: MortSpacing.md),
        const MortPaymentDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save payment preference',
          busyLabel: 'Saving...',
          busy: _busy,
          icon: Icons.save,
          onPressed: _save,
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

  Future<void> _finish() async {
    if (_busy) return;
    if (!_backendReady) {
      MortToast.show(
        context,
        'MORT cannot connect right now. Try again later.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).completeOnboarding();
      ref.invalidate(currentProfileProvider);
      if (mounted) context.go('/account-status');
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
          title: 'Rules before earning',
          subtitle:
              'No exact addresses in chat, no unsafe tools, no off-platform pressure, and report anything weird.',
        ),
        const MortStepper(current: 8, total: 9),
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
        MortButton(
          label: 'I understand - finish setup',
          busyLabel: 'Finishing...',
          busy: _busy,
          icon: Icons.check_circle,
          onPressed: _finish,
        ),
      ],
    );
  }
}

class _OnboardingMomentumCard extends StatelessWidget {
  const _OnboardingMomentumCard();

  @override
  Widget build(BuildContext context) {
    return const MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(label: '1 of 8 started', color: MortColors.neon),
          SizedBox(height: MortSpacing.sm),
          Text(
            'Your account is ready. Complete the remaining safety-first setup steps.',
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
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: profile?.displayName ?? userRoleToString(role) ?? 'MORT',
          title: title,
          subtitle:
              'Safety-first workflows and optional perks without paywalling core safety.',
          trailing: MortNotificationBell(
            onPressed: () => context.go('/notifications'),
          ),
        ),
        if (role == UserRole.teen)
          MortProfileCompletionMeter(value: profile?.completionRatio ?? 0),
        if (role == UserRole.adult) const MortVerificationDisclaimer(),
        if (role == UserRole.guardian) const MortGuardianBanner(),
        if (role == UserRole.admin)
          const MortSafetyBanner(
            message:
                'Admin tools are limited to authorized moderation accounts.',
          ),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(actions: actions),
        const SizedBox(height: MortSpacing.md),
        if (role == UserRole.teen || role == UserRole.adult)
          MortBannerAd(
            placement: role == UserRole.teen ? 'job_feed' : 'adult_dashboard',
          ),
      ],
    );
  }
}

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
          subtitle:
              'General area only. Use reports and Safety Ping if anything feels off.',
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
                message:
                    'Applications will appear after a teen applies or an adult posts jobs.',
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
      final cents = MortValidators.dollarsToCents(_pay.text);
      await ref
          .read(jobsRepositoryProvider)
          .createJob(
            title: _title.text,
            description: _description.text,
            category: _category.text,
            locationText: _area.text,
            city: _city.text,
            state: _state.text,
            payAmountCents: cents,
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
          subtitle:
              'No hazardous work, no private contact pressure, no exact-location sharing in chat.',
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
                validator: MortValidators.dollarAmount,
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
      final prepared = UploadsRepository.prepareProof(await file.readAsBytes());
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
          subtitle:
              'Choose one clear completion photo. MORT re-encodes it as a private JPEG before upload.',
        ),
        const MortSafetyBanner(
          message:
              'Proof should show job completion only. Do not upload private IDs, exact addresses, or unrelated people.',
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

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _picker = ImagePicker();
  PreparedVerificationImage? _document;
  String? _fileName;
  String? _submissionId;
  String _businessType = 'individual';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _choose(ImageSource source) async {
    if (_busy) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2800,
        maxHeight: 2800,
        imageQuality: 94,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final repository = ref.read(uploadsRepositoryProvider);
      final prepared = UploadsRepository.prepareVerification(
        await file.readAsBytes(),
      );
      setState(() {
        _document = prepared;
        _fileName = file.name;
        _submissionId = repository.newVerificationSubmissionId();
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  Future<void> _submit() async {
    final document = _document;
    final submissionId = _submissionId;
    if (_busy || document == null || submissionId == null) return;
    if (_name.text.trim().length < 2) {
      MortToast.show(context, 'Add your account or business name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(uploadsRepositoryProvider)
          .uploadVerificationDocument(
            submissionId: submissionId,
            businessName: _name.text.trim(),
            businessType: _businessType,
            document: document,
            notes: _notes.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      MortToast.show(context, 'Verification submitted for review.');
      setState(() {
        _document = null;
        _fileName = null;
        _submissionId = null;
        _notes.clear();
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final document = _document;
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Adult/business trust',
          title: 'Verification',
          subtitle:
              'Submit an internal review request before publishing jobs. Verification does not guarantee another user or job.',
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
        const MortVerificationDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Upload only the minimum document needed for internal review. Cover Social Security numbers, bank details, full license numbers, and unrelated personal information.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MortTextField(
                label: 'Account or business name',
                controller: _name,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortDropdown<String>(
                label: 'Account type',
                value: _businessType,
                items: const {
                  'individual': 'Individual adult',
                  'sole_proprietor': 'Sole proprietor',
                  'business': 'Business',
                  'nonprofit': 'Nonprofit',
                  'community_organization': 'Community organization',
                },
                onChanged: (value) {
                  if (value != null) setState(() => _businessType = value);
                },
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextArea(
                label: 'Optional reviewer note',
                controller: _notes,
                maxLength: 1000,
                hint: 'Explain what this document verifies.',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document == null ? 'Verification image' : 'Private preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MortSpacing.sm),
              if (document == null)
                const Text('Choose a JPEG, PNG, or WebP image under 10 MB.')
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(document.bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  '${_fileName ?? 'Selected image'} - re-encoded without original metadata',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: MortSpacing.md),
              MortActionRow(
                actions: [
                  MortAction(
                    label: document == null ? 'Choose image' : 'Replace image',
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
                  'Browser file selection works in web preview. Native camera and permission behavior require Android or iPhone device testing.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: profile?.verificationStatus == 'rejected'
              ? 'Resubmit verification'
              : 'Submit verification',
          busyLabel: 'Submitting...',
          busy: _busy,
          icon: Icons.upload_file,
          onPressed: document == null ? null : _submit,
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
  late Future<List<MessageThread>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(messagingRepositoryProvider).listThreads();
  }

  void _reload() {
    setState(() {
      _future = ref.read(messagingRepositoryProvider).listThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_backendReady) return const SetupRequiredScreen();
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Safety scanner',
          title: 'Messages',
          subtitle: 'No ads in chat. Messages pass through MORT safety checks.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh conversations',
            onPressed: _reload,
          ),
        ),
        FutureBuilder<List<MessageThread>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Messages error',
                message: userFacingError(snapshot.error),
              );
            final threads = snapshot.data ?? const [];
            if (threads.isEmpty) {
              return const MortEmptyState(
                title: 'No conversations yet',
                message: 'A thread appears when a job/application creates one.',
              );
            }
            return Column(
              children: [
                for (final thread in threads) ...[
                  MortCard(
                    onTap: () => context.go('/messages/${thread.id}'),
                    child: Row(
                      children: [
                        const MortAvatar(label: 'M'),
                        const SizedBox(width: MortSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Protected conversation',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                formatDateTime(thread.updatedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (thread.unreadCount > 0) ...[
                          MortBadge(
                            label: thread.unreadCount == 1
                                ? '1 unread'
                                : '${thread.unreadCount} unread',
                            color: MortColors.warning,
                          ),
                          const SizedBox(width: MortSpacing.xs),
                        ],
                        const Icon(Icons.chevron_right),
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

class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  final _body = TextEditingController();
  late Future<List<MortMessage>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<List<MortMessage>> _load() async {
    final repository = ref.read(messagingRepositoryProvider);
    final messages = await repository.listMessages(widget.threadId);
    await repository.markThreadRead(widget.threadId);
    return messages;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _send() async {
    if (_body.text.trim().isEmpty || _busy) return;
    if (_body.text.trim().length > 2000) {
      MortToast.show(context, 'Keep messages under 2,000 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendSafeMessage(widget.threadId, _body.text);
      _body.clear();
      if (mounted) MortToast.show(context, 'Message sent through scanner.');
      if (mounted) _reload();
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
          eyebrow: 'Keep chat in MORT',
          title: 'Thread',
          subtitle:
              'Phone numbers, social handles, exact addresses, and off-platform pressure can be blocked.',
        ),
        const MortSafetyBanner(
          message:
              'Use quick replies and report anything unsafe. No ads appear in messages.',
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<MortMessage>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Thread error',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            final messages = snapshot.data ?? const [];
            return Column(
              children: [
                if (messages.isEmpty)
                  const MortEmptyState(
                    title: 'No messages yet',
                    message: 'Start with a safe, on-platform note.',
                  ),
                for (final message in messages) ...[
                  MortCard(
                    color: message.blocked
                        ? MortColors.danger.withValues(alpha: 0.1)
                        : MortColors.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MortBadge(
                          label: message.scannerStatus,
                          color: message.blocked
                              ? MortColors.danger
                              : message.flagged
                              ? MortColors.warning
                              : MortColors.neon,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          message.blocked ? 'Blocked by scanner' : message.body,
                        ),
                        if (message.scannerReason != null)
                          Text(
                            message.scannerReason!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: MortSpacing.xs),
                        MortActionRow(
                          actions: [
                            MortAction(
                              label: 'Report message',
                              icon: Icons.report,
                              route: '/report/message/${message.id}',
                              style: MortButtonStyle.danger,
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
        MortTextArea(
          label: 'Message',
          controller: _body,
          maxLines: 3,
          maxLength: 2000,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Send message',
              icon: Icons.send,
              onPressed: _send,
              busy: _busy,
              busyLabel: 'Sending...',
              style: MortButtonStyle.primary,
            ),
          ],
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

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_reason == 'other' && _details.text.trim().length < 10) {
      MortToast.show(context, 'Add a short description for Other.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .createReport(
            targetUserId: widget.targetUserId,
            targetJobId: widget.targetJobId,
            targetMessageId: widget.targetMessageId,
            targetReviewId: widget.targetReviewId,
            reason: _reason,
            details: _details.text.trim().isEmpty ? null : _details.text.trim(),
          );
      if (mounted) setState(() => _submitted = true);
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
            subtitle:
                'MORT records the report for moderation. Immediate danger still requires local emergency services.',
          ),
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
          subtitle:
              'Reports are reviewed without blaming the reporter. MORT is not an emergency service.',
        ),
        const MortSafetyBanner(
          message:
              'For immediate danger, contact local emergency services and a trusted adult.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortDropdown<String>(
          label: 'Reason',
          value: _reason,
          items: const {
            'unsafe_job': 'Unsafe or prohibited job',
            'scam': 'Scam or upfront fee',
            'contact_sharing': 'Off-platform contact pressure',
            'harassment': 'Threats or harassment',
            'sexual_content': 'Sexual content',
            'other': 'Other',
          },
          onChanged: (value) => setState(() => _reason = value ?? 'other'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Details (optional)',
          controller: _details,
          maxLines: 5,
          maxLength: 1000,
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
            message:
                'Blocking does not contact emergency services. Report urgent safety concerns too.',
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

class _SafetyCenterScreenState extends ConsumerState<SafetyCenterScreen> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _ping() async {
    if (_busy) return;
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Send Safety Ping?',
      message:
          'This alerts the people configured by MORT. It is not a replacement for emergency services.',
      confirmLabel: 'Send Safety Ping',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .createSafetyPing(note: _note.text.trim());
      if (mounted) MortToast.show(context, 'Safety Ping created.');
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
          eyebrow: 'Safety Center',
          title: 'Get help inside MORT',
          subtitle:
              'Safety Ping is not an emergency service. Call local emergency services for immediate danger.',
        ),
        const MortSafetyBanner(
          message:
              'Report, block, and Safety Ping stay free. Keep communication on MORT.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortTextArea(
          label: 'Optional Safety Ping note',
          controller: _note,
          maxLines: 3,
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Safety Ping',
          busyLabel: 'Sending Safety Ping...',
          busy: _busy,
          icon: Icons.health_and_safety,
          style: MortButtonStyle.danger,
          onPressed: _ping,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Safety Circle',
          icon: Icons.group_outlined,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/settings/safety-circle'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Safety case history',
          icon: Icons.folder_shared_outlined,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/settings/safety-cases'),
        ),
        const SizedBox(height: MortSpacing.md),
        const FeatureChecklist(
          items: [
            'Guardian knows where you are.',
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
          subtitle:
              'Review account and job activity in one place. Device alerts require notification permission.',
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

enum AdminSensitiveQueueAction { none, identity, incident }

class AdminQueueScreen extends ConsumerStatefulWidget {
  const AdminQueueScreen({
    super.key,
    required this.title,
    required this.table,
    this.subtitle,
    this.statusField = 'status',
    this.actionLabel,
    this.actionValue,
    this.equals = const {},
    this.notEquals = const {},
    this.orFilter,
    this.sensitiveAction = AdminSensitiveQueueAction.none,
  });

  final String title;
  final String table;
  final String? subtitle;
  final String statusField;
  final String? actionLabel;
  final String? actionValue;
  final Map<String, String> equals;
  final Map<String, String> notEquals;
  final String? orFilter;
  final AdminSensitiveQueueAction sensitiveAction;

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
                    actionLabel: widget.actionLabel,
                    actionValue: widget.actionValue,
                    sensitiveAction: widget.sensitiveAction,
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

class _AdminRowCard extends ConsumerStatefulWidget {
  const _AdminRowCard({
    required this.table,
    required this.row,
    required this.statusField,
    required this.actionLabel,
    required this.actionValue,
    required this.sensitiveAction,
    required this.onUpdated,
  });

  final String table;
  final Map<String, dynamic> row;
  final String statusField;
  final String? actionLabel;
  final String? actionValue;
  final AdminSensitiveQueueAction sensitiveAction;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AdminRowCard> createState() => _AdminRowCardState();
}

class _AdminRowCardState extends ConsumerState<_AdminRowCard> {
  bool _busy = false;

  Future<String?> _reasonDialog(String title, String guidance) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(guidance),
            const SizedBox(height: MortSpacing.md),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Decision reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

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

  Future<void> _update(String id) async {
    if (_busy || widget.actionValue == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).updateById(widget.table, id, {
        widget.statusField: widget.actionValue,
      });
      if (!mounted) return;
      MortToast.show(context, '${widget.actionLabel} completed.');
      widget.onUpdated();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewIdentity(String id, String action) async {
    if (_busy) return;
    String? decisionCode;
    if (action == 'approve') {
      final confirmed = await _confirm(
        'Approve identity verification?',
        'Approve only after reviewing restricted evidence through the logged access workflow and confirming every required check. Verification does not guarantee safety.',
      );
      if (!confirmed) return;
      decisionCode = 'restricted_evidence_review_completed';
    } else {
      decisionCode = await _reasonDialog(
        action == 'request_information'
            ? 'Request more information'
            : 'Reject identity verification',
        'Use a factual reason. The user may see this code and may appeal the result.',
      );
      if (decisionCode == null) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .reviewIdentity(
            verificationId: id,
            action: action,
            decisionCode: decisionCode,
          );
      if (!mounted) return;
      MortToast.show(context, 'Identity review action completed.');
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
      _ =>
        'The current safety review is resolved. Appeal options remain available where applicable.',
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
          if (id != null &&
              widget.sensitiveAction == AdminSensitiveQueueAction.identity) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: 'Approve after evidence review',
                  icon: Icons.verified_user,
                  busy: _busy,
                  onPressed: () => _reviewIdentity(id, 'approve'),
                ),
                MortAction(
                  label: 'Request information',
                  icon: Icons.more_horiz,
                  busy: _busy,
                  onPressed: () => _reviewIdentity(id, 'request_information'),
                ),
                MortAction(
                  label: 'Reject',
                  icon: Icons.block,
                  busy: _busy,
                  onPressed: () => _reviewIdentity(id, 'reject'),
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
          ] else if (id != null && widget.actionValue != null) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                MortAction(
                  label: widget.actionLabel ?? 'Update',
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
          subtitle:
              'Three free lifetime changes, then Plus allowance, token, or admin credit.',
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
  Widget build(BuildContext context) {
    return const FeatureScaffoldScreen(
      eyebrow: 'Settings',
      title: 'Control your account',
      description:
          'Profile, trust, device security, privacy, legal, support, and sign-out.',
      actions: [
        MortAction(
          label: 'Edit profile',
          icon: Icons.person,
          route: '/settings/profile',
        ),
        MortAction(
          label: 'Username',
          icon: Icons.alternate_email,
          route: '/settings/username',
        ),
        MortAction(
          label: 'Guardian Mode',
          icon: Icons.family_restroom,
          route: '/settings/guardian-mode',
        ),
        MortAction(
          label: 'Account trust',
          icon: Icons.shield_outlined,
          route: '/settings/account-trust',
        ),
        MortAction(
          label: 'Teen verification options',
          icon: Icons.school_outlined,
          route: '/trust/teen-verification',
        ),
        MortAction(
          label: 'Device security',
          icon: Icons.phonelink_lock,
          route: '/settings/device-security',
        ),
        MortAction(
          label: 'Device permissions',
          icon: Icons.admin_panel_settings_outlined,
          route: '/settings/native-permissions',
        ),
        MortAction(
          label: 'Safety Circle',
          icon: Icons.group_outlined,
          route: '/settings/safety-circle',
        ),
        MortAction(
          label: 'Safety cases',
          icon: Icons.folder_shared_outlined,
          route: '/settings/safety-cases',
        ),
        MortAction(
          label: 'Active sessions',
          icon: Icons.phonelink_lock,
          route: '/settings/active-sessions',
        ),
        MortAction(
          label: 'Reviews received',
          icon: Icons.star_outline,
          route: '/settings/reviews',
        ),
        MortAction(
          label: 'Activity history',
          icon: Icons.history,
          route: '/settings/activity',
        ),
        MortAction(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          route: '/notifications',
        ),
        MortAction(
          label: 'Support',
          icon: Icons.support_agent,
          route: '/support',
        ),
        MortAction(
          label: 'MORT Guide',
          icon: Icons.assistant_outlined,
          route: '/guide',
        ),
        MortAction(
          label: 'Subscription',
          icon: Icons.workspace_premium,
          route: '/settings/subscription',
        ),
        MortAction(
          label: 'Ad preferences',
          icon: Icons.ads_click,
          route: '/settings/ad-preferences',
        ),
        MortAction(
          label: 'Privacy',
          icon: Icons.privacy_tip,
          route: '/settings/privacy',
        ),
        MortAction(
          label: 'Legal',
          icon: Icons.policy,
          route: '/settings/legal',
        ),
        MortAction(
          label: 'Legal center and clickwrap',
          icon: Icons.verified_user_outlined,
          route: '/legal-center',
        ),
        MortAction(
          label: 'Job agreements and payment',
          icon: Icons.description_outlined,
          route: '/contracts',
        ),
        MortAction(
          label: 'Trust architecture status',
          icon: Icons.fact_check_outlined,
          route: '/trust/foundations',
        ),
        MortAction(
          label: 'Request account deletion',
          icon: Icons.delete_outline,
          route: '/settings/account-deletion',
          style: MortButtonStyle.danger,
        ),
      ],
    );
  }
}

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffoldScreen(
      eyebrow: 'Legal draft',
      title: title,
      description:
          'Review MORT policies, safety standards, and support options. Closed-pilot access does not replace legal or safety review.',
      children: const [
        MortPaymentDisclaimer(),
        SizedBox(height: MortSpacing.sm),
        MortSafetyBanner(),
      ],
      actions: const [
        MortAction(
          label: 'Back to settings',
          icon: Icons.settings,
          route: '/settings',
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
            message:
                'Support tickets are tied to your MORT account and are not public.',
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
            message:
                'This area is not enabled for the closed pilot. Core account and safety tools remain available.',
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

class _BackendStatusCard extends StatelessWidget {
  const _BackendStatusCard();

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: AppConfig.isSupabaseConfigured
          ? MortColors.neonDeep
          : MortColors.cardAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppConfig.isSupabaseConfigured ? Icons.cloud_done : Icons.cloud_off,
            color: AppConfig.isSupabaseConfigured
                ? MortColors.neon
                : MortColors.warning,
          ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              AppConfig.isSupabaseConfigured
                  ? 'Connected securely. Marketplace access remains limited to approved closed-pilot participants.'
                  : 'MORT cannot connect right now. Account features remain unavailable until service returns.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
