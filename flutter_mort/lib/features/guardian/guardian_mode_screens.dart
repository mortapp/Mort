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
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(
            completedStep: 'guardian',
            preferences: const {'safety_setup_choice': 'configured'},
          );
      if (!mounted) return;
      setState(() => _inviteCode = result['invite_code'] as String?);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
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
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(
            completedStep: 'guardian',
            preferences: const {'safety_setup_choice': 'declined_optional'},
          );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/preferences');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueForNonTeen() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(
            completedStep: 'guardian',
            preferences: const {'safety_setup_choice': 'review_later'},
          );
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/preferences');
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
      return MortScreen(
        children: [
          const MortHeader(
            eyebrow: 'Guardian Mode',
            title: 'Guardian setup is optional',
            subtitle:
                'Guardian linking is designed for teen accounts. You can manage your own Guardian Mode connections later in Settings.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Continue to preferences',
                busy: _busy,
                onPressed: _continueForNonTeen,
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
        const MortStepper(current: 8, total: 12),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Guardian Mode is optional. Skipping this will not prevent you from browsing or applying for jobs. Report, block, and Safety Ping remain available either way.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_inviteCode != null)
          MortCard(
            color: MortColors.accent.withValues(alpha: 0.08),
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
                route: '/onboarding/preferences',
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
          subtitle: 'Optional linking with clear privacy boundaries.',
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
                    ? MortColors.accent
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
        const MortSectionTitle(title: 'Connections'),
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
  });

  final Map<String, dynamic> row;
  final bool isTeen;
  final bool busy;
  final VoidCallback onUnlink;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'unknown';
    final guardian = row['guardian'];
    final teen = row['teen'];
    final person = isTeen ? guardian : teen;
    final name = person is Map ? person['display_name']?.toString() : null;
    final personId = person is Map ? person['id']?.toString() : null;
    final avatarPath = person is Map ? person['avatar_path']?.toString() : null;
    final accepted = DateTime.tryParse(
      (row['guardian_consent_at'] ?? '').toString(),
    );
    final isPending = status == 'pending';
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
                  name ?? (isPending ? 'Invite pending' : 'Guardian link'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          MortBadge(label: status.replaceAll('_', ' ')),
          if (accepted != null) Text('Linked ${accepted.toLocal()}'),
          const SizedBox(height: MortSpacing.sm),
          MortActionRow(
            actions: isPending && isTeen
                ? [
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
        ],
      ),
    );
  }
}
