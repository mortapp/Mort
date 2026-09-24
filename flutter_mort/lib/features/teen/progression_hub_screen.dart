import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/progression.dart';
import '../../data/repositories/providers.dart';
import 'teen_shell.dart';

class ProgressionHubScreen extends ConsumerWidget {
  const ProgressionHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(myProgressionProvider);
    return MortScreen(
      children: [
        const MortTeenDestinationHeader(
          eyebrow: 'GET IN MOTION',
          title: 'Progression',
          subtitle: 'Build yourself up through real work and safe habits.',
        ),
        const SizedBox(height: MortSpacing.md),
        progression.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Progression unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(myProgressionProvider),
            ),
          ),
          data: (snapshot) => _ProgressionBody(snapshot: snapshot),
        ),
      ],
    );
  }
}

class _ProgressionBody extends ConsumerWidget {
  const _ProgressionBody({required this.snapshot});
  final ProgressionSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        snapshot.cosmetics.any(
          (cosmetic) => cosmetic.key == 'ice_trace' && cosmetic.equipped,
        )
        ? MortColors.lightBlue
        : MortColors.silverBright;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    label: '${snapshot.rankLabel} rank emblem',
                    child: SvgPicture.asset(
                      'assets/gamification/ranks/${snapshot.rank}.svg',
                      width: 76,
                      height: 76,
                    ),
                  ),
                  const SizedBox(width: MortSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.rankLabel.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Level ${snapshot.level} of 50',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (snapshot.nextRank case final next?)
                          Text(
                            'Next rank: $next',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.md),
              Semantics(
                label: snapshot.nextLevelXp == null
                    ? 'Maximum level reached, ${snapshot.xpTotal} total XP'
                    : '${snapshot.xpTotal} total XP, ${snapshot.nextLevelXp! - snapshot.xpTotal} XP to next level',
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: snapshot.levelProgress),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 450),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    color: accent,
                    backgroundColor: MortColors.line,
                  ),
                ),
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(
                snapshot.nextLevelXp == null
                    ? '${snapshot.xpTotal} XP · highest level'
                    : '${snapshot.xpTotal} XP · ${snapshot.nextLevelXp! - snapshot.xpTotal} to next level',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Motion Tokens',
                value: '${snapshot.motionTokensBalance}',
                icon: Icons.stars_outlined,
                color: accent,
              ),
            ),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: _Metric(
                label: 'Safety Streak',
                value: '${snapshot.currentSafetyStreak}',
                icon: Icons.shield_outlined,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        Text(
          'Motion Tokens unlock only profile cosmetics. Rank measures activity, not identity or guaranteed safety.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final event
            in snapshot.events.where((event) => event.newLevel != null).take(1))
          Padding(
            padding: const EdgeInsets.only(top: MortSpacing.md),
            child: _MilestoneNotice(event: event),
          ),
        const MortSectionLabel(label: 'Badges'),
        snapshot.badges.isEmpty
            ? const MortGlassSoftSurface(
                child: Text(
                  'Your first completed job starts your badge collection.',
                ),
              )
            : Wrap(
                spacing: MortSpacing.xs,
                runSpacing: MortSpacing.xs,
                children: [
                  for (final badge in snapshot.badges)
                    MortStatusPill(
                      label: _badgeName(badge),
                      icon: Icons.workspace_premium_outlined,
                      color: MortColors.silverBright,
                    ),
                ],
              ),
        const MortSectionLabel(label: 'Recent XP'),
        if (snapshot.events.where((event) => event.xp > 0).isEmpty)
          const MortGlassSoftSurface(
            child: Text('No XP events yet. Legitimate work will appear here.'),
          ),
        for (final event
            in snapshot.events.where((event) => event.xp > 0).take(5))
          MortGlassSoftSurface(
            child: Row(
              children: [
                Icon(Icons.bolt_outlined, color: accent),
                const SizedBox(width: MortSpacing.sm),
                Expanded(child: Text(_eventName(event.type))),
                Text('+${event.xp} XP'),
              ],
            ),
          ),
        const MortSectionLabel(label: 'Cosmetic collection'),
        if (snapshot.cosmetics.isEmpty)
          const MortGlassSoftSurface(
            child: Text('Cosmetics will appear when available.'),
          ),
        for (final cosmetic in snapshot.cosmetics)
          Padding(
            padding: const EdgeInsets.only(bottom: MortSpacing.sm),
            child: MortGlassSoftSurface(
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: MortColors.silverBright,
                  ),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cosmetic.title),
                        Text(
                          cosmetic.owned
                              ? (cosmetic.equipped ? 'Equipped' : 'Unlocked')
                              : '${cosmetic.cost} Motion Tokens',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!cosmetic.owned)
                    TextButton(
                      onPressed: snapshot.motionTokensBalance < cosmetic.cost
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(progressionRepositoryProvider)
                                    .unlockCosmetic(cosmetic.key);
                                ref.invalidate(myProgressionProvider);
                                if (context.mounted)
                                  MortToast.show(
                                    context,
                                    '${cosmetic.title} unlocked.',
                                  );
                              } catch (error) {
                                if (context.mounted)
                                  MortToast.show(
                                    context,
                                    userFacingError(error),
                                  );
                              }
                            },
                      child: const Text('Unlock'),
                    ),
                  if (cosmetic.owned && !cosmetic.equipped)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(progressionRepositoryProvider)
                              .equipCosmetic(cosmetic.key);
                          ref.invalidate(myProgressionProvider);
                        } catch (error) {
                          if (context.mounted)
                            MortToast.show(context, userFacingError(error));
                        }
                      },
                      child: const Text('Equip'),
                    ),
                ],
              ),
            ),
          ),
        const MortSectionLabel(label: 'Goals'),
        for (final goal in snapshot.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: MortSpacing.xs),
            child: MortGlassSoftSurface(
              child: Row(
                children: [
                  Icon(
                    goal.progress >= goal.target
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: MortColors.silverBright,
                  ),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(child: Text(goal.title)),
                  Text('${goal.progress.clamp(0, goal.target)}/${goal.target}'),
                ],
              ),
            ),
          ),
        const MortSectionLabel(label: 'Keep moving'),
        MortQuickActionGrid(
          actions: [
            MortAction(
              label: 'Goals',
              icon: Icons.flag_outlined,
              onPressed: () => context.push('/teen/goals'),
            ),
            MortAction(
              label: 'Leaderboard',
              icon: Icons.leaderboard_outlined,
              onPressed: () => context.push('/teen/progression/leaderboard'),
            ),
            if (snapshot.xpTotal > 0)
              MortAction(
                label: 'Share milestone',
                icon: Icons.ios_share_outlined,
                onPressed: () => context.push('/teen/progression/share'),
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
      ],
    );
  }
}

