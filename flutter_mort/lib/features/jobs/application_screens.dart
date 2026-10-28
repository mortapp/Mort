import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/application.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../profile/profile_avatar_widgets.dart';
import '../teen/teen_shell.dart';

enum ApplicationView { teen, adult, guardian }

class ApplicationListScreen extends ConsumerStatefulWidget {
  const ApplicationListScreen({super.key, this.view = ApplicationView.teen});

  final ApplicationView view;

  @override
  ConsumerState<ApplicationListScreen> createState() =>
      _ApplicationListScreenState();
}

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.view,
    required this.applicationId,
  });

  final ApplicationView view;
  final String applicationId;

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  late Future<MortApplication?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MortApplication?> _load() {
    final role = switch (widget.view) {
      ApplicationView.teen => UserRole.teen,
      ApplicationView.adult => UserRole.adult,
      ApplicationView.guardian => UserRole.guardian,
    };
    return ref
        .read(applicationsRepositoryProvider)
        .getApplication(widget.applicationId, role: role);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _changeStatus(MortApplication application, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .updateStatus(
            application.id,
            action,
            expectedUpdatedAt: application.updatedAt,
          );
      if (!mounted) return;
      MortToast.show(context, _successMessage(action));
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _successMessage(String action) => switch (action) {
    'viewed' => 'Application marked viewed.',
    'accepted' => 'Applicant accepted and job assigned.',
    'rejected' => 'Application declined.',
    'withdrawn' => 'Application withdrawn.',
    _ => 'Application updated.',
  };

  @override
  Widget build(BuildContext context) {
    final copy = switch (widget.view) {
      ApplicationView.adult => (
        eyebrow: 'Adult review',
        title: 'Applicant details',
        subtitle: 'Review and manage the selected application.',
      ),
      ApplicationView.guardian => (
        eyebrow: 'Guardian activity',
        title: 'Application details',
        subtitle: 'View an application submitted by a linked teen.',
      ),
      ApplicationView.teen => (
        eyebrow: 'Teen tracker',
        title: 'Application details',
        subtitle: 'Track progress and next steps.',
      ),
    };
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: copy.eyebrow,
          title: copy.title,
          subtitle: copy.subtitle,
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh application',
            onPressed: _reload,
          ),
        ),
        FutureBuilder<MortApplication?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Application unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final application = snapshot.data;
            if (application == null) {
              return const MortEmptyState(
                title: 'Application not found',
                message:
                    'This application may have been removed or is not visible to you.',
              );
            }
            return Column(
              children: [
                _ApplicationLifecycleCard(
                  application: application,
                  view: widget.view,
                  busy: _busy,
                  onStatus: (action) => _changeStatus(application, action),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ApplicationListScreenState extends ConsumerState<ApplicationListScreen> {
  late Future<List<MortApplication>> _future;
  String? _busyApplicationId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MortApplication>> _load() {
    final repository = ref.read(applicationsRepositoryProvider);
    return widget.view == ApplicationView.adult
        ? repository.listApplicationsForMyJobs()
        : repository.listMyApplications();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _changeStatus(MortApplication application, String action) async {
    if (_busyApplicationId != null) return;
    setState(() => _busyApplicationId = application.id);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .updateStatus(
            application.id,
            action,
            expectedUpdatedAt: application.updatedAt,
          );
      if (!mounted) return;
      MortToast.show(context, _successMessage(action));
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyApplicationId = null);
    }
  }

  String _successMessage(String action) => switch (action) {
    'viewed' => 'Application marked viewed.',
    'accepted' => 'Applicant accepted and job assigned.',
    'rejected' => 'Application declined.',
    'withdrawn' => 'Application withdrawn.',
    _ => 'Application updated.',
  };

  @override
  Widget build(BuildContext context) {
    final copy = switch (widget.view) {
      ApplicationView.adult => (
        eyebrow: 'Adult review',
        title: 'Applicants',
        subtitle:
            'View, accept, decline, and complete applications through protected job actions.',
      ),
      ApplicationView.guardian => (
        eyebrow: 'Guardian activity',
        title: 'Linked teen applications',
        subtitle:
            'View applications submitted by linked teens. Application decisions are handled by the teen and job poster.',
      ),
      ApplicationView.teen => (
        eyebrow: 'Teen tracker',
        title: 'Applications',
        subtitle:
            'Track real submission, review, assignment, work, proof, and completion states.',
      ),
    };
    final header = widget.view == ApplicationView.teen
        ? MortTeenDestinationHeader(
            eyebrow: copy.eyebrow,
            title: copy.title,
            subtitle: copy.subtitle,
            trailing: MortIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh applications',
              onPressed: _reload,
            ),
          )
        : MortHeader(
            eyebrow: copy.eyebrow,
            title: copy.title,
            subtitle: copy.subtitle,
            trailing: MortIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh applications',
              onPressed: _reload,
            ),
          );
    return MortScreen(
      children: [
        header,
        if (widget.view == ApplicationView.teen)
          const SizedBox(height: MortSpacing.md),
        if (widget.view == ApplicationView.guardian) ...[
          const MortSafetyBanner(
            message:
                'This view is read-only. Guardian consent is managed through the linked account, while each teen and job poster handles the application decision.',
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        FutureBuilder<List<MortApplication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Applications unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final applications = snapshot.data ?? const [];
            if (applications.isEmpty) {
              return const MortEmptyState(
                title: 'Nothing here yet',
                message:
                    'Applications appear here only after a real submission or approval request.',
              );
            }
            return Column(
              children: [
                for (final application in applications) ...[
                  _ApplicationLifecycleCard(
                    application: application,
                    view: widget.view,
                    busy: _busyApplicationId == application.id,
                    onStatus: (action) => _changeStatus(application, action),
                    onTap: () {
                      final route = switch (widget.view) {
                        ApplicationView.teen =>
                          '/teen/applications/${application.id}',
                        ApplicationView.adult =>
                          '/adult/applicants/${application.id}',
                        ApplicationView.guardian =>
                          '/guardian/approvals/${application.id}',
                      };
                      context.push(route);
                    },
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

class _ApplicationLifecycleCard extends ConsumerWidget {
  const _ApplicationLifecycleCard({
    required this.application,
    required this.view,
    required this.busy,
    required this.onStatus,
    this.onTap,
  });

  final MortApplication application;
  final ApplicationView view;
  final bool busy;
  final ValueChanged<String> onStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = application.job;
    return MortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (view != ApplicationView.teen)
            Row(
              children: [
                ProfileAvatarView(
                  profileId: application.teenId,
                  avatarPath: application.teenAvatarPath,
                  fallbackLabel: application.teenName ?? 'Applicant',
                  radius: 24,
                ),
                const SizedBox(width: MortSpacing.sm),
                Expanded(
                  child: Text(
                    application.teenName ?? 'Teen applicant',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          if (view != ApplicationView.teen)
            const SizedBox(height: MortSpacing.sm),
          Text(
            job?.title ?? 'Application',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              MortBadge(
                label: application.status.replaceAll('_', ' '),
                color: _statusColor(application.status),
              ),
              if (application.availabilityConfirmed)
                const MortBadge(
                  label: 'Availability confirmed',
                  color: MortColors.accent,
                ),
            ],
          ),
          if (job != null) ...[
            const SizedBox(height: MortSpacing.sm),
            Text('${job.payDisplay} | ${job.scheduleDisplay}'),
          ],
          if (application.note?.isNotEmpty == true) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(application.note!),
          ],
          if (view == ApplicationView.guardian) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(
              'Guardian view is read-only. Application decisions are made by the teen and job poster.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (application.status == 'canceled' && job != null) ...[
            const SizedBox(height: MortSpacing.sm),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: ref
                  .watch(jobsRepositoryProvider)
                  .listManagementEvents(job.id),
              builder: (context, snapshot) {
                final events = snapshot.data ?? const [];
                final cancellations = events.where(
                  (event) =>
                      event['action'] == 'cancel' && event['succeeded'] == true,
                );
                final reason = cancellations.isEmpty
                    ? null
                    : cancellations.last['reason']?.toString();
                if (reason == null || reason.isEmpty) {
                  return const MortSafetyBanner(
                    message:
                        'This job was canceled. Contact support if you need help with an assigned job.',
                  );
                }
                return MortSafetyBanner(
                  message: 'Cancellation reason: $reason',
                );
              },
            ),
          ],
          const SizedBox(height: MortSpacing.md),
          MortActionRow(actions: _actions(context)),
          const SizedBox(height: MortSpacing.sm),
          _LazyApplicationStatusTimeline(
            applicationId: application.id,
            formatTimestamp: _formatTimestamp,
          ),
        ],
      ),
    );
  }

  List<MortAction> _actions(BuildContext context) {
    if (view == ApplicationView.guardian) return const [];
    if (view == ApplicationView.adult) {
      final actions = <MortAction>[];
      if (['submitted', 'shortlisted'].contains(application.status)) {
        actions.add(
          MortAction(
            label: 'Mark viewed',
            icon: Icons.visibility_outlined,
            busy: busy,
            onPressed: () => onStatus('viewed'),
          ),
        );
      }
      if (['submitted', 'shortlisted', 'viewed'].contains(application.status)) {
        actions.addAll([
          MortAction(
            label: 'Accept applicant',
            icon: Icons.check,
            busy: busy,
            onPressed: () => onStatus('accepted'),
          ),
          MortAction(
            label: 'Decline applicant',
            icon: Icons.close,
            busy: busy,
            style: MortButtonStyle.danger,
            onPressed: () => onStatus('rejected'),
          ),
        ]);
      }
      if ([
        'accepted',
        'in_progress',
        'proof_submitted',
      ].contains(application.status)) {
        actions.add(
          MortAction(
            label: 'Open job progress',
            icon: Icons.timeline_outlined,
            route: '/jobs/progress/${application.id}',
          ),
        );
      }
      if (application.status == 'proof_submitted') {
        actions.add(
          MortAction(
            label: 'Review proof',
            icon: Icons.fact_check_outlined,
            onPressed: () =>
                context.push('/adult/proof-review/${application.id}'),
          ),
        );
      }
      if ([
        'accepted',
        'in_progress',
        'proof_submitted',
      ].contains(application.status)) {
        actions.add(
          MortAction(
            label: 'Job safety',
            icon: Icons.health_and_safety_outlined,
            onPressed: () =>
                context.push('/applications/${application.id}/safety'),
          ),
        );
        actions.add(
          MortAction(
            label: 'Message',
            icon: Icons.chat_outlined,
            onPressed: () => context.push('/messages'),
          ),
        );
      }
      if (application.status == 'completed') {
        actions.add(
          MortAction(
            label: 'Leave review',
            icon: Icons.rate_review_outlined,
            onPressed: () => context.push('/reviews/${application.id}'),
          ),
        );
      }
      return actions;
    }

    final actions = <MortAction>[];
    if (['submitted', 'shortlisted', 'viewed'].contains(application.status)) {
      actions.add(
        MortAction(
          label: 'Withdraw application',
          icon: Icons.undo,
          busy: busy,
          style: MortButtonStyle.danger,
          onPressed: () => onStatus('withdrawn'),
        ),
      );
    }
    if (application.status == 'accepted') {
      actions.add(
        MortAction(
          label: 'Confirm safety terms',
          icon: Icons.health_and_safety_outlined,
          onPressed: () =>
              context.push('/teen/safety/applications/${application.id}'),
        ),
      );
      actions.add(
        MortAction(
          label: 'Open job progress',
          icon: Icons.timeline_outlined,
          route: '/jobs/progress/${application.id}',
        ),
      );
    }
    if (application.status == 'in_progress') {
      actions.add(
        MortAction(
          label: 'Upload proof',
          icon: Icons.upload,
          onPressed: () => context.push('/teen/proof/${application.id}'),
        ),
      );
    }
    if ([
      'accepted',
      'in_progress',
      'proof_submitted',
    ].contains(application.status)) {
      if (application.status != 'accepted') {
        actions.add(
          MortAction(
            label: 'Job safety',
            icon: Icons.health_and_safety_outlined,
            onPressed: () =>
                context.push('/teen/safety/applications/${application.id}'),
          ),
        );
      }
      actions.add(
        MortAction(
          label: 'Message',
          icon: Icons.chat_outlined,
          onPressed: () => context.push('/messages'),
        ),
      );
    }
    if (application.status == 'completed') {
      actions.add(
        MortAction(
          label: 'Leave review',
          icon: Icons.rate_review_outlined,
          onPressed: () => context.push('/reviews/${application.id}'),
        ),
      );
    }
    return actions;
  }

  static Color _statusColor(String status) => switch (status) {
    'accepted' || 'completed' => MortColors.accent,
    'rejected' ||
    'guardian_rejected' ||
    'withdrawn' ||
    'canceled' => MortColors.danger,
    'in_progress' || 'proof_submitted' => MortColors.warning,
    _ => MortColors.safetyBlue,
  };

  static String _formatTimestamp(String? value) {
    final timestamp = DateTime.tryParse(value ?? '');
    if (timestamp == null) return 'Time unavailable';
    final local = timestamp.toLocal();
    return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _LazyApplicationStatusTimeline extends ConsumerStatefulWidget {
  const _LazyApplicationStatusTimeline({
    required this.applicationId,
    required this.formatTimestamp,
  });

  final String applicationId;
  final String Function(String?) formatTimestamp;

  @override
  ConsumerState<_LazyApplicationStatusTimeline> createState() =>
      _LazyApplicationStatusTimelineState();
}

class _LazyApplicationStatusTimelineState
    extends ConsumerState<_LazyApplicationStatusTimeline> {
  Future<List<Map<String, dynamic>>>? _eventsFuture;

  void _loadEvents() {
    setState(() {
      _eventsFuture = ref
          .read(applicationsRepositoryProvider)
          .listStatusEvents(widget.applicationId);
    });
  }

  void _handleExpansionChanged(bool expanded) {
    if (expanded && _eventsFuture == null) {
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('Status timeline'),
      onExpansionChanged: _handleExpansionChanged,
      children: [
        if (_eventsFuture case final future?)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userFacingError(snapshot.error)),
                    TextButton.icon(
                      onPressed: _loadEvents,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry timeline'),
                    ),
                  ],
                );
              }
              final events = snapshot.data ?? const [];
              if (events.isEmpty) {
                return const Text('No status events have been recorded.');
              }
              return Column(
                children: [
                  for (final event in events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(
                        (event['to_status'] ?? 'updated').toString().replaceAll(
                          '_',
                          ' ',
                        ),
                      ),
                      subtitle: Text(
                        widget.formatTimestamp(event['created_at']?.toString()),
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
