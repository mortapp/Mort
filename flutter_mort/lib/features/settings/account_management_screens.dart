import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/account_deletion_repository.dart';

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
