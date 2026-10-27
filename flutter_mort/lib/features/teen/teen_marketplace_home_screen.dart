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
class TeenMarketplaceHomeScreen extends ConsumerWidget {
  const TeenMarketplaceHomeScreen({super.key});

  static const _filters = JobSearchFilters(limit: 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(openJobsProvider(_filters));
    final colors = Theme.of(context).colorScheme;
    return MortScreen(
      showAtmosphere: false,
      children: [
        Row(
          children: [
            Text(
              'MORT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Notifications',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: () => context.push('/notifications'),
              style: IconButton.styleFrom(
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outlineVariant),
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.lg),
        Text(
          'Jobs near you',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: MortSpacing.xxs),
        Row(
          children: [
            Icon(
              Icons.shield_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: MortSpacing.xxs),
            Expanded(
              child: Text(
                'Local work. Exact addresses stay private.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/teen/explore'),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface,
                minimumSize: const Size(48, 44),
              ),
              child: const Text('Explore'),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
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
            final openJobs = feed.items
                .where((job) => !quickJobIds.contains(job.id))
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quickJobs.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Quick picks',
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
                    title: 'All nearby jobs',
                    actionLabel: 'See all',
                    onAction: () => context.go('/teen/explore'),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  for (final job in openJobs) ...[
                    _MarketplaceJobCard(key: ValueKey(job.id), job: job),
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
                const SizedBox(height: MortSpacing.md),
                Text(
                  'Exact addresses stay private until they are needed for a job.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
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
      width: 248,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/teen/jobs/${job.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MortSpacing.md,
              MortSpacing.sm,
              MortSpacing.md,
              MortSpacing.sm,
            ),
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
  const _MarketplaceJobCard({super.key, required this.job});

  final Job job;

  @override
  ConsumerState<_MarketplaceJobCard> createState() =>
      _MarketplaceJobCardState();
}

class _MarketplaceJobCardState extends ConsumerState<_MarketplaceJobCard> {
  bool _saving = false;

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
    final metadata = [?duration, job.scheduleDisplay].join('  ·  ');

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(MortSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: MortSpacing.xxs),
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MortSpacing.sm),
                Text(
                  job.payDisplay,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MortSpacing.sm),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: MortSpacing.xs),
                Flexible(
                  child: Text(
                    job.posterName ?? 'Local poster',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (job.posterVerified) ...[
                  const SizedBox(width: MortSpacing.xxs),
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
                const Spacer(),
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: MortSpacing.xxs),
                Flexible(
                  child: Text(
                    job.locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MortSpacing.xs),
            Text(
              metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (job.summary?.isNotEmpty == true) ...[
              const SizedBox(height: MortSpacing.xxs),
              Text(
                job.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: MortSpacing.sm),
            Row(
              children: [
                IconButton(
                  tooltip: saved ? 'Remove saved job' : 'Save job',
                  onPressed: _saving || !savedJobs.hasValue
                      ? null
                      : () => _toggleSaved(saved),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: colors.onSurface,
                  ),
                ),
                const SizedBox(width: MortSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/teen/jobs/${job.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('View job'),
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
