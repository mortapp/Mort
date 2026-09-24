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
  final ssvMigration = File(
    '${root.path}/supabase/migrations/20260923160000_mort_pro_revenuecat_and_ad_eligibility.sql',
  ).readAsStringSync();

  test(
    'the SDK callback only observes the reward; the server grants Spark',
    () {
      expect(rewardedButton, contains('onUserEarnedReward: (ad, reward) {'));
      expect(rewardedButton, contains('setServerSideOptions('));
      expect(rewardedButton, contains("customData: 'mort_spark'"));
      expect(sparkSection, contains('MortNativeRewardedAdButton('));
      expect(sparkSection, contains('onReward: _handleReward'));
      expect(sparkSection, isNot(contains('onPressed: _handleReward')));
    },
  );

  test('the client cannot invoke the old grant RPC', () {
    expect(sparkSection, isNot(contains('grantSparkReward()')));
    expect(monetizationRepository, isNot(contains('grant_mort_spark_reward')));
    expect(
      ssvMigration,
      contains(
        'revoke execute on function public.grant_mort_spark_reward(uuid)',
      ),
    );
  });

  test('MORT Spark is gated behind the real ads SDK flags', () {
    expect(
      sparkSection,
      contains('if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled)'),
    );
    expect(sparkSection, contains('return const SizedBox.shrink();'));
  });

  test('the repository reads only server-authoritative Spark state', () {
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
      expect(ssvMigration, contains('create table public.admob_reward_events'));
      expect(
        ssvMigration,
        contains('create or replace function public.process_mort_spark_ssv('),
      );
      expect(
        ssvMigration,
        contains("if (select auth.role()) <> 'service_role' then"),
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
