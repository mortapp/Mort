import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

/// Adult Explore searches the poster's own jobs. The adult client does not
/// query teen-only discovery or expose teen profiles outside applicant flows.
class AdultExploreScreen extends ConsumerStatefulWidget {
  const AdultExploreScreen({super.key});

  @override
  ConsumerState<AdultExploreScreen> createState() => _AdultExploreScreenState();
}

class _AdultExploreScreenState extends ConsumerState<AdultExploreScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(myJobsProvider);
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Find it fast',
          title: 'Explore',
          subtitle:
              'Search your job posts and open the work that needs attention.',
          showBackButton: false,
        ),
        const SizedBox(height: MortSpacing.sm),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search your jobs',
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
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
            final results = items
                .where((job) {
                  if (_query.isEmpty) return true;
                  final query = _query.toLowerCase();
                  return job.title.toLowerCase().contains(query) ||
                      job.category.toLowerCase().contains(query) ||
                      job.locationText.toLowerCase().contains(query);
                })
                .toList(growable: false);
            if (results.isEmpty) {
              return MortEmptyState(
                title: _query.isEmpty ? 'No jobs to explore yet' : 'No matches',
                message: _query.isEmpty
                    ? 'Post a job to see its workflow here.'
                    : 'Try a different title, category, or general area.',
                icon: Icons.search_off_rounded,
                action: _query.isEmpty
                    ? MortButton(
                        label: 'Post a job',
                        icon: Icons.add_rounded,
                        onPressed: () => context.go('/adult/post-job'),
                      )
                    : null,
              );
            }
            return Column(
              children: [
                for (final job in results) ...[
                  MortCard(
                    onTap: () => context.go('/adult/jobs/${job.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.category,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: MortSpacing.xxs),
                        Text(
                          job.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          '${job.payDisplay} · ${job.locationText}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        MortJobStatusBadge(status: job.status),
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
