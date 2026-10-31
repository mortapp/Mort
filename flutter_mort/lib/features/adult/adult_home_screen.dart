import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';

class AdultHomeScreen extends ConsumerWidget {
  const AdultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    return MortScreen(
      showAtmosphere: false,
      children: [
        MortHeader(
          eyebrow: 'YOUR WORK',
          title: 'Your posted jobs',
          subtitle: 'Post nearby work and review each applicant in MORT.',
          trailing: MortIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh your jobs',
            onPressed: () => ref.invalidate(myJobsProvider),
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Post a job',
          icon: Icons.add_rounded,
          onPressed: () => context.go('/adult/post-job'),
        ),
        const SizedBox(height: MortSpacing.md),
        jobs.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Your jobs could not be loaded',
            message: userFacingError(error),
            action: MortButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(myJobsProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const MortEmptyState(
                title: 'Your next job starts here',
                message:
                    'Create a clear, local listing to meet your first applicant.',
                icon: Icons.work_outline_rounded,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final job in items.take(5)) ...[
                  _AdultHomeJobCard(job: job),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (items.length > 5)
                  MortButton(
                    label: 'View all jobs',
                    style: MortButtonStyle.secondary,
                    onPressed: () => context.go('/adult/jobs'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AdultHomeJobCard extends StatelessWidget {
  const _AdultHomeJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MortGlassCard(
      onTap: () => context.push('/adult/jobs/${job.id}'),
      semanticLabel: '${job.title}, ${job.status}, ${job.payDisplay}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MortBadge(label: job.status, color: colors.primary),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            '${job.payDisplay}  ·  ${job.category}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            job.publicAreaDisplay,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
