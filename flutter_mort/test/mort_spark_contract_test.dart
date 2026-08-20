import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rewardedButton = File(
    '${Directory.current.path}/lib/features/ads/widgets/mort_rewarded_ad_button.dart',
  ).readAsStringSync();
  final sparkSection = File(
    '${Directory.current.path}/lib/features/ads/widgets/mort_spark_section.dart',
  ).readAsStringSync();
  final monetizationRepository = File(
    '${Directory.current.path}/lib/data/repositories/monetization_repository.dart',
  ).readAsStringSync();
  final teenProfileScreen = File(
    '${Directory.current.path}/lib/features/teen/teen_profile_screen.dart',
  ).readAsStringSync();
  final root = Directory.current.parent;
  final sparkMigration = File(
    '${root.path}/supabase/migrations/20260820120000_mort_spark_rewarded_ads.sql',
  ).readAsStringSync();

  test('the reward is granted only inside the SDK earned-reward callback', () {
    expect(rewardedButton, contains('onUserEarnedReward: (ad, reward) {'));
    expect(sparkSection, contains('MortNativeRewardedAdButton('));
    expect(sparkSection, contains('onReward: _handleReward'));
    expect(sparkSection, isNot(contains('onPressed: _handleReward')));
  });

  test('the grant call never fabricates the entitlement on failure', () {
    expect(sparkSection, contains('grantSparkReward()'));
    expect(sparkSection, contains('} catch (_) {'));
    expect(
      sparkSection,
      contains('never fabricate the cosmetic entitlement locally'),
    );
  });

  test('MORT Spark is gated behind the real ads SDK flags', () {
    expect(
      sparkSection,
      contains('if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled)'),
    );
    expect(sparkSection, contains('return const SizedBox.shrink();'));
  });

  test('the repository is idempotent and does not fabricate client state', () {
    expect(monetizationRepository, contains('grant_mort_spark_reward'));
    expect(
      monetizationRepository,
      contains("params: {'p_client_request_id': _uuid.v4()}"),
    );
    expect(monetizationRepository, contains('getActiveSparkExpiry'));
    expect(monetizationRepository, contains('mort_spark_grants'));
  });

  test('MORT Spark has a real, tasteful, non-sensitive UI entry point', () {
    expect(teenProfileScreen, contains('MortSparkSection'));
    expect(teenProfileScreen, isNot(contains("push('/teen/safety")));
  });

  test(
    'the server-side grant is cosmetic-only, cooldown-limited, and idempotent',
    () {
      expect(
        sparkMigration,
        contains('create or replace function public.grant_mort_spark_reward('),
      );
      expect(sparkMigration, contains('security definer'));
      expect(sparkMigration, contains("set search_path = ''"));
      expect(sparkMigration, contains('No marketplace, safety, ranking'));
      expect(sparkMigration, contains('mort_spark_grants_request_unique_idx'));
      expect(sparkMigration, contains("'cooldown_active'"));
      expect(sparkMigration, contains("v_cooldown constant interval"));
      expect(
        sparkMigration,
        contains('mort_spark_grants_select on public.mort_spark_grants'),
      );
      expect(
        sparkMigration,
        contains('user_id = (select auth.uid()) or public.is_admin()'),
      );
      expect(
        sparkMigration,
        isNot(contains('create policy mort_spark_grants_insert')),
      );
      expect(
        sparkMigration,
        contains('revoke all on function public.grant_mort_spark_reward(uuid)'),
      );
    },
  );

  test('no OAuth or server secret identifier is embedded as a value', () {
    final combined = '$sparkSection\n$monetizationRepository';
    expect(combined, isNot(contains('client_secret=')));
    expect(combined, isNot(contains('service_role=')));
    expect(combined, isNot(contains('debugPrint(')));
    expect(combined, isNot(contains('print(')));
  });
}
