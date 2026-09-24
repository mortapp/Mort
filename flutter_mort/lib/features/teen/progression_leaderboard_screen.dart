import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import 'teen_shell.dart';

const _boards = <String, String>{
  'weekly_xp': 'Weekly XP',
  'completed_jobs': 'Completed Jobs',
  'safety_streak': 'Safety Streak',
  'beginner_helpers': 'Beginner Helpers',
  'pet_care': 'Pet Care',
  'yard_work': 'Yard Work',
  'tutoring': 'Tutoring',
  'business_help': 'Business Help',
};

class ProgressionLeaderboardScreen extends ConsumerStatefulWidget {
  const ProgressionLeaderboardScreen({super.key});

  @override
  ConsumerState<ProgressionLeaderboardScreen> createState() =>
      _ProgressionLeaderboardScreenState();
}

class _ProgressionLeaderboardScreenState
    extends ConsumerState<ProgressionLeaderboardScreen> {
  String _selected = 'weekly_xp';

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(progressionBoardProvider(_selected));
    final myRank = ref.watch(myLeaderboardRankProvider);
    return MortScreen(
      children: [
        const MortTeenDestinationHeader(
          eyebrow: 'MOTION COMMUNITY',
          title: 'Leaderboards',
          subtitle:
              'Optional recognition for legitimate work. Your earnings and location stay private.',
        ),
        const SizedBox(height: MortSpacing.md),
        myRank.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Privacy setting unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(myLeaderboardRankProvider),
            ),
          ),
          data: (rank) => MortGlassSoftSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank.leaderboardOptOut
                      ? 'You are hidden'
                      : 'You are participating',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.xs),
                const Text(
                  'Only your username, safe avatar, level, rank, and selected board score may appear.',
                ),
                const SizedBox(height: MortSpacing.xs),
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(leaderboardRepositoryProvider)
                          .setOptOut(!rank.leaderboardOptOut);
                      ref.invalidate(myLeaderboardRankProvider);
                      ref.invalidate(leaderboardProvider);
                      for (final key in _boards.keys) {
                        ref.invalidate(progressionBoardProvider(key));
                      }
                    } catch (error) {
                      if (context.mounted)
                        MortToast.show(context, userFacingError(error));
                    }
                  },
                  child: Text(rank.leaderboardOptOut ? 'Opt in' : 'Opt out'),
                ),
              ],
            ),
          ),
        ),
        const MortSectionLabel(label: 'Choose a board'),
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            for (final item in _boards.entries)
              ChoiceChip(
                label: Text(item.value),
                selected: _selected == item.key,
                onSelected: (_) => setState(() => _selected = item.key),
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        board.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Leaderboard unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () =>
                  ref.invalidate(progressionBoardProvider(_selected)),
            ),
          ),
          data: (entries) => entries.isEmpty
              ? const MortEmptyState(
                  title: 'No entries yet',
                  message:
                      'This board fills as opted-in members complete eligible work.',
                )
              : Column(
                  children: [
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: MortSpacing.xs),
                        child: MortGlassSoftSurface(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '#${entry.position}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const Icon(
                                Icons.person_outline_rounded,
                                color: MortColors.silverBright,
                              ),
                              const SizedBox(width: MortSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('@${entry.username}'),
                                    Text(
                                      '${entry.rank} · Level ${entry.level}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${entry.score}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
