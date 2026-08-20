import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/oauth_flow.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/providers.dart';

class GoogleAuthSection extends ConsumerStatefulWidget {
  const GoogleAuthSection({super.key, this.successRoute = '/account-status'});

  final String successRoute;

  @override
  ConsumerState<GoogleAuthSection> createState() => _GoogleAuthSectionState();
}

class _GoogleAuthSectionState extends ConsumerState<GoogleAuthSection> {
  StreamSubscription<OAuthFlowSnapshot>? _subscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(authRepositoryProvider).oauthStates.listen((
      state,
    ) {
      if (!mounted || state.stage != OAuthFlowStage.success || _navigated) {
        return;
      }
      _navigated = true;
      context.go(widget.successRoute);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _launch() async {
    _navigated = false;
    await ref.read(authRepositoryProvider).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.googleAuthEnabled) return const SizedBox.shrink();
    final repository = ref.watch(authRepositoryProvider);
    final state = ref
        .watch(oauthFlowStateProvider)
        .when(
          data: (value) => value,
          loading: () => repository.oauthState,
          error: (_, _) => const OAuthFlowSnapshot(
            OAuthFlowStage.internalFailure,
            'Google sign-in status is unavailable. Use email and password.',
          ),
        );
    final enabled = !state.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MortSpacing.sm),
              child: Text('or'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Continue with Google',
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: enabled ? _launch : null,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                disabledBackgroundColor: const Color(0xFFF2F2F2),
                disabledForegroundColor: const Color(0xFF5F6368),
                side: const BorderSide(color: Color(0xFF747775)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.isBusy)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    SvgPicture.asset(
                      'assets/branding/google_g.svg',
                      width: 18,
                      height: 18,
                      semanticsLabel: 'Google',
                    ),
                  const SizedBox(width: 12),
                  Text(
                    state.isBusy
                        ? 'Connecting to Google...'
                        : 'Continue with Google',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.message.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: MortSpacing.xs),
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: state.isError
                      ? MortColors.warning
                      : MortColors.textMuted,
                ),
              ),
            ),
          ),
        if (state.canCancel)
          TextButton(
            onPressed: repository.cancelOAuthFlow,
            child: const Text('Cancel Google sign-in'),
          ),
      ],
    );
  }
}

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  const OAuthCallbackScreen({super.key, required this.callbackUri});

  final Uri callbackUri;

  @override
  ConsumerState<OAuthCallbackScreen> createState() =>
      _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  StreamSubscription<OAuthFlowSnapshot>? _subscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(authRepositoryProvider)
        .oauthStates
        .listen(_handleOAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = await ref
          .read(authRepositoryProvider)
          .handleOAuthCallback(widget.callbackUri);
      _handleOAuthState(state);
    });
  }

  void _handleOAuthState(OAuthFlowSnapshot state) {
    if (!mounted || _navigated || state.stage != OAuthFlowStage.success) {
      return;
    }
    _navigated = true;
    context.go('/account-status');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(oauthFlowStateProvider)
        .when(
          data: (value) => value,
          loading: () => const OAuthFlowSnapshot(
            OAuthFlowStage.processingCallback,
            'Verifying the sign-in response...',
          ),
          error: (_, _) => const OAuthFlowSnapshot(
            OAuthFlowStage.internalFailure,
            'The sign-in response could not be completed.',
          ),
        );
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Secure sign-in',
          title: state.isError
              ? 'Sign-in needs attention'
              : 'Finishing sign-in',
          subtitle: state.message,
        ),
        if (state.isBusy)
          const MortLoading(
            label: 'Checking your MORT account...',
            fullScreen: false,
          )
        else if (state.isError)
          MortErrorState(
            title: switch (state.stage) {
              OAuthFlowStage.profileBootstrapFailed =>
                'Account setup needs attention',
              OAuthFlowStage.sessionExchangeFailed =>
                'Session setup needs attention',
              OAuthFlowStage.accountSuspended ||
              OAuthFlowStage.accountDeletionPending =>
                'Account access is restricted',
              _ => 'MORT could not finish sign-in',
            },
            message: state.message,
          ),
        const SizedBox(height: MortSpacing.md),
        if (!state.isBusy)
          MortButton(
            label: 'Back to sign in',
            icon: Icons.arrow_back,
            onPressed: () {
              ref.read(authRepositoryProvider).resetOAuthState();
              context.go('/auth/sign-in');
            },
          ),
      ],
    );
  }
}

