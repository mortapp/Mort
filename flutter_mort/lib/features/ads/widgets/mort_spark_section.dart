import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/repositories/providers.dart';
import 'mort_rewarded_ad_button.dart';

/// Optional, purely cosmetic 24h profile accent unlocked by watching a
/// rewarded ad to completion. No job ranking, Quick Accept, leaderboard,
/// safety, moderation, marketplace-priority, or job-eligibility effect --
/// decoration only. State is server-authoritative (grant_mort_spark_reward)
/// so it is correct across devices and cannot be forged client-side.
class MortSparkSection extends ConsumerStatefulWidget {
  const MortSparkSection({super.key});

  @override
  ConsumerState<MortSparkSection> createState() => _MortSparkSectionState();
}

class _MortSparkSectionState extends ConsumerState<MortSparkSection> {
  late Future<DateTime?> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<DateTime?> _loadStatus() =>
      ref.read(monetizationRepositoryProvider).getActiveSparkExpiry();

  Future<void> _handleReward() async {
    try {
      await ref.read(monetizationRepositoryProvider).grantSparkReward();
    } catch (_) {
      // Fail closed: never fabricate the cosmetic entitlement locally if
      // the server call fails. The status refresh below will simply show
      // the entitlement as still inactive.
    }
    if (!mounted) return;
    setState(() => _statusFuture = _loadStatus());
  }

  String _remaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.inMinutes <= 0) return 'less than a minute';
    if (remaining.inHours < 1) return '${remaining.inMinutes} min';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<DateTime?>(
      future: _statusFuture,
      builder: (context, snapshot) {
        final expiresAt = snapshot.data;
        final active = expiresAt != null;
        return MortGlassSoftSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: MortColors.roseGold,
                  ),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MORT Spark',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: MortSpacing.xxs),
                        Text(
                          active
                              ? 'Active for another ${_remaining(expiresAt)} -- a cosmetic profile accent only. No job, ranking, or eligibility effect.'
                              : 'Optional cosmetic profile accent. Watching an ad never affects jobs, Quick Accept, the leaderboard, or safety.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.sm),
              MortNativeRewardedAdButton(
                placement: 'profile_spark',
                label: active
                    ? 'Extend MORT Spark'
                    : 'Watch an ad for MORT Spark',
                onReward: _handleReward,
              ),
            ],
          ),
        );
      },
    );
  }
}
