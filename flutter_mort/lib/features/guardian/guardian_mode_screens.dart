import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../profile/profile_avatar_widgets.dart';

class GuardianOptionalOnboardingScreen extends ConsumerStatefulWidget {
  const GuardianOptionalOnboardingScreen({super.key});

  @override
  ConsumerState<GuardianOptionalOnboardingScreen> createState() =>
      _GuardianOptionalOnboardingScreenState();
}

class _GuardianOptionalOnboardingScreenState
    extends ConsumerState<GuardianOptionalOnboardingScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _inviteCode;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invite({bool includeEmail = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(guardianRepositoryProvider)
          .createInvite(email: includeEmail ? _email.text.trim() : null);
      setState(() => _inviteCode = result['invite_code'] as String?);
      ref.invalidate(currentProfileProvider);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(guardianRepositoryProvider).skipSetup();
      ref.invalidate(currentProfileProvider);
      if (mounted) context.go('/onboarding/safety');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    if (profile != null && !profile.isTeen) {
      return const MortScreen(
        children: [
          MortHeader(
            eyebrow: 'Guardian Mode',
            title: 'Guardian setup is optional',
            subtitle:
                'Guardian linking is designed for teen accounts. You can manage your own Guardian Mode connections later in Settings.',
          ),
          SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Continue to safety',
                route: '/onboarding/safety',
              ),
            ],
          ),
        ],
      );
    }

    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Optional safety feature',
          title: 'Add a guardian? Optional.',
          subtitle:
              'Guardian Mode can share selected safety alerts and check-ins with someone you trust. You can skip this and set it up later.',
        ),
        const MortStepper(current: 7, total: 9),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Guardian Mode is optional. Skipping this will not prevent you from browsing or applying for jobs. Report, block, and Safety Ping remain available either way.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_inviteCode != null)
          MortCard(
            color: MortColors.neon.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guardian invite code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.xs),
                SelectableText(
                  _inviteCode!,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MortSpacing.xs),
                const Text(
                  'Share this code directly with the guardian you trust. MORT stores only a secure hash of the code.',
                ),
              ],
            ),
          ),
        if (_inviteCode == null) ...[
          MortTextField(
            label: 'Guardian email (optional)',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hint: 'guardian@example.com',
          ),
          const SizedBox(height: MortSpacing.sm),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Link a guardian now',
                icon: Icons.link,
                busy: _busy,
                onPressed: () => _invite(),
              ),
              MortAction(
                label: 'Send an invite',
                icon: Icons.mail_outline,
                busy: _busy,
                onPressed: () => _invite(includeEmail: true),
              ),
              MortAction(
                label: 'Use an invite code',
                icon: Icons.pin_outlined,
                route: '/settings/guardian-mode',
              ),
            ],
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            if (_inviteCode != null)
              const MortAction(
                label: 'Continue',
                icon: Icons.arrow_forward,
                route: '/onboarding/safety',
              ),
            MortAction(
              label: 'Skip for now',
              icon: Icons.skip_next,
              busy: _busy,
              onPressed: _skip,
              style: MortButtonStyle.ghost,
            ),
          ],
        ),
      ],
    );
  }
}

class GuardianModeScreen extends ConsumerStatefulWidget {
  const GuardianModeScreen({super.key});

  @override
  ConsumerState<GuardianModeScreen> createState() => _GuardianModeScreenState();
}

