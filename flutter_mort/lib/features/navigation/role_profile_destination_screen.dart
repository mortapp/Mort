import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

/// A read-only profile landing page for adult and guardian tabs. Editing stays
/// in the existing guarded Settings route.
class RoleProfileDestinationScreen extends ConsumerWidget {
  const RoleProfileDestinationScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return MortScreen(
      children: [
        MortHeader(
          title: 'Profile',
          subtitle: role == UserRole.guardian
              ? 'Your guardian account and controls.'
              : 'Your account and work profile.',
          showBackButton: false,
          trailing: MortSettingsButton(
            onPressed: () => context.push('/settings'),
          ),
        ),
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
                  message: 'Complete onboarding to view your profile.',
                )
              : _ProfileBody(profile: value, role: role),
        ),
      ],
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.role});

  final Profile profile;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName?.trim().isNotEmpty == true
        ? profile.displayName!.trim()
        : 'MORT member';
    final area = [
      profile.city,
      profile.state,
    ].where((part) => part?.trim().isNotEmpty == true).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortCard(
          child: Column(
            children: [
              MortAvatar(label: name, radius: 40),
              const SizedBox(height: MortSpacing.sm),
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              if (profile.username?.trim().isNotEmpty == true)
                Text(
                  '@${profile.username!.trim()}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: MortSpacing.sm),
              MortBadge(
                label: profile.verificationStatus.replaceAll('_', ' '),
                icon: Icons.verified_user_outlined,
              ),
              if (area.isNotEmpty) ...[
                const SizedBox(height: MortSpacing.sm),
                Text('General area: $area'),
              ],
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.lg),
        MortProfileCompletionMeter(
          value: profile.completionRatio,
          items: [
            for (final item in profile.completionChecklist)
              (label: item.label, complete: item.complete),
          ],
        ),
        const SizedBox(height: MortSpacing.lg),
        MortButton(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onPressed: () => context.push('/settings/profile'),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: role == UserRole.guardian ? 'Guardian controls' : 'My jobs',
          icon: role == UserRole.guardian
              ? Icons.family_restroom_outlined
              : Icons.work_outline,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push(
            role == UserRole.guardian
                ? '/guardian/linked-teens'
                : '/adult/jobs',
          ),
        ),
      ],
    );
  }
}
