import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

final partnerStaffContextsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref.read(missionPilotRepositoryProvider).partnerStaffContexts();
  },
);

class PartnerStaffHomeScreen extends ConsumerWidget {
  const PartnerStaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contexts = ref.watch(partnerStaffContextsProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Approved organizations',
          title: 'Partner workspace',
          subtitle:
              'Access is limited to organization-bound participants and expressly granted staff permissions.',
        ),
        const MortSafetyBanner(
          message:
              'Partner access never includes unrestricted messages, raw identity documents, earnings, housing status, or unrelated users.',
        ),
        const SizedBox(height: MortSpacing.md),
        contexts.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Partner access unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(partnerStaffContextsProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const MortEmptyState(
                title: 'No active partner assignment',
                message:
                    'This account has no active organization staff assignment. Contact an authorized MORT administrator if that is unexpected.',
                action: MortActionRow(
                  actions: [
                    MortAction(
                      label: 'Contact support',
                      icon: Icons.support_agent,
                      route: '/support',
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items) ...[
                  _PartnerOrganizationCard(contextData: item),
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

class _PartnerOrganizationCard extends StatelessWidget {
  const _PartnerOrganizationCard({required this.contextData});

  final Map<String, dynamic> contextData;

  @override
  Widget build(BuildContext context) {
    final organizationId = contextData['organization_id']?.toString() ?? '';
    final permissions = (contextData['permissions'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final canView = permissions.contains('view_connected_participants');
    final canInvite = permissions.contains('manage_partner_invites');
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contextData['organization_name']?.toString() ??
                'Approved organization',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'Staff role: ${_humanize(contextData['staff_role'])}. Access is logged and expires with the staff assignment.',
          ),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              for (final permission in permissions)
                MortBadge(
                  label: _humanize(permission),
                  color: MortColors.safetyBlue,
                ),
            ],
          ),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              if (canView)
                MortAction(
                  label: 'Connected participants',
                  icon: Icons.groups_outlined,
                  route: '/partner/participants/$organizationId',
                ),
              if (canInvite)
                MortAction(
                  label: 'Scoped invitations',
                  icon: Icons.mark_email_read_outlined,
                  route: '/partner/invites/$organizationId',
                ),
              const MortAction(
                label: 'Report a safety concern',
                icon: Icons.report_outlined,
                route: '/support',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PartnerParticipantsScreen extends ConsumerStatefulWidget {
  const PartnerParticipantsScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<PartnerParticipantsScreen> createState() =>
      _PartnerParticipantsScreenState();
}

class _PartnerParticipantsScreenState
    extends ConsumerState<PartnerParticipantsScreen> {
  late Future<_PartnerParticipantData> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repository = ref.read(missionPilotRepositoryProvider);
    _future =
        Future.wait([
          repository.partnerConnectedParticipants(widget.organizationId),
          repository.organizationAttestations(widget.organizationId),
        ]).then(
          (results) => _PartnerParticipantData(
            participants: results[0],
            attestations: results[1],
          ),
        );
  }

  void _refresh() {
    setState(_reload);
  }

  Future<void> _attest(Map<String, dynamic> participant) async {
    var factType = 'partner_program_participation';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record a limited fact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Participant: ${participant['display_name'] ?? 'Connected participant'}',
              ),
              const SizedBox(height: MortSpacing.md),
              MortDropdown<String>(
                label: 'Fact observed',
                value: factType,
                items: const {
                  'partner_program_participation': 'Program participation',
                  'person_appeared_before_partner': 'Appeared before staff',
                  'school_or_program_affiliation': 'Current affiliation',
                  'approximate_age_band_eligible': 'Eligible age band',
                },
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => factType = value);
                  }
                },
              ),
              const SizedBox(height: MortSpacing.sm),
              const Text(
                'This does not establish legal identity, document authenticity, address, account ownership, or safety.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm fact'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final subjectId = participant['user_id']?.toString() ?? '';
    setState(() => _busyId = subjectId);
    try {
      await ref
          .read(missionPilotRepositoryProvider)
          .submitPartnerAttestation(
            organizationId: widget.organizationId,
            subjectUserId: subjectId,
            factType: factType,
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 90)),
          );
      if (mounted) MortToast.show(context, 'Limited fact recorded.');
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revoke(Map<String, dynamic> attestation) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke attestation'),
        content: MortTextArea(
          label: 'Reason',
          controller: reasonController,
          hint: 'Explain what changed (8 characters minimum)',
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length >= 8) Navigator.pop(dialogContext, value);
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final id = attestation['id']?.toString() ?? '';
    setState(() => _busyId = id);
    try {
      await ref
          .read(missionPilotRepositoryProvider)
          .revokePartnerAttestation(attestationId: id, reason: reason);
      if (mounted) MortToast.show(context, 'Attestation revoked.');
      if (mounted) _refresh();
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
          eyebrow: 'Partner workspace',
          title: 'Connected participants',
          subtitle:
              'Only participants linked to this organization are shown. Private job messages and financial details are excluded.',
        ),
        FutureBuilder<_PartnerParticipantData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Roster unavailable',
                message: userFacingError(snapshot.error!),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final data = snapshot.data!;
            if (data.participants.isEmpty) {
              return MortEmptyState(
                title: 'No connected participants',
                message:
                    'This organization has no pending or authorized participants.',
                action: MortButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final participant in data.participants) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant['display_name']?.toString() ??
                              'Connected participant',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          'Role: ${_humanize(participant['role'])}. Enrollment: ${_humanize(participant['enrollment_status'])}.',
                        ),
                        const SizedBox(height: MortSpacing.md),
                        MortActionRow(
                          actions: [
                            MortAction(
                              label: 'Record limited fact',
                              icon: Icons.fact_check_outlined,
                              busy:
                                  _busyId == participant['user_id']?.toString(),
                              onPressed: () => _attest(participant),
                            ),
                            MortAction(
                              label: 'Report concern',
                              icon: Icons.report_outlined,
                              route: '/report/user/${participant['user_id']}',
                              style: MortButtonStyle.danger,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                const SizedBox(height: MortSpacing.md),
                Text(
                  'Recent attestations',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MortSpacing.sm),
                if (data.attestations.isEmpty)
                  const MortEmptyState(
                    title: 'No attestations',
                    message: 'No limited facts have been recorded here.',
                  )
                else
                  for (final attestation in data.attestations) ...[
                    MortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _humanize(attestation['fact_type']),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: MortSpacing.xs),
                          Text(
                            attestation['attestation_statement']?.toString() ??
                                'Limited partner fact',
                          ),
                          const SizedBox(height: MortSpacing.xs),
                          MortBadge(
                            label: _humanize(attestation['status']),
                            color: attestation['status'] == 'active'
                                ? MortColors.neon
                                : MortColors.textMuted,
                          ),
                          if (attestation['status'] == 'active') ...[
                            const SizedBox(height: MortSpacing.md),
                            MortButton(
                              label: 'Revoke attestation',
                              icon: Icons.cancel_outlined,
                              style: MortButtonStyle.danger,
                              busy: _busyId == attestation['id']?.toString(),
                              onPressed: () => _revoke(attestation),
                            ),
                          ],
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

class PartnerInvitesScreen extends ConsumerStatefulWidget {
  const PartnerInvitesScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<PartnerInvitesScreen> createState() =>
      _PartnerInvitesScreenState();
}

class _PartnerInvitesScreenState extends ConsumerState<PartnerInvitesScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _creating = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref
        .read(missionPilotRepositoryProvider)
        .partnerInvites(widget.organizationId);
  }

  void _refresh() => setState(_reload);

  Future<void> _create() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create one-use teen invitation?'),
        content: const Text(
          'The code expires in 7 days, can be used once, and only establishes an organization relationship. It does not verify identity or guarantee account eligibility.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _creating = true);
    try {
      final result = await ref
          .read(missionPilotRepositoryProvider)
          .createPartnerInvite(
            organizationId: widget.organizationId,
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Invitation code - shown once'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                result['invite_code']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.md),
              const Text(
                'Share only with the intended participant. MORT stores only a one-way hash and cannot show this code again.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('I saved it securely'),
            ),
          ],
        ),
      );
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> invite) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke invitation'),
        content: MortTextArea(
          label: 'Reason',
          controller: reasonController,
          hint: 'Explain why this code should stop working',
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length >= 8) Navigator.pop(dialogContext, value);
            },
            child: const Text('Revoke code'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    final id = invite['id']?.toString() ?? '';
    setState(() => _busyId = id);
    try {
      await ref
          .read(missionPilotRepositoryProvider)
          .revokePartnerInvite(codeId: id, reason: reason);
      if (mounted) MortToast.show(context, 'Invitation revoked.');
      if (mounted) _refresh();
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
          eyebrow: 'Partner workspace',
          title: 'Scoped invitations',
          subtitle:
              'Create short-lived, limited-use teen invitations for this approved organization.',
        ),
        const MortSafetyBanner(
          message:
              'An invitation confirms only an organization relationship. It does not verify legal identity, approve a job, or guarantee marketplace access.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Create one-use invitation',
          busyLabel: 'Creating securely...',
          busy: _creating,
          icon: Icons.add_link,
          onPressed: _create,
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Invitations unavailable',
                message: userFacingError(snapshot.error!),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const MortEmptyState(
                title: 'No invitations yet',
                message:
                    'Create an invitation only when an approved participant needs one.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final invite in items) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code prefix ${invite['code_prefix'] ?? 'hidden'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          'Used ${invite['use_count'] ?? 0} of ${invite['max_uses'] ?? 0}. Expires ${_dateLabel(invite['expires_at'])}.',
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        MortBadge(
                          label: invite['revoked_at'] == null
                              ? 'Active'
                              : 'Revoked',
                          color: invite['revoked_at'] == null
                              ? MortColors.neon
                              : MortColors.textMuted,
                        ),
                        if (invite['revoked_at'] == null) ...[
                          const SizedBox(height: MortSpacing.md),
                          MortButton(
                            label: 'Revoke invitation',
                            icon: Icons.link_off,
                            style: MortButtonStyle.danger,
                            busy: _busyId == invite['id']?.toString(),
                            onPressed: () => _revoke(invite),
                          ),
                        ],
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

class _PartnerParticipantData {
  const _PartnerParticipantData({
    required this.participants,
    required this.attestations,
  });

  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> attestations;
}

String _humanize(Object? value) {
  final words = value?.toString().trim().replaceAll('_', ' ') ?? '';
  if (words.isEmpty) return 'Not specified';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String _dateLabel(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return 'an unknown date';
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$month/$day/${parsed.year}';
}
