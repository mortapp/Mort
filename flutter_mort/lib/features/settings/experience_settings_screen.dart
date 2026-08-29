import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/preferences/mort_experience_preferences.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';

class ExperienceSettingsScreen extends ConsumerWidget {
  const ExperienceSettingsScreen({super.key, this.appearanceFirst = false});

  final bool appearanceFirst;

  Future<void> _change(
    BuildContext context,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } catch (error) {
      if (context.mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(mortExperiencePreferencesProvider);
    return MortScreen(
      children: [
        MortGlassHeader(
          eyebrow: appearanceFirst ? 'Appearance' : 'Accessibility',
          title: appearanceFirst ? 'How MORT looks' : 'How MORT feels',
          subtitle:
              'These private preferences stay on this device and take effect immediately.',
        ),
        const SizedBox(height: MortSpacing.md),
        preferences.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Preferences unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(mortExperiencePreferencesProvider),
            ),
          ),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MortSectionLabel(label: 'Accessibility'),
              MortGlassCard(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: value.reducedMotion,
                      title: const Text('Reduce motion'),
                      subtitle: const Text(
                        'Stops MORT brand, navigation, and control animations. Device reduced-motion settings are always honored too.',
                      ),
                      onChanged: (enabled) => _change(
                        context,
                        () => ref
                            .read(mortExperiencePreferencesProvider.notifier)
                            .setReducedMotion(enabled),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: value.highContrast,
                      title: const Text('Increase contrast'),
                      subtitle: const Text(
                        'Strengthens borders and removes translucent surfaces where contrast matters.',
                      ),
                      onChanged: (enabled) => _change(
                        context,
                        () => ref
                            .read(mortExperiencePreferencesProvider.notifier)
                            .setHighContrast(enabled),
                      ),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: value.hapticsEnabled,
                      title: const Text('Control haptics'),
                      subtitle: const Text(
                        'Allows subtle vibration for PIN entry and confirmed job actions. Emergency behavior never depends on haptics.',
                      ),
                      onChanged: (enabled) => _change(
                        context,
                        () => ref
                            .read(mortExperiencePreferencesProvider.notifier)
                            .setHapticsEnabled(enabled),
                      ),
                    ),
                  ],
                ),
              ),
              const MortSectionLabel(label: 'Appearance and performance'),
              MortGlassCard(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: value.reducedTransparency,
                      title: const Text('Reduce transparency'),
                      subtitle: const Text(
                        'Uses solid glass fallbacks and disables live blur. This can improve readability and performance on lower-cost phones.',
                      ),
                      onChanged: (enabled) => _change(
                        context,
                        () => ref
                            .read(mortExperiencePreferencesProvider.notifier)
                            .setReducedTransparency(enabled),
                      ),
                    ),
                    const Divider(),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.dark_mode_outlined,
                        color: MortColors.lightBlue,
                      ),
                      title: Text('Dark appearance'),
                      subtitle: Text(
                        'MORT currently supports its high-contrast dark identity only. Device text size remains the source of truth.',
                      ),
                      trailing: MortBadge(label: 'Active'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MortSpacing.md),
              const MortSafetyBanner(
                message:
                    'Accessibility preferences never change role checks, safety controls, verification, or marketplace access.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortGlassHeader(
        eyebrow: 'Privacy',
        title: 'Control what MORT can use',
        subtitle:
            'MORT uses approximate areas for discovery and keeps exact teen location, messages, and evidence private.',
      ),
      const MortSectionLabel(label: 'Location and visibility'),
      MortDashboardActionTile(
        label: 'Device permissions',
        description:
            'Review foreground location, camera, photos, and notifications.',
        icon: Icons.location_on_outlined,
        onPressed: () => context.push('/settings/native-permissions'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Edit public-safe profile',
        description:
            'Change your display information and approximate area. Exact addresses are not accepted.',
        icon: Icons.visibility_outlined,
        onPressed: () => context.push('/settings/profile'),
      ),
      const MortSectionLabel(label: 'Sharing and boundaries'),
      MortDashboardActionTile(
        label: 'Guardian Mode',
        description:
            'Review optional linked-teen sharing and its privacy boundaries.',
        icon: Icons.family_restroom_outlined,
        onPressed: () => context.push('/settings/guardian-mode'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Blocked accounts',
        description: 'Review and reverse account blocks you created.',
        icon: Icons.block_outlined,
        onPressed: () => context.push('/settings/blocked-users'),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortSafetyBanner(
        message:
            'MORT does not expose a teen\'s exact location to job posters. Guardian Mode does not grant unrestricted message access.',
      ),
    ],
  );
}