class _GuardianModeScreenState extends ConsumerState<GuardianModeScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(currentProfileProvider);
      if (mounted) MortToast.show(context, success);
      setState(() {});
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(String linkId) async {
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Unlink this guardian?',
      message:
          'They will stop receiving new Guardian Mode updates. Your MORT account and safety tools will continue working.',
      confirmLabel: 'Unlink',
    );
    if (!confirmed) return;
    await _run(
      () => ref.read(guardianRepositoryProvider).unlink(linkId),
      'Guardian Mode unlinked. Your account remains active.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final connections = ref.watch(guardianRepositoryProvider).listConnections();
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Settings',
          title: 'Guardian Mode',
          subtitle:
              'Optional linking, selected safety alerts, and clear privacy controls.',
        ),
        const MortSafetyBanner(
          message:
              'Basic Guardian Mode is free. Guardians do not receive unrestricted access to private messages. Report, block, Safety Ping, and account access remain available without a link.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MortSpacing.xs),
              MortBadge(
                label: (profile?.guardianSetupStatus ?? 'not_started')
                    .replaceAll('_', ' '),
                color: profile?.guardianSetupStatus == 'linked'
                    ? MortColors.neon
                    : MortColors.safetyBlue,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (profile?.isTeen == true) ...[
          MortTextField(
            label: 'Guardian email (optional)',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Create guardian invite',
            icon: Icons.person_add_alt_1,
            busy: _busy,
            onPressed: () => _run(() async {
              final result = await ref
                  .read(guardianRepositoryProvider)
                  .createInvite(email: _email.text.trim());
              if (mounted) {
                await _showCode(result['invite_code'] as String?);
              }
            }, 'Guardian invite created.'),
          ),
        ],
        if (profile?.isGuardian == true) ...[
          MortTextField(
            label: 'Guardian invite code',
            controller: _code,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Link with code',
            icon: Icons.link,
            busy: _busy,
            onPressed: () => _run(
              () async =>
                  ref.read(guardianRepositoryProvider).acceptInvite(_code.text),
              'Guardian Mode linked.',
            ),
          ),
        ],
        const MortSectionTitle(
          title: 'Connections',
          subtitle: 'Only people in this list can receive selected updates.',
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: connections,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Guardian links unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return const MortEmptyState(
                title: 'No guardian linked',
                message:
                    'Guardian Mode is optional. You can create or enter an invite whenever you are ready.',
              );
            }
            return Column(
              children: [
                for (final row in rows) ...[
                  _GuardianConnectionCard(
                    row: row,
                    isTeen: profile?.isTeen == true,
                    busy: _busy,
                    onUnlink: () => _unlink(row['id'].toString()),
                    onCancel: () => _run(
                      () async => ref
                          .read(guardianRepositoryProvider)
                          .cancelInvite(row['id'].toString()),
                      'Invitation canceled.',
                    ),
                    onResend: () => _run(() async {
                      final result = await ref
                          .read(guardianRepositoryProvider)
                          .resendInvite(row['id'].toString());
                      if (mounted) {
                        await _showCode(result['invite_code'] as String?);
                      }
                    }, 'Invitation renewed.'),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const MortSectionTitle(title: 'What can be shared'),
        const _GuardianChecklist(
          items: [
            'Safety Ping alerts and account safety warnings',
            'Job check-in status and accepted job summaries',
            'Optional weekly activity summary',
            'Optional approval requests only for jobs that explicitly request them',
            'Private message contents are not shared by default',
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        const MortActionRow(
          actions: [
            MortAction(
              label: 'How Guardian Mode works',
              icon: Icons.help_outline,
              route: '/legal/guardian-guide',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showCode(String? code) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardian invite code'),
        content: SelectableText(code ?? 'Invite created'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _GuardianChecklist extends StatelessWidget {
  const _GuardianChecklist({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MortSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardianConnectionCard extends StatelessWidget {
  const _GuardianConnectionCard({
    required this.row,
    required this.isTeen,
    required this.busy,
    required this.onUnlink,
    required this.onCancel,
    required this.onResend,
  });

  final Map<String, dynamic> row;
  final bool isTeen;
  final bool busy;
  final VoidCallback onUnlink;
  final VoidCallback onCancel;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final guardian = row['guardian'];
    final teen = row['teen'];
    final person = isTeen ? guardian : teen;
    final name = person is Map ? person['display_name']?.toString() : null;
    final personId = person is Map ? person['id']?.toString() : null;
    final avatarPath = person is Map ? person['avatar_path']?.toString() : null;
    final accepted = DateTime.tryParse((row['accepted_at'] ?? '').toString());
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (personId != null)
                ProfileAvatarView(
                  profileId: personId,
                  avatarPath: avatarPath,
                  fallbackLabel: name ?? 'Guardian link',
                  radius: 24,
                ),
              if (personId != null) const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Text(
                  name ??
                      (status == 'invited'
                          ? 'Invite pending'
                          : 'Guardian link'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          MortBadge(label: status.replaceAll('_', ' ')),
          if (row['relationship'] != null) Text(row['relationship'].toString()),
          if (accepted != null) Text('Linked ${accepted.toLocal()}'),
          const SizedBox(height: MortSpacing.sm),
          MortActionRow(
            actions: status == 'invited' && isTeen
                ? [
                    MortAction(
                      label: 'Resend invitation',
                      icon: Icons.refresh,
                      busy: busy,
                      onPressed: onResend,
                    ),
                    MortAction(
                      label: 'Cancel invitation',
                      icon: Icons.cancel_outlined,
                      busy: busy,
                      onPressed: onCancel,
                      style: MortButtonStyle.danger,
                    ),
                  ]
                : status == 'active'
                ? [
                    MortAction(
                      label: 'Unlink guardian',
                      icon: Icons.link_off,
                      busy: busy,
                      onPressed: onUnlink,
                      style: MortButtonStyle.danger,
                    ),
                  ]
                : const [],
          ),
          if (status == 'active' && isTeen) ...[
            const SizedBox(height: MortSpacing.md),
            _GuardianPreferenceEditor(
              linkId: row['id'].toString(),
              rawPreferences: row['guardian_preferences'],
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardianPreferenceEditor extends ConsumerStatefulWidget {
  const _GuardianPreferenceEditor({
    required this.linkId,
    required this.rawPreferences,
  });

  final String linkId;
  final Object? rawPreferences;

  @override
  ConsumerState<_GuardianPreferenceEditor> createState() =>
      _GuardianPreferenceEditorState();
}

class _GuardianPreferenceEditorState
    extends ConsumerState<_GuardianPreferenceEditor> {
  late bool _safetyPing;
  late bool _checkin;
  late bool _acceptedSummary;
  late bool _safetyWarnings;
  late bool _weeklyDigest;
  late bool _jobApprovals;
  bool _saving = false;

  Map<String, dynamic> get _preferences {
    final raw = widget.rawPreferences;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return const {};
  }

  @override
  void initState() {
    super.initState();
    final values = _preferences;
    _safetyPing = values['safety_ping_alerts'] != false;
    _checkin = values['job_checkin_alerts'] != false;
    _acceptedSummary = values['accepted_job_summary'] != false;
    _safetyWarnings = values['safety_warning_alerts'] != false;
    _weeklyDigest = values['weekly_digest'] == true;
    _jobApprovals = values['optional_job_approval_enabled'] == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(guardianRepositoryProvider)
          .updatePreferences(
            widget.linkId,
            safetyPingAlerts: _safetyPing,
            jobCheckinAlerts: _checkin,
            acceptedJobSummary: _acceptedSummary,
            safetyWarningAlerts: _safetyWarnings,
            weeklyDigest: _weeklyDigest,
            optionalJobApprovalEnabled: _jobApprovals,
          );
      if (mounted) MortToast.show(context, 'Shared-alert settings saved.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('Manage shared alerts'),
      subtitle: const Text('The teen controls these categories.'),
      children: [
        _toggle(
          'Safety Ping alerts',
          _safetyPing,
          (value) => _safetyPing = value,
        ),
        _toggle('Job check-in status', _checkin, (value) => _checkin = value),
        _toggle(
          'Accepted job summary',
          _acceptedSummary,
          (value) => _acceptedSummary = value,
        ),
        _toggle(
          'Account safety warnings',
          _safetyWarnings,
          (value) => _safetyWarnings = value,
        ),
        _toggle(
          'Weekly activity summary',
          _weeklyDigest,
          (value) => _weeklyDigest = value,
        ),
        _toggle(
          'Optional job approval requests',
          _jobApprovals,
          (value) => _jobApprovals = value,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: MortSpacing.sm),
          child: Text(
            'Private message contents are not shared by default. Turning off an alert does not remove report, block, or Safety Ping from the teen account.',
          ),
        ),
        MortButton(
          label: 'Save shared-alert settings',
          icon: Icons.save_outlined,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> update) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(label),
      onChanged: (next) => setState(() => update(next)),
    );
  }
}