class _MilestoneNotice extends StatelessWidget {
  const _MilestoneNotice({required this.event});
  final ProgressionEvent event;

  @override
  Widget build(BuildContext context) {
    final rank = event.newRank;
    final hasRankEmblem = const {
      'bronze',
      'silver',
      'gold',
      'platinum',
      'diamond',
    }.contains(rank);
    return MortGlassSoftSurface(
      child: Row(
        children: [
          if (hasRankEmblem)
            SvgPicture.asset(
              'assets/gamification/ranks/$rank.svg',
              width: 48,
              height: 48,
            )
          else
            const Icon(
              Icons.workspace_premium_outlined,
              color: MortColors.silverBright,
              size: 40,
            ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasRankEmblem
                      ? '${rank![0].toUpperCase()}${rank.substring(1)} rank reached'
                      : 'Level ${event.newLevel} reached',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  event.tokens > 0
                      ? 'Level ${event.newLevel} · +${event.tokens} Motion Tokens'
                      : 'Level ${event.newLevel} milestone',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => MortGlassSoftSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: MortSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _eventName(String type) => switch (type) {
  'completed_job' => 'Completed job',
  'first_completed_job' => 'First completed job',
  'first_category' => 'First job in a category',
  'safety_checkins' => 'Safety check-ins complete',
  'post_job_review' => 'Post-job feedback',
  _ => 'Progression activity',
};

String _badgeName(String key) {
  final fixed = switch (key) {
    'jobs_1' => 'First Move',
    'jobs_5' => 'Getting In Motion',
    'jobs_10' => 'Momentum',
    'jobs_25' => 'Consistent',
    'jobs_50' => 'Local Veteran',
    'safety_3' => 'Check-In Ready',
    'safety_10' => 'Safety Habit',
    _ => null,
  };
  if (fixed != null) return fixed;
  final category = RegExp(r'^category_(.+)_(1|5|20)$').firstMatch(key);
  if (category == null) return key.replaceAll('_', ' ');
  final name = category
      .group(1)!
      .split('_')
      .map((word) {
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
  return switch (category.group(2)) {
    '1' => 'First $name Job',
    '5' => '$name Regular',
    _ => '$name Specialist',
  };
}
