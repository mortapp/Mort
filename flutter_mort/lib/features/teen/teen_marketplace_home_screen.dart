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
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Jobs near you',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.xs),
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
                    height: 132,
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
                _SectionHeading(
                  title: 'Open jobs',
                  actionLabel: 'See all',
                  onAction: () => context.go('/teen/explore'),
                ),
                const SizedBox(height: MortSpacing.xs),
                for (final job in feed.items) ...[
                  _MarketplaceJobCard(key: ValueKey(job.id), job: job),
                  const SizedBox(height: MortSpacing.sm),
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Text(actionLabel),
      ),
    ],
  );
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
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                Text(
                  job.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: MortSpacing.xxs),
                Text(
                  '${job.payDisplay}  ·  ${job.estimatedDurationMinutes} min',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
    final metadata = [
      job.payDisplay,
      ?duration,
      job.scheduleDisplay,
    ].join('  ·  ');

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push('/teen/jobs/${job.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MortSpacing.md,
                MortSpacing.sm,
                MortSpacing.md,
                MortSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: MortSpacing.xxs),
                      Expanded(
                        child: Text(
                          job.locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: colors.surfaceContainerHigh,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: MortSpacing.xs),
                      Flexible(
                        child: Text(
                          job.posterName ?? 'Local poster',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (job.posterVerified) ...[
                        const SizedBox(width: MortSpacing.xxs),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          semanticLabel: 'Verified poster',
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: MortSpacing.xxs),
                        Text(
                          'Verified',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  Text(
                    job.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: MortSpacing.xxs),
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  Text(
                    metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (job.summary?.isNotEmpty == true) ...[
                    const SizedBox(height: MortSpacing.xs),
                    Text(
                      job.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MortSpacing.sm,
              0,
              MortSpacing.sm,
              MortSpacing.sm,
            ),
            child: Row(
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
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
