import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/reviewer/reviewer_session.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/onboarding_progress.dart';
import '../../data/repositories/providers.dart';
import '../../data/services/supabase_service.dart';
import 'google_auth_screens.dart';

enum UnifiedAuthMode { signIn, signUp }

class UnifiedAuthScreen extends ConsumerStatefulWidget {
  const UnifiedAuthScreen({
    super.key,
    this.initialMode = UnifiedAuthMode.signIn,
  });

  final UnifiedAuthMode initialMode;

  @override
  ConsumerState<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends ConsumerState<UnifiedAuthScreen> {
  final _signInForm = GlobalKey<FormState>();
  final _signUpForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpPassword = TextEditingController();
  late UnifiedAuthMode _mode;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _legalAcknowledged = false;
  bool _reviewerIdentifierEntered = false;
  bool _legalError = false;
  String? _formError;

  bool get _backendReady => SupabaseService.isInitialized;
  bool get _isSignIn => _mode == UnifiedAuthMode.signIn;
  GlobalKey<FormState> get _form => _isSignIn ? _signInForm : _signUpForm;
  TextEditingController get _activePassword =>
      _isSignIn ? _signInPassword : _signUpPassword;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(UnifiedAuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode && !_busy) {
      _switchMode(widget.initialMode);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _signInPassword.dispose();
    _signUpPassword.dispose();
    super.dispose();
  }

  void _switchMode(UnifiedAuthMode mode) {
    if (_mode == mode || _busy) return;
    setState(() {
      _mode = mode;
      _obscurePassword = true;
      _formError = null;
      _legalError = false;
      _reviewerIdentifierEntered =
          mode == UnifiedAuthMode.signIn &&
          isExactPlayReviewerIdentifier(
            _email.text,
            reviewerModeEnabled: ref.read(reviewerModeEnabledProvider),
          );
    });
  }

  void _onEmailChanged(String value) {
    final isReviewer =
        _isSignIn &&
        isExactPlayReviewerIdentifier(
          value,
          reviewerModeEnabled: ref.read(reviewerModeEnabledProvider),
        );
    if (isReviewer == _reviewerIdentifierEntered) return;
    if (isReviewer) _signInPassword.clear();
    setState(() => _reviewerIdentifierEntered = isReviewer);
  }

  Future<void> _recordAcknowledgement() async {
    if (!_legalAcknowledged) return;
    try {
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
      ref.invalidate(onboardingProgressProvider);
    } catch (_) {
      // Onboarding remains the server-authoritative acknowledgement fallback.
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_backendReady) {
      setState(() {
        _formError = 'MORT cannot connect securely right now. Try again later.';
      });
      return;
    }
    setState(() {
      _formError = null;
      _legalError = !_isSignIn && !_legalAcknowledged;
    });
    if (_form.currentState?.validate() != true || _legalError) return;

    setState(() => _busy = true);
    try {
      if (_isSignIn) {
        final response = await ref
            .read(authRepositoryProvider)
            .signIn(email: _email.text.trim(), password: _signInPassword.text);
        if (response.session != null) await _recordAcknowledgement();
        if (mounted) context.go('/account-status');
        return;
      }

      if (isExactPlayReviewerIdentifier(
        _email.text,
        reviewerModeEnabled: ref.read(reviewerModeEnabledProvider),
      )) {
        setState(() {
          _formError = 'This identifier is reserved for Google Play review.';
        });
        return;
      }
      final response = await ref
          .read(authRepositoryProvider)
          .signUp(email: _email.text.trim(), password: _signUpPassword.text);
      if (!mounted) return;
      if (response.session == null) {
        MortToast.show(
          context,
          'Check your email to confirm the account, then sign in.',
        );
        _switchMode(UnifiedAuthMode.signIn);
      } else {
        await _recordAcknowledgement();
        if (mounted) context.go('/onboarding/age');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startReviewer() {
    if (_busy) return;
    final productionSessionPresent =
        ref.read(authRepositoryProvider).currentUser != null;
    final started = ref
        .read(reviewerSessionProvider)
        .start(
          identifier: _email.text,
          productionSessionPresent: productionSessionPresent,
        );
    if (!started) {
      setState(() {
        _formError = productionSessionPresent
            ? 'Sign out of the current MORT account before starting review mode.'
            : 'Enter the exact Google Play reviewer identifier.';
      });
      return;
    }
    context.go('/review');
  }

  @override
  Widget build(BuildContext context) {
    final eyebrow = _isSignIn ? 'Welcome back' : 'Age-gated';
    return MortScreen(
      children: [
        const Center(child: MortBrandMark(size: 72, showWordmark: true)),
        const SizedBox(height: MortSpacing.md),
        MortGlassHeader(
          eyebrow: eyebrow,
          title: _reviewerIdentifierEntered ? 'Sign in' : 'Access MORT',
          subtitle: _isSignIn
              ? 'Use your account or switch to create one without leaving this screen.'
              : 'Create an account, confirm your email, then complete age and role onboarding.',
          showBack: true,
          onBack: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/splash'),
        ),
        const SizedBox(height: MortSpacing.md),
        if (!_reviewerIdentifierEntered)
          MortSegmentedControl<UnifiedAuthMode>(
            value: _mode,
            options: const [
              MortSegmentOption(
                value: UnifiedAuthMode.signIn,
                label: 'Sign in',
                icon: Icons.login_rounded,
              ),
              MortSegmentOption(
                value: UnifiedAuthMode.signUp,
                label: 'Create account',
                icon: Icons.person_add_alt_1_rounded,
              ),
            ],
            onChanged: _switchMode,
          ),
        if (!_backendReady) ...[
          const SizedBox(height: MortSpacing.md),
          const MortSafetyBanner(
            message:
                'Secure sign-in is unavailable until MORT reconnects to its hosted backend.',
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortTextField(
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: [
                    _isSignIn ? AutofillHints.email : AutofillHints.newUsername,
                  ],
                  autocorrect: false,
                  validator: (value) => !_isSignIn
                      ? rejectReservedPlayReviewerIdentifier(
                              value,
                              reviewerModeEnabled: ref.watch(
                                reviewerModeEnabledProvider,
                              ),
                            ) ??
                            MortValidators.email(value)
                      : MortValidators.email(value),
                  onChanged: _onEmailChanged,
                ),
                if (_reviewerIdentifierEntered) ...[
                  const SizedBox(height: MortSpacing.md),
                  const MortGlassSoftSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MortStatusPill(
                          label: 'Google Play Review Mode',
                          color: MortColors.warning,
                          icon: Icons.verified_user,
                        ),
                        SizedBox(height: MortSpacing.sm),
                        Text(
                          'Synthetic demonstration data. No production account or password is created.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.md),
                  MortButton(
                    label: 'Continue as Play Reviewer',
                    icon: Icons.verified_user,
                    onPressed: _startReviewer,
                  ),
                ] else ...[
                  const SizedBox(height: MortSpacing.sm),
                  MortTextField(
                    key: ValueKey(_mode),
                    label: 'Password',
                    controller: _activePassword,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      _isSignIn
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => MortValidators.password(
                      value,
                      minimumLength: _isSignIn ? 6 : 12,
                      requireComplexity: !_isSignIn,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  if (!_isSignIn) ...[
                    const SizedBox(height: MortSpacing.sm),
                    const MortGlassSoftSurface(
                      child: Text(
                        'Use at least 12 characters with uppercase, lowercase, a number, and a symbol.',
                      ),
                    ),
                  ],
                  const SizedBox(height: MortSpacing.md),
                  if (_formError != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: MortErrorState(
                        title: _isSignIn
                            ? 'Sign in unsuccessful'
                            : 'Account creation unsuccessful',
                        message: _formError!,
                      ),
                    ),
                    const SizedBox(height: MortSpacing.md),
                  ],
                  MortButton(
                    label: _isSignIn ? 'Sign in' : 'Create account',
                    busyLabel: _isSignIn
                        ? 'Signing in...'
                        : 'Creating account...',
                    busy: _busy,
                    icon: _isSignIn
                        ? Icons.login_rounded
                        : Icons.person_add_alt_1_rounded,
                    onPressed: _busy ? null : _submit,
                  ),
                  if (_isSignIn) ...[
                    const SizedBox(height: MortSpacing.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push('/auth/forgot-password'),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Forgot password'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (!_reviewerIdentifierEntered) ...[
          const SizedBox(height: MortSpacing.md),
          const GoogleAuthSection(),
        ],
        const SizedBox(height: MortSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _legalAcknowledged,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _legalAcknowledged = value == true;
                      if (_legalAcknowledged) _legalError = false;
                    }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isSignIn
                            ? 'I have read MORT\'s '
                            : 'I agree to MORT\'s ',
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 36),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        onPressed: () => context.push('/legal/terms'),
                        child: const Text('Terms'),
                      ),
                      const Text(' and '),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 36),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        onPressed: () => context.push('/legal/privacy'),
                        child: const Text('Privacy Policy'),
                      ),
                      Text(' ($mortOnboardingAcknowledgementVersion)'),
                    ],
                  ),
                  if (_legalError)
                    const Padding(
                      padding: EdgeInsets.only(top: MortSpacing.xs),
                      child: Text(
                        'Agreement is required to create an account.',
                        style: TextStyle(color: MortColors.danger),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
