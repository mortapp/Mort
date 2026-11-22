import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_startup.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/reviewer/reviewer_session.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/account_deletion_repository.dart';
import '../monetization/providers/revenuecat_providers.dart';

class SecuritySessionsScreen extends ConsumerStatefulWidget {
  const SecuritySessionsScreen({super.key});

  @override
  ConsumerState<SecuritySessionsScreen> createState() =>
      _SecuritySessionsScreenState();
}

class _SecuritySessionsScreenState
    extends ConsumerState<SecuritySessionsScreen> {
  bool _busy = false;

  Future<bool> _confirm({required bool global}) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: !_busy,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              global ? 'Sign out on every device?' : 'Sign out on this device?',
            ),
            content: Text(
              global
                  ? 'This revokes MORT refresh sessions on your other phones and browsers too. You will need to sign in again everywhere.'
                  : 'This removes the MORT session and user-specific cached state from this device. Other devices stay signed in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(global ? 'Sign out everywhere' : 'Sign out'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _signOut({required bool global}) async {
    if (_busy || !await _confirm(global: global)) return;
    setState(() => _busy = true);
    Object? remoteFailure;
    final auth = ref.read(authRepositoryProvider);
    try {
      if (global) {
        await auth.signOutGlobal();
      } else {
        await auth.signOutLocal();
      }
    } catch (error) {
      remoteFailure = error;
    } finally {
      await ref.read(revenueCatServiceProvider).logOut();
      ref.read(reviewerSessionProvider).exit();
      invalidateUserScopedProviders(ref);
      ref.read(authStartupProvider).markSignedOut();
    }

    if (!mounted) return;
    if (remoteFailure != null && global) {
      MortToast.show(
        context,
        'This device signed out, but MORT could not confirm every-device revocation. Reconnect, sign in, and retry global sign-out.',
      );
    }
    context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: MortScreen(
        children: [
          const MortHeader(
            eyebrow: 'Account security',
            title: 'Security and sessions',
            subtitle:
                'Control this device separately from every other MORT session.',
          ),
          const MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This device'),
                SizedBox(height: MortSpacing.xs),
                Text(
                  'Session tokens use encrypted device storage. Theme, accessibility, and optional device-lock preferences remain after sign-out.',
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Sign out on this device',
            busyLabel: 'Signing out...',
            icon: Icons.logout,
            busy: _busy,
            onPressed: () => _signOut(global: false),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Sign out on all devices',
            busyLabel: 'Revoking sessions...',
            icon: Icons.phonelink_erase,
            style: MortButtonStyle.danger,
            busy: _busy,
            onPressed: () => _signOut(global: true),
          ),
          const SizedBox(height: MortSpacing.lg),
          const MortActionRow(
            actions: [
              MortAction(
                label: 'Review active sessions',
                icon: Icons.devices,
                route: '/settings/active-sessions',
              ),
              MortAction(
                label: 'Optional device lock',
                icon: Icons.fingerprint,
                route: '/settings/device-security',
              ),
              MortAction(
                label: 'Account deletion',
                icon: Icons.delete_outline,
                route: '/settings/account-deletion',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AccountDeletionRequestScreen extends ConsumerStatefulWidget {
  const AccountDeletionRequestScreen({super.key});

  @override
  ConsumerState<AccountDeletionRequestScreen> createState() =>
      _AccountDeletionRequestScreenState();
}

class _AccountDeletionRequestScreenState
    extends ConsumerState<AccountDeletionRequestScreen> {
  final _confirmation = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _useRecentSignIn = false;
  AccountDeletionRequest? _request;
  String? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmation.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final request = await ref
          .read(accountDeletionRepositoryProvider)
          .getCurrentRequest();
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) {
        setState(() => _loadFailed = true);
        MortToast.show(context, userFacingError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_canVerify || _confirmation.text.trim() != 'DELETE') return;
    setState(() => _busy = true);
    try {
      await _reauthenticateIfNeeded();
      if (!mounted) return;
      final repository = ref.read(accountDeletionRepositoryProvider);
      final request = await repository.requestDeletion();
      if (!mounted) return;
      _confirmation.clear();
      _password.clear();
      setState(() {
        _request = request;
        _receipt = null;
      });
      await _issueReceipt(repository, request);
    } catch (error) {
      if (mounted) _showVerificationError(error);
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy || !_canVerify) return;
    setState(() => _busy = true);
    try {
      await _reauthenticateIfNeeded();
      if (!mounted) return;
      final request = await ref
          .read(accountDeletionRepositoryProvider)
          .cancelDeletion();
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) _showVerificationError(error);
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  bool get _canVerify => _useRecentSignIn || _password.text.isNotEmpty;

  Future<void> _reauthenticateIfNeeded() async {
    // The RPC verifies the actual GoTrue session's age, identity and MFA.
    // This option lets users with an OAuth-only account initiate in the app.
    if (!_useRecentSignIn) {
      await ref
          .read(authRepositoryProvider)
          .reauthenticateWithPassword(_password.text);
    }
  }

  void _showVerificationError(Object error) {
    if (error is MortCodedError &&
        error.code == 'recent_reauthentication_required') {
      MortToast.show(
        context,
        'Sign out and sign in again, complete any required verification, then return here.',
      );
      return;
    }
    MortToast.show(context, userFacingError(error));
  }

  Future<void> _issueReceipt(
    AccountDeletionRepository repository,
    AccountDeletionRequest request,
  ) async {
    try {
      final code = await repository.issueReceipt(request.id);
      if (mounted && code != null) setState(() => _receipt = code);
      if (mounted && code == null) {
        MortToast.show(context, 'A status receipt could not be issued.');
      }
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'A status receipt could not be issued.');
      }
    }
  }

  Future<void> _renewReceipt(AccountDeletionRequest request) async {
    if (_busy || !_canVerify || !request.canIssueReceipt) return;
    setState(() => _busy = true);
    try {
      await _reauthenticateIfNeeded();
      if (!mounted) return;
      await _issueReceipt(ref.read(accountDeletionRepositoryProvider), request);
    } catch (error) {
      if (mounted) _showVerificationError(error);
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openWeb() async {
    final uri = AppConfig.accountDeletionWebUri;
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Do not send account credentials or a status receipt in a browser URL.
    }
    if (mounted) MortToast.show(context, 'Could not open the deletion page.');
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final canSubmit = request == null || request.canSubmitAnother;
    final canCancel = request?.canCancel ?? false;
    final canRenew =
        request != null && request.canIssueReceipt && _receipt == null;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Account control',
          title: 'Request account deletion',
          subtitle:
              'Submit a verified request to delete your MORT account and ordinary profile data. This does not require contacting support first.',
        ),
        const MortSafetyBanner(
          message:
              'MORT may retain narrowly necessary safety, fraud, dispute, security, and legal records after removing ordinary account data. Retained records stay access restricted.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_loading)
          const MortLoading(
            label: 'Checking deletion status...',
            fullScreen: false,
          )
        else if (_loadFailed) ...[
          const Text(
            'If your account requires additional sign-in verification, '
            'complete it before retrying.',
          ),
          MortButton(label: 'Retry loading status', onPressed: _load),
        ] else ...[
          if (request != null)
            MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request status: ${request.status.replaceAll('_', ' ')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  Text('Requested ${request.requestedAt.toLocal()}'),
                  if (request.retentionSummary?.isNotEmpty == true) ...[
                    const SizedBox(height: MortSpacing.sm),
                    Text(request.retentionSummary!),
                  ],
                ],
              ),
            ),
          if (request != null) ...[
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Refresh request status',
              style: MortButtonStyle.secondary,
              onPressed: _busy ? null : _load,
            ),
          ],
          if (_receipt != null) ...[
            const SizedBox(height: MortSpacing.md),
            const Text(
              'Save this private receipt code to check status on the MORT deletion website. It expires after 90 days.',
            ),
            SelectableText(_receipt!),
          ],
          if (canSubmit || canCancel || canRenew) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use my recent sign-in'),
              subtitle: const Text(
                'Use this if you just signed in, including with Apple or Google. '
                'MORT verifies your sign-in before accepting a request.',
              ),
              value: _useRecentSignIn,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _password.clear();
                      _useRecentSignIn = value;
                    }),
            ),
            if (!_useRecentSignIn)
              MortTextField(
                label: 'Confirm your password',
                controller: _password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: MortSpacing.md),
          ],
          if (canCancel)
            MortButton(
              label: 'Cancel pending request',
              icon: Icons.undo,
              style: MortButtonStyle.secondary,
              busy: _busy,
              onPressed: _canVerify ? _cancel : null,
            ),
          if (canRenew)
            MortButton(
              label: 'Issue new status receipt',
              style: MortButtonStyle.secondary,
              busy: _busy,
              onPressed: _canVerify ? () => _renewReceipt(request) : null,
            ),
          if (canSubmit) ...[
            const SizedBox(height: MortSpacing.md),
            MortTextField(
              label: 'Type DELETE to confirm',
              controller: _confirmation,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Submit deletion request',
              icon: Icons.delete_outline,
              style: MortButtonStyle.danger,
              busy: _busy,
              onPressed: _confirmation.text.trim() == 'DELETE' && _canVerify
                  ? _submit
                  : null,
            ),
          ],
        ],
        if (AppConfig.accountDeletionWebUri != null) ...[
          const SizedBox(height: MortSpacing.md),
          const Text(
            'No password? Use an email verification link on the MORT deletion website.',
          ),
          MortButton(
            label: 'Open account deletion website',
            style: MortButtonStyle.secondary,
            onPressed: _openWeb,
          ),
        ],
      ],
    );
  }
}
