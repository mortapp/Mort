import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';

const _canvas = Color(0xFFF6F6F3);
const _surface = Colors.white;
const _ink = Color(0xFF171819);
const _muted = Color(0xFF6C7073);
const _line = Color(0xFFE5E6E3);
const _silver = Color(0xFFEBECE9);

List<Job> selectQuickJobs(List<Job> jobs) => jobs
    .where(
      (job) =>
          job.isOpen &&
          !job.isTest &&
          job.estimatedDurationMinutes != null &&
          job.estimatedDurationMinutes! < 30,
    )
    .toList(growable: false);

class TeenMarketplaceHomeScreen extends ConsumerWidget {
  const TeenMarketplaceHomeScreen({super.key});

  static const _filters = JobSearchFilters(limit: 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final feed = ref.watch(openJobsProvider(_filters));
    final displayName = profile?.displayName?.trim() ?? '';
    final firstName = displayName.isEmpty
        ? null
        : displayName.split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _ink,
          onRefresh: () async => ref.invalidate(openJobsProvider(_filters)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              MortSpacing.md,
              MortSpacing.md,
              MortSpacing.md,
              112,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MORT',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          firstName == null || firstName.isEmpty
                              ? 'Find your next job'
                              : 'Good to see you, $firstName',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Good work, close to home.',
                          style: TextStyle(color: _muted, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_none_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: _surface,
                      side: const BorderSide(color: _line),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.lg),
              feed.when(
                loading: () => const _FeedLoading(),
                error: (error, _) => _FeedError(
                  message: userFacingError(error),
                  onRetry: () => ref.invalidate(openJobsProvider(_filters)),
                ),
                data: (state) => _MarketplaceSections(
                  jobs: state.items,
                  hasMore: state.hasMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceSections extends StatelessWidget {
  const _MarketplaceSections({required this.jobs, required this.hasMore});

  final List<Job> jobs;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final quickJobs = selectQuickJobs(jobs);
    final textScale = MediaQuery.textScalerOf(context).scale(18) / 18;
    final quickJobsRailHeight = 180 + (textScale - 1).clamp(0.0, 3.0) * 140;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Quick jobs',
          detail: 'Under 30 minutes',
          action: 'Explore',
          onAction: () => context.go('/teen/jobs'),
        ),
        const SizedBox(height: MortSpacing.sm),
        if (quickJobs.isEmpty)
          const _QuietCard(
            title: 'No quick jobs nearby yet',
            detail: 'New local work will show up here when it is available.',
          )
        else
          SizedBox(
            height: quickJobsRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickJobs.length,
              separatorBuilder: (_, _) => const SizedBox(width: MortSpacing.sm),
              itemBuilder: (context, index) => SizedBox(
                width: 260,
                child: _QuickJobCard(job: quickJobs[index]),
              ),
            ),
          ),
        const SizedBox(height: MortSpacing.lg),
        _SectionHeading(
          title: 'Jobs near you',
          detail: 'A good place to start',
          action: 'See all',
          onAction: () => context.go('/teen/jobs'),
        ),
        const SizedBox(height: MortSpacing.sm),
        if (jobs.isEmpty)
          const _QuietCard(
            title: 'No open jobs right now',
            detail: 'Check back soon or explore another area.',
          )
        else ...[
          for (final job in jobs.take(8)) ...[
            _JobFeedCard(job: job),
            const SizedBox(height: MortSpacing.sm),
          ],
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: () => context.go('/teen/jobs'),
                style: TextButton.styleFrom(foregroundColor: _ink),
                child: const Text('See all open jobs'),
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.detail,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String detail;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(foregroundColor: _ink),
        child: Text(action),
      ),
    ],
  );
}

class _QuickJobCard extends StatelessWidget {
  const _QuickJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) => _JobSurface(
    onTap: () => context.push('/teen/jobs/${job.id}'),
    padding: const EdgeInsets.all(MortSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Tag(label: job.category),
            const Spacer(),
            const Icon(Icons.bolt_rounded, size: 18, color: _ink),
          ],
        ),
        const Spacer(),
        Text(
          job.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${job.payDisplay}  ·  ${job.estimatedDurationMinutes} min',
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _JobFeedCard extends StatelessWidget {
  const _JobFeedCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) => _JobSurface(
    onTap: () => context.push('/teen/jobs/${job.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                job.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: MortSpacing.sm),
            Text(
              job.payDisplay,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            _Tag(label: job.category),
            _Tag(label: '${job.city}, ${job.state}'),
            _Tag(
              label: job.estimatedDurationMinutes == null
                  ? job.scheduleDisplay
                  : '${job.estimatedDurationMinutes} min',
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Icon(
              job.posterVerified
                  ? Icons.verified_rounded
                  : Icons.shield_outlined,
              size: 16,
              color: _muted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                job.posterVerified
                    ? 'Verified poster'
                    : 'Safety details included',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: _muted),
          ],
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _silver,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _JobSurface extends StatelessWidget {
  const _JobSurface({
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(MortSpacing.md),
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: _surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    ),
  );
}

class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(MortSpacing.md),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: _muted, fontSize: 14)),
      ],
    ),
  );
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < 3; index++) ...[
        Container(
          height: 142,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
      ],
    ],
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _QuietCard(
    title: 'Jobs are not available right now',
    detail: '$message\n\nTry again in a moment.',
  )._withRetry(onRetry);
}

extension on _QuietCard {
  Widget _withRetry(VoidCallback onRetry) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      this,
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: _ink),
          child: const Text('Try again'),
        ),
      ),
    ],
  );
}
