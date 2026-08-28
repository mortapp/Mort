import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../ads/widgets/mort_spark_section.dart';
import '../profile/profile_avatar_widgets.dart';
import 'teen_shell.dart';

class TeenProfileDestinationScreen extends ConsumerWidget {
  const TeenProfileDestinationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return MortScreen(
      children: [
        MortTeenDestinationHeader(
          eyebrow: 'Your MORT identity',
          title: 'Profile',
          subtitle: 'Your work history, trust signals, and account controls.',
          trailing: MortIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        profile.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Profile unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(currentProfileProvider),
            ),
          ),
          data: (value) => value == null
              ? const MortEmptyState(
                  title: 'Profile setup required',
                  message: 'Complete onboarding before using Teen Profile.',
                )
              : _TeenProfileBody(profile: value),
        ),
      ],
    );
  }
}

class _TeenProfileBody extends ConsumerWidget {
  const _TeenProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!
        : 'MORT member';
    final joined = profile.createdAt == null
        ? 'Join date unavailable'
        : 'Member since ${profile.createdAt!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidGlassContainer(
          tint: MortColors.roseGold,
          child: Column(
            children: [
              ProfileAvatarView(
                profileId: profile.id,
                avatarPath: profile.avatarPath,
                avatarUpdatedAt: profile.avatarUpdatedAt,
                fallbackLabel: displayName,
                radius: 48,
              ),
              const SizedBox(height: MortSpacing.sm),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (profile.username?.isNotEmpty == true) ...[
                const SizedBox(height: MortSpacing.xxs),
                Text('@${profile.username}'),
              ],
              const SizedBox(height: MortSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: MortSpacing.xs,
                runSpacing: MortSpacing.xs,
                children: [
                  MortStatusPill(
                    label: profile.verificationStatus.replaceAll('_', ' '),
                    icon: Icons.verified_user_outlined,
                    color: profile.verificationStatus == 'approved'
                        ? MortColors.success
                        : MortColors.lightBlue,
                  ),
                  MortStatusPill(
                    label: joined,
                    icon: Icons.calendar_today_outlined,
                    color: MortColors.silver,
                  ),
                ],
              ),
            ],
          ),
        ),
        const MortSectionLabel(label: 'Profile readiness'),
        MortProfileCompletionMeter(
          value: profile.completionRatio,
          items: [
            for (final item in profile.completionChecklist)
              (label: item.label, complete: item.complete),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        MortGlassSoftSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileFact(
                icon: Icons.family_restroom_outlined,
                label: 'Guardian Mode',
                value: profile.guardianSetupStatus.replaceAll('_', ' '),
              ),
              const Divider(height: MortSpacing.lg),
              _ProfileFact(
                icon: Icons.place_outlined,
                label: 'General area',
                value: _area(profile),
              ),
              const Divider(height: MortSpacing.lg),
              _ProfileFact(
                icon: Icons.schedule_outlined,
                label: 'Availability',
                value: profile.availability?.trim().isNotEmpty == true
                    ? profile.availability!
                    : 'Not added yet',
              ),
            ],
          ),
        ),
        if (profile.preferredJobCategories.isNotEmpty) ...[
          const MortSectionLabel(label: 'Interests'),
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              for (final category in profile.preferredJobCategories)
                MortStatusPill(
                  label: category,
                  color: MortColors.roseGoldLight,
                ),
            ],
          ),
        ],
        const MortSectionLabel(label: 'Profile extras'),
        const MortSparkSection(),
        const MortSectionLabel(label: 'Recent work'),
        ref
            .watch(myApplicationsProvider)
            .when(
              loading: () => const MortSkeletonCard(),
              error: (error, _) => MortErrorState(
                title: 'Recent work unavailable',
                message: userFacingError(error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(myApplicationsProvider),
                ),
              ),
              data: (applications) {
                final recent = applications
                    .where(
                      (application) =>
                          application.status == 'completed' ||
                          application.status == 'paid',
                    )
                    .take(3)
                    .toList(growable: false);
                if (recent.isEmpty) {
                  return const MortGlassSoftSurface(
                    child: Text('Completed jobs will appear here.'),
                  );
                }
                return MortGlassSoftSurface(
                  child: Column(
                    children: [
                      for (var index = 0; index < recent.length; index++) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: MortColors.success,
                          ),
                          title: Text(
                            recent[index].job?.title ?? 'Completed job',
                          ),
                          subtitle: Text(
                            recent[index].status.replaceAll('_', ' '),
                          ),
                          onTap: () => context.push(
                            '/teen/applications/${recent[index].id}',
                          ),
                        ),
                        if (index < recent.length - 1) const Divider(),
                      ],
                    ],
                  ),
                );
              },
            ),
        const MortSectionLabel(label: 'Account'),
        MortButton(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onPressed: () => context.push('/teen/profile/edit'),
        ),
        const SizedBox(height: MortSpacing.md),
        MortQuickActionGrid(
          actions: [
            MortAction(
              label: 'Saved jobs',
              icon: Icons.bookmark_outline_rounded,
              onPressed: () => context.push('/teen/saved'),
            ),
            MortAction(
              label: 'Activity',
              icon: Icons.history_rounded,
              onPressed: () => context.push('/settings/activity'),
            ),
            MortAction(
              label: 'Reviews',
              icon: Icons.star_outline_rounded,
              onPressed: () => context.push('/settings/reviews'),
            ),
            MortAction(
              label: 'Security & sign out',
              icon: Icons.phonelink_lock_outlined,
              onPressed: () => context.push('/settings/security-sessions'),
            ),
          ],
        ),
      ],
    );
  }

  String _area(Profile profile) {
    if (profile.approximateArea?.trim().isNotEmpty == true) {
      return profile.approximateArea!;
    }
    final parts = [profile.city, profile.state]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? 'Not added yet' : parts.join(', ');
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: MortColors.lightBlue),
      const SizedBox(width: MortSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: MortSpacing.xxs),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    ],
  );
}