class SafetySettingsScreen extends StatelessWidget {
  const SafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortGlassHeader(
        eyebrow: 'Safety',
        title: 'Safety controls stay free',
        subtitle:
            'Reporting, blocking, Safety Ping, and core Guardian Mode do not require a purchase.',
      ),
      MortDashboardActionTile(
        label: 'Safety Center',
        description:
            'Open check-ins, Safety Ping, active-job tools, and emergency guidance.',
        icon: Icons.health_and_safety_outlined,
        onPressed: () => context.push('/safety'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Safety Circle',
        description: 'Manage consent-based trusted contact relationships.',
        icon: Icons.group_outlined,
        onPressed: () => context.push('/settings/safety-circle'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Safety cases',
        description: 'Review your authorized incident and safety case status.',
        icon: Icons.folder_shared_outlined,
        onPressed: () => context.push('/settings/safety-cases'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Report a concern',
        description: 'Report unsafe conduct, a job, a message, or an account.',
        icon: Icons.report_outlined,
        onPressed: () => context.push('/report'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Teen safety standards',
        description: 'Review prohibited work and child-safety boundaries.',
        icon: Icons.policy_outlined,
        onPressed: () => context.push('/legal/teen-safety'),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortSafetyBanner(
        message:
            'MORT is not an emergency service. In immediate danger, move to safety and contact local emergency services.',
      ),
    ],
  );
}

class DataControlsScreen extends StatelessWidget {
  const DataControlsScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortGlassHeader(
        eyebrow: 'Data controls',
        title: 'Your account data',
        subtitle:
            'Deletion is available in-app. Self-service full account export is not available yet.',
      ),
      MortDashboardActionTile(
        label: 'Activity history',
        description: 'Review account-visible job and safety activity.',
        icon: Icons.history_rounded,
        onPressed: () => context.push('/settings/activity'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Request account deletion',
        description:
            'Reconfirm your identity and submit or cancel a server-tracked deletion request.',
        icon: Icons.delete_outline,
        onPressed: () => context.push('/settings/account-deletion'),
      ),
      const SizedBox(height: MortSpacing.md),
      const MortGlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download_outlined, color: MortColors.silver),
          title: Text('Full account export'),
          subtitle: Text(
            'Self-service export is not available yet. Contact Support to make a privacy request.',
          ),
          trailing: MortBadge(label: 'Unavailable'),
        ),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortGlassButton(
        label: 'Contact Support',
        icon: Icons.support_agent_outlined,
        onPressed: () => context.push('/support'),
      ),
    ],
  );
}

class AboutMortScreen extends StatelessWidget {
  const AboutMortScreen({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortGlassHeader(
        eyebrow: 'About',
        title: 'MORT',
        subtitle: 'Safe neighborhood jobs. For teens. By community.',
      ),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const MortSkeletonCard();
          final package = snapshot.requireData;
          return MortGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${package.version} (${package.buildNumber})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Open-source licenses',
        description: 'Review licenses for software included with MORT.',
        icon: Icons.code_rounded,
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'MORT',
          applicationLegalese: 'MORT. All rights reserved.',
        ),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDashboardActionTile(
        label: 'Legal and safety documents',
        description: 'Open the current legal center and safety standards.',
        icon: Icons.policy_outlined,
        onPressed: () => context.push('/settings/legal'),
      ),
    ],
  );
}