class EmailConfirmationCallbackScreen extends ConsumerStatefulWidget {
  const EmailConfirmationCallbackScreen({super.key});

  @override
  ConsumerState<EmailConfirmationCallbackScreen> createState() =>
      _EmailConfirmationCallbackScreenState();
}

class _EmailConfirmationCallbackScreenState
    extends ConsumerState<EmailConfirmationCallbackScreen> {
  Timer? _timeout;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    final confirmed = user?.emailConfirmedAt != null;
    if (confirmed) _timeout?.cancel();

    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Account security',
          title: confirmed
              ? 'Email confirmed'
              : _timedOut
              ? 'Confirmation needs attention'
              : 'Confirming your email',
          subtitle: confirmed
              ? 'Your email is verified. Continue to finish or review your MORT account.'
              : _timedOut
              ? 'This link may be expired or already used. Sign in, or request a fresh confirmation email.'
              : 'MORT is securely checking the confirmation response.',
        ),
        if (!confirmed && !_timedOut)
          const MortLoading(
            label: 'Checking email confirmation...',
            fullScreen: false,
          )
        else if (confirmed)
          const MortSafetyBanner(
            message:
                'Email confirmation does not change your age, role, verification, or marketplace access.',
          )
        else
          const MortErrorState(
            title: 'Email not confirmed here',
            message:
                'No valid confirmation session reached this device. MORT did not change the account.',
          ),
        const SizedBox(height: MortSpacing.md),
        if (confirmed)
          MortButton(
            label: 'Continue to MORT',
            icon: Icons.arrow_forward,
            onPressed: () => context.go('/account-status'),
          )
        else if (_timedOut)
          MortButton(
            label: 'Back to sign in',
            icon: Icons.login,
            onPressed: () => context.go('/auth/sign-in'),
          ),
      ],
    );
  }
}

class PasswordRecoveryCallbackScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryCallbackScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryCallbackScreen> createState() =>
      _PasswordRecoveryCallbackScreenState();
}

class _PasswordRecoveryCallbackScreenState
    extends ConsumerState<PasswordRecoveryCallbackScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  Timer? _timeout;
  bool _timedOut = false;
  bool _busy = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .completePasswordRecovery(_password.text);
      if (!mounted) return;
      setState(() => _completed = true);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final repository = ref.watch(authRepositoryProvider);
    final authorized =
        repository.currentUser != null &&
        repository.canCompletePasswordRecovery;
    if (authorized || _completed) _timeout?.cancel();

    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Account security',
          title: _completed ? 'Password changed' : 'Choose a new password',
          subtitle: _completed
              ? 'Your password was updated and all MORT sessions were signed out.'
              : 'Use a unique password with at least 12 characters.',
        ),
        if (_completed) ...[
          const MortSafetyBanner(
            message:
                'Sign in again on devices you trust. MORT never sends or displays your password.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Sign in with new password',
            icon: Icons.login,
            onPressed: () => context.go('/auth/sign-in'),
          ),
        ] else if (authorized) ...[
          Form(
            key: _form,
            child: Column(
              children: [
                MortTextField(
                  label: 'New password',
                  controller: _password,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: MortValidators.password,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show new password'
                        : 'Hide new password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortTextField(
                  label: 'Confirm new password',
                  controller: _confirmation,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) {
                    final passwordError = MortValidators.password(value);
                    if (passwordError != null) return passwordError;
                    return value == _password.text
                        ? null
                        : 'Passwords do not match.';
                  },
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Show password confirmation'
                        : 'Hide password confirmation',
                    onPressed: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Update password',
            busyLabel: 'Securing account...',
            busy: _busy,
            icon: Icons.lock_reset,
            onPressed: _submit,
          ),
        ] else if (!_timedOut)
          const MortLoading(
            label: 'Verifying password reset link...',
            fullScreen: false,
          )
        else ...[
          const MortErrorState(
            title: 'Reset link not accepted',
            message:
                'This reset link may be expired or already used. Request a fresh link; no password was changed.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Request another reset link',
            icon: Icons.email_outlined,
            onPressed: () => context.go('/auth/forgot-password'),
          ),
        ],
      ],
    );
  }
}

