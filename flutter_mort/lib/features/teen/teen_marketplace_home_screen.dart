import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';

/// Teen Home is the marketplace feed. Jobs lead; search and detailed filters
/// live in Explore.
class TeenMarketplaceHomeScreen extends ConsumerStatefulWidget {
  const TeenMarketplaceHomeScreen({super.key});

  @override
  ConsumerState<TeenMarketplaceHomeScreen> createState() =>
      _TeenMarketplaceHomeScreenState();
}

class _TeenMarketplaceHomeScreenState
    extends ConsumerState<TeenMarketplaceHomeScreen> {
  static const _filters = JobSearchFilters(limit: 20);
  final Set<String> _interestedJobIds = {};

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(openJobsProvider(_filters));
    return MortScreen(
      showAtmosphere: false,
      children: [
        result.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: MortSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => MortErrorState(
            title: 'Jobs could not be loaded',
            message: userFacingError(error),
            action: MortButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(openJobsProvider(_filters)),
            ),
          ),
          data: (feed) {
            if (feed.items.isEmpty) {
              return MortEmptyState(
                title: 'No open jobs nearby yet',
                message: 'Explore other areas or check back soon.',
                icon: Icons.work_outline_rounded,
                action: MortButton(
                  label: 'Explore jobs',
                  icon: Icons.search_rounded,
                  onPressed: () => context.go('/teen/explore'),
                ),
              );
            }

            final quickJobs = feed.items
                .where(
                  (job) =>
                      job.estimatedDurationMinutes != null &&
                      job.estimatedDurationMinutes! > 0 &&
                      job.estimatedDurationMinutes! < 30,
                )
                .toList(growable: false);
            final quickJobIds = quickJobs.map((job) => job.id).toSet();
            final openJobs =
                feed.items
                    .where((job) => !quickJobIds.contains(job.id))
                    .toList(growable: true)
                  ..sort((left, right) {
                    final leftInterested = _interestedJobIds.contains(left.id);
                    final rightInterested = _interestedJobIds.contains(
                      right.id,
                    );
                    if (leftInterested == rightInterested) return 0;
                    return rightInterested ? 1 : -1;
                  });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quickJobs.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Quick Jobs',
                    actionLabel: 'Explore all',
                    onAction: () => context.go('/teen/explore'),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  SizedBox(
                    height: 168 * MediaQuery.textScalerOf(context).scale(1),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickJobs.length.clamp(0, 8),
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: MortSpacing.sm),
                      itemBuilder: (context, index) =>
                          _QuickJobCard(job: quickJobs[index]),
                    ),
                  ),
                  const SizedBox(height: MortSpacing.md),
                ],
                if (openJobs.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Nearby work',
                    actionLabel: 'See all',
                    onAction: () => context.go('/teen/explore'),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  for (final job in openJobs) ...[
                    _MarketplaceJobCard(
                      key: ValueKey(job.id),
                      job: job,
                      interested: _interestedJobIds.contains(job.id),
                      onInterestChanged: (interested) => setState(() {
                        if (interested) {
                          _interestedJobIds.add(job.id);
                        } else {
                          _interestedJobIds.remove(job.id);
                        }
                      }),
                    ),
                    const SizedBox(height: MortSpacing.sm),
                  ],
                ],
                if (feed.hasMore) ...[
                  const SizedBox(height: MortSpacing.xs),
                  MortButton(
                    label: feed.loadingMore ? 'Loading jobs' : 'Load more',
                    icon: Icons.expand_more_rounded,
                    style: MortButtonStyle.secondary,
                    busy: feed.loadingMore,
                    onPressed: feed.loadingMore
                        ? null
                        : () => ref
                              .read(openJobsProvider(_filters).notifier)
                              .loadNext(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 44),
            foregroundColor: colors.onSurfaceVariant,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _QuickJobCard extends StatelessWidget {
  const _QuickJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 228,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/teen/jobs/${job.id}'),
          child: Padding(
            padding: const EdgeInsets.all(MortSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: MortSpacing.xxs),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: MortSpacing.xxs),
                    Expanded(
                      child: Text(
                        job.posterName ?? 'Local poster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (job.posterVerified) ...[
                      Tooltip(
                        message: 'Verified poster',
                        child: Icon(
                          Icons.verified_rounded,
                          size: 16,
                          semanticLabel: 'Verified poster',
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: MortSpacing.xxs),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: MortSpacing.xxs),
                    Expanded(
                      child: Text(
                        job.locationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MortSpacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if (job.estimatedDurationMinutes != null)
                            '${job.estimatedDurationMinutes} min',
                          if (job.scheduleDisplay.isNotEmpty)
                            job.scheduleDisplay,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: MortSpacing.xs),
                    Text(
                      job.payDisplay,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceJobCard extends ConsumerStatefulWidget {
  const _MarketplaceJobCard({
    super.key,
    required this.job,
    required this.interested,
    required this.onInterestChanged,
  });

  final Job job;
  final bool interested;
  final ValueChanged<bool> onInterestChanged;

  @override
  ConsumerState<_MarketplaceJobCard> createState() =>
      _MarketplaceJobCardState();
}

class _MarketplaceJobCardState extends ConsumerState<_MarketplaceJobCard> {
  bool _saving = false;
  bool _applying = false;
  String? _applicationId;

  bool get _requiresApplicationConfirmation {
    final job = widget.job;
    return !job.isFlexible ||
        job.requiresGuardianApproval ||
        (job.specialInstructions?.trim().isNotEmpty ?? false) ||
        (job.safetyNotes?.trim().isNotEmpty ?? false) ||
        (job.equipmentWorkerBrings?.trim().isNotEmpty ?? false) ||
        job.physicalRequirements.isNotEmpty;
  }

  Future<void> _apply() async {
    if (_applying) return;
    if (_applicationId != null) {
      if (mounted) context.push('/teen/applications/$_applicationId');
      return;
    }
    if (_requiresApplicationConfirmation) {
      context.push('/teen/jobs/${widget.job.id}');
      return;
    }

    setState(() => _applying = true);
    try {
      final repository = ref.read(applicationsRepositoryProvider);
      final eligibility = await repository.checkEligibility(widget.job.id);
      if (!mounted) return;
      if (!eligibility.eligible) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(eligibility.message)));
        return;
      }
      final application = await repository.applyToJob(widget.job.id);
      if (!mounted) return;
      setState(() => _applicationId = application.id);
      ref.invalidate(myApplicationsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _toggleSaved(bool wasSaved) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(jobsRepositoryProvider);
      if (wasSaved) {
        await repository.unsaveJob(widget.job.id);
      } else {
        await repository.saveJob(widget.job.id);
      }
      if (!mounted) return;
      ref.invalidate(savedJobIdsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasSaved ? 'Job removed from saved.' : 'Job saved.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final colors = Theme.of(context).colorScheme;
    final savedJobs = ref.watch(savedJobIdsProvider);
    final saved = savedJobs.asData?.value.contains(job.id) ?? false;
    final duration = job.estimatedDurationMinutes == null
        ? null
        : '${job.estimatedDurationMinutes} min';
    final metadata = [
      if (job.payDisplay.isNotEmpty) job.payDisplay,
      ?duration,
      job.scheduleDisplay,
    ].where((value) => value.isNotEmpty).join('  ·  ');

    return Material(
      key: ValueKey('nearby-job-${job.id}'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.sm,
          vertical: MortSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: MortSpacing.xxs),
                Expanded(
                  child: Text(
                    job.locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (job.posterVerified)
                  const Tooltip(
                    message: 'Verified poster',
                    child: Icon(Icons.verified_rounded, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: MortSpacing.xxs),
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: MortSpacing.xs),
                Expanded(
                  child: Text(
                    job.posterName ?? 'Local poster',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  job.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MortSpacing.xxs),
            Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: MortSpacing.xxs),
            Text(
              metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: MortSpacing.xxs),
            Row(
              children: [
                IconButton(
                  tooltip: widget.interested
                      ? 'Remove interest'
                      : 'Show interest',
                  onPressed: () => widget.onInterestChanged(!widget.interested),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: Icon(
                    widget.interested
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: colors.onSurface,
                  ),
                ),
                IconButton(
                  tooltip: saved ? 'Remove saved job' : 'Save job',
                  onPressed: _saving || !savedJobs.hasValue
                      ? null
                      : () => _toggleSaved(saved),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                        ),
                  style: IconButton.styleFrom(
                    foregroundColor: colors.onSurface,
                  ),
                ),
                const SizedBox(width: MortSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: _applying ? null : _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _applying
                          ? 'Applying…'
                          : _applicationId != null
                          ? 'View application'
                          : 'Apply',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
