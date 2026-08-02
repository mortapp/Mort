import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_startup.dart';
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
  AccountDeletionRequest? _request;

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
    try {
      final request = await ref
          .read(accountDeletionRepositoryProvider)
          .getCurrentRequest();
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _confirmation.text.trim() != 'DELETE') return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .reauthenticateWithPassword(_password.text);
      final request = await ref
          .read(accountDeletionRepositoryProvider)
          .requestDeletion();
      if (!mounted) return;
      _confirmation.clear();
      _password.clear();
      setState(() => _request = request);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await ref
          .read(accountDeletionRepositoryProvider)
          .cancelDeletion();
      if (mounted) setState(() => _request = request);
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
        else if (_request != null) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request status: ${_request!.status.replaceAll('_', ' ')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.sm),
                Text('Requested ${_request!.requestedAt.toLocal()}'),
                if (_request!.retentionSummary?.isNotEmpty == true) ...[
                  const SizedBox(height: MortSpacing.sm),
                  Text(_request!.retentionSummary!),
                ],
              ],
            ),
          ),
          if (_request!.canCancel) ...[
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Cancel pending request',
              icon: Icons.undo,
              style: MortButtonStyle.secondary,
              busy: _busy,
              onPressed: _cancel,
            ),
          ],
        ] else ...[
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
            onPressed:
                _confirmation.text.trim() == 'DELETE' &&
                    _password.text.isNotEmpty
                ? _submit
                : null,
          ),
        ],
      ],
    );
  }
}