class ConnectedAccountsScreen extends ConsumerStatefulWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  ConsumerState<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState
    extends ConsumerState<ConnectedAccountsScreen> {
  late Future<List<ConnectedAuthIdentity>> _identities;
  StreamSubscription<OAuthFlowSnapshot>? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _identities = ref.read(authRepositoryProvider).getConnectedIdentities();
    _subscription = ref.read(authRepositoryProvider).oauthStates.listen((
      state,
    ) {
      if (!mounted || state.stage != OAuthFlowStage.success) return;
      _refresh();
      MortToast.show(context, 'Your MORT account was updated.');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _identities = ref.read(authRepositoryProvider).getConnectedIdentities();
    });
  }

  Future<void> _linkGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).linkGoogleIdentity();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkApple() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).linkAppleIdentity();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmUnlink() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disconnect Google?'),
            content: const Text(
              'You will need your remaining sign-in method to access MORT. Your profile, jobs, messages, and history will stay on the same account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep connected'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect Google'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmUnlinkApple() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disconnect Apple?'),
            content: const Text(
              'You will need your remaining sign-in method to access MORT. Your profile, jobs, messages, and history will stay on the same account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep connected'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect Apple'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _reauthenticateIfNeeded(bool hasPassword) async {
    final repository = ref.read(authRepositoryProvider);
    if (AuthRepository.isRecentlyAuthenticated(repository.currentUser)) {
      return true;
    }
    if (!hasPassword) {
      MortToast.show(
        context,
        'Sign out and sign back in, then return here within 15 minutes.',
      );
      return false;
    }

    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'MORT password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return false;
    await repository.reauthenticateWithPassword(password);
    return true;
  }

  Future<void> _unlinkGoogle({required bool hasPassword}) async {
    if (_busy || !await _confirmUnlink()) return;
    setState(() => _busy = true);
    try {
      if (!await _reauthenticateIfNeeded(hasPassword)) return;
      await ref.read(authRepositoryProvider).unlinkGoogleIdentity();
      if (!mounted) return;
      MortToast.show(context, 'Google was disconnected.');
      _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlinkApple({required bool hasPassword}) async {
    if (_busy || !await _confirmUnlinkApple()) return;
    setState(() => _busy = true);
    try {
      if (!await _reauthenticateIfNeeded(hasPassword)) return;
      await ref.read(authRepositoryProvider).unlinkAppleIdentity();
      if (!mounted) return;
      MortToast.show(context, 'Apple was disconnected.');
      _refresh();
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
          eyebrow: 'Account security',
          title: 'Connected accounts',
          subtitle:
              'Manage how you sign in. Google and Apple do not set your MORT role, age, verification, or marketplace access.',
        ),
        FutureBuilder<List<ConnectedAuthIdentity>>(
          future: _identities,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Could not load connected accounts',
                message: userFacingError(snapshot.error!),
              );
            }
            final identities = snapshot.data ?? const [];
            final googleIdentities = identities
                .where((item) => item.isGoogle)
                .toList(growable: false);
            final google = googleIdentities.isEmpty
                ? null
                : googleIdentities.first;
            final appleIdentities = identities
                .where((item) => item.isApple)
                .toList(growable: false);
            final apple = appleIdentities.isEmpty
                ? null
                : appleIdentities.first;
            final password = identities.any((item) => item.isPassword);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IdentityCard(
                  title: 'Email and password',
                  connected: password,
                  subtitle: password
                      ? 'Available as a sign-in method.'
                      : 'No password identity is connected.',
                ),
                const SizedBox(height: MortSpacing.sm),
                _IdentityCard(
                  title: 'Google',
                  connected: google != null,
                  subtitle: google == null
                      ? 'Not connected.'
                      : [
                          if (google.email?.isNotEmpty == true) google.email!,
                          if (google.createdAt != null)
                            'Linked ${_formatDate(google.createdAt!)}',
                        ].join(' - '),
                ),
                const SizedBox(height: MortSpacing.md),
                if (google == null)
                  MortButton(
                    label: 'Connect Google',
                    busy: _busy,
                    busyLabel: 'Opening Google...',
                    icon: Icons.add_link,
                    style: MortButtonStyle.secondary,
                    onPressed: AppConfig.googleAuthEnabled ? _linkGoogle : null,
                  )
                else
                  MortButton(
                    label: 'Disconnect Google',
                    busy: _busy,
                    icon: Icons.link_off,
                    style: MortButtonStyle.danger,
                    onPressed: identities.length > 1
                        ? () => _unlinkGoogle(hasPassword: password)
                        : null,
                  ),
                if (!AppConfig.googleAuthEnabled && google == null)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.xs),
                    child: Text(
                      'Google linking is awaiting owner configuration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MortColors.textMuted),
                    ),
                  ),
                if (google != null && identities.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.xs),
                    child: Text(
                      'Add another sign-in method before disconnecting your only identity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MortColors.textMuted),
                    ),
                  ),
                const SizedBox(height: MortSpacing.md),
                _IdentityCard(
                  title: 'Apple',
                  connected: apple != null,
                  subtitle: apple == null
                      ? 'Not connected.'
                      : [
                          if (apple.email?.isNotEmpty == true) apple.email!,
                          if (apple.createdAt != null)
                            'Linked ${_formatDate(apple.createdAt!)}',
                        ].join(' - '),
                ),
                const SizedBox(height: MortSpacing.md),
                if (apple == null)
                  MortButton(
                    label: 'Connect Apple',
                    busy: _busy,
                    busyLabel: 'Opening Apple...',
                    icon: Icons.add_link,
                    style: MortButtonStyle.secondary,
                    onPressed: AppConfig.appleAuthEnabled ? _linkApple : null,
                  )
                else
                  MortButton(
                    label: 'Disconnect Apple',
                    busy: _busy,
                    icon: Icons.link_off,
                    style: MortButtonStyle.danger,
                    onPressed: identities.length > 1
                        ? () => _unlinkApple(hasPassword: password)
                        : null,
                  ),
                if (!AppConfig.appleAuthEnabled && apple == null)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.xs),
                    child: Text(
                      'Apple linking is awaiting owner configuration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MortColors.textMuted),
                    ),
                  ),
                if (apple != null && identities.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.xs),
                    child: Text(
                      'Add another sign-in method before disconnecting your only identity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MortColors.textMuted),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Connecting or disconnecting Google or Apple never creates admin access and never changes your role, DOB, verification, jobs, payments, or safety history.',
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.title,
    required this.connected,
    required this.subtitle,
  });

  final String title;
  final bool connected;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          connected ? Icons.verified_user : Icons.link_off,
          color: connected ? MortColors.neon : MortColors.textMuted,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: MortBadge(
          label: connected ? 'Connected' : 'Not connected',
          color: connected ? MortColors.neon : MortColors.textMuted,
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}
