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
  final Set<String> _pendingInterestJobIds = {};
  final Set<String> _notInterestedJobIds = {};

  void _dismissJob(Job job) {
    setState(() => _notInterestedJobIds.add(job.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Not interested'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted) setState(() => _notInterestedJobIds.remove(job.id));
          },
        ),
      ),
    );
  }

  Future<void> _setInterest(String jobId, bool interested) async {
    if (_pendingInterestJobIds.contains(jobId)) return;
    setState(() => _pendingInterestJobIds.add(jobId));
    try {
      await ref
          .read(jobsRepositoryProvider)
          .setJobInterest(jobId, interested: interested);
      if (!mounted) return;
      ref.invalidate(interestedJobIdsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(error))));
    } finally {
      if (mounted) setState(() => _pendingInterestJobIds.remove(jobId));
    }
  }

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
            final interestedJobIds =
                ref.watch(interestedJobIdsProvider).asData?.value ??
                const <String>{};
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
                    .where(
                      (job) =>
                          !quickJobIds.contains(job.id) &&
                          !_notInterestedJobIds.contains(job.id),
                    )
                    .toList(growable: true)
                  ..sort((left, right) {
                    final leftInterested = interestedJobIds.contains(left.id);
                    final rightInterested = interestedJobIds.contains(right.id);
                    if (leftInterested == rightInterested) return 0;
                    return rightInterested ? 1 : -1;
                  });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _MarketplaceMasthead(),
                if (quickJobs.isNotEmpty) ...[
                  _SectionHeading(
                    title: 'Quick Jobs',
                    eyebrow: 'UNDER 30 MINUTES',
                    actionLabel: 'Explore all',
                    onAction: () => context.go('/teen/explore'),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  SizedBox(
                    height: 184 * MediaQuery.textScalerOf(context).scale(1),
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
                    eyebrow: 'PICK UP WHERE YOU ARE',
                    actionLabel: 'See all',
                    onAction: () => context.go('/teen/explore'),
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  for (final job in openJobs) ...[
                    SizedBox(
                      width:
                          MediaQuery.sizeOf(context).width - MortSpacing.md * 2,
                      child: Dismissible(
                        key: ValueKey('dismissible-${job.id}'),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: MortSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_circle_outline_rounded),
                              SizedBox(width: MortSpacing.xs),
                              Text('Not interested'),
                            ],
                          ),
                        ),
                        onDismissed: (_) => _dismissJob(job),
                        child: _MarketplaceJobCard(
                          key: ValueKey(job.id),
                          job: job,
                          interested: interestedJobIds.contains(job.id),
                          interestSaving: _pendingInterestJobIds.contains(
                            job.id,
                          ),
                          onInterestChanged: (interested) =>
                              _setInterest(job.id, interested),
                        ),
                      ),
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
    required this.eyebrow,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String eyebrow;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: MortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAction,
            tooltip: actionLabel,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceMasthead extends StatelessWidget {
  const _MarketplaceMasthead();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.onSurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              'M',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(width: MortSpacing.xs),
          const Spacer(),
          IconButton(
            tooltip: 'Explore work near you',
            onPressed: () => context.go('/teen/explore'),
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerHigh,
              minimumSize: const Size(44, 44),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.near_me_outlined),
          ),
        ],
      ),
    );
  }
}

class _QuickJobCard extends StatelessWidget {
  const _QuickJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final area = job.locationText.trim();
    return SizedBox(
      width: 226,
      child: Material(
        color: isDark ? colors.surfaceContainerHigh : const Color(0xFF171717),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/teen/jobs/${job.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _prettyCategory(job.category).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? colors.onSurfaceVariant
                              : Colors.white70,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_east_rounded,
                      size: 17,
                      color: isDark ? colors.onSurface : Colors.white70,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? colors.onSurface : Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: isDark ? colors.surface : Colors.white24,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: isDark ? colors.onSurface : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.posterName ?? 'Local poster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark ? colors.onSurface : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (job.posterVerified)
                      Tooltip(
                        message: 'Verified poster',
                        child: Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: isDark ? colors.onSurface : Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: isDark ? colors.onSurfaceVariant : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? colors.onSurfaceVariant
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: isDark ? colors.onSurfaceVariant : Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        [
                          if (job.estimatedDurationMinutes != null)
                            '${job.estimatedDurationMinutes} min',
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? colors.onSurfaceVariant
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  job.payDisplay,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDark ? colors.onSurface : Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
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
    required this.interestSaving,
    required this.onInterestChanged,
  });

  final Job job;
  final bool interested;
  final bool interestSaving;
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
    final area = _safeAreaLabel(job);
    final details = [
      ?duration,
      if (!job.isFlexible && job.startsAt != null) job.scheduleDisplay,
    ].join('  ·  ');

    return Material(
      key: ValueKey('nearby-job-${job.id}'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/teen/jobs/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.near_me_outlined,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      area.isEmpty ? 'Nearby' : area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (job.posterVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
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
                  const SizedBox(width: 7),
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
                  if (details.isNotEmpty)
                    Flexible(
                      child: Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prettyCategory(job.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    job.payDisplay,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: widget.interested
                        ? 'Remove interest'
                        : 'Show interest',
                    onPressed: widget.interestSaving
                        ? null
                        : () => widget.onInterestChanged(!widget.interested),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    icon: widget.interestSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
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
                        minimumSize: const Size(48, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

String _safeAreaLabel(Job job) {
  final neighborhood = job.neighborhood?.trim();
  if (neighborhood != null && neighborhood.isNotEmpty) return neighborhood;
  final city = job.city.trim();
  final state = job.state.trim();
  if (city.isEmpty) return '';
  return state.isEmpty ? city : '$city, $state';
}

String _prettyCategory(String category) {
  return category
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
