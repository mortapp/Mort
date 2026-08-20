import 'repository_base.dart';

class MonetizationRepository extends RepositoryBase {
  Future<Map<String, dynamic>> getMyEntitlements() async {
    final result = await client.rpc('get_my_entitlements');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> recordPaywallEvent({
    required String eventType,
    required String placement,
    String? offeringId,
    String? packageId,
    String? productId,
    String? errorMessage,
  }) async {
    await client.rpc(
      'record_paywall_event',
      params: {
        'p_event_type': eventType,
        'p_placement': placement,
        'p_offering_id': offeringId,
        'p_package_id': packageId,
        'p_product_id': productId,
        'p_error_message': errorMessage,
      },
    );
  }

  Future<Map<String, dynamic>> adEligibility(
    String placement,
    String format,
  ) async {
    final result = await client.rpc(
      'get_ad_eligibility',
      params: {'p_placement': placement, 'p_ad_format': format},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> recordAdImpression({
    required String placement,
    required String format,
    String? adUnitId,
    bool requestNonPersonalized = true,
  }) async {
    await client.rpc(
      'record_ad_impression',
      params: {
        'p_placement': placement,
        'p_ad_format': format,
        'p_ad_unit_id': adUnitId,
        'p_request_non_personalized': requestNonPersonalized,
      },
    );
  }

  Future<void> recordFeatureUsage({
    required String featureKey,
    String? entitlementRequired,
    bool allowed = false,
  }) async {
    await client.rpc(
      'record_feature_usage',
      params: {
        'p_feature_key': featureKey,
        'p_entitlement_required': entitlementRequired,
        'p_allowed': allowed,
      },
    );
  }

  Future<Map<String, dynamic>?> getSubscriptionStatus() async {
    final row = await client
        .from('user_subscription_status')
        .select()
        .eq('user_id', requireUserId())
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> getJobBoostCreditStatus() async {
    final result = await client.rpc('get_job_boost_credit_status');
    final rows = result as List<dynamic>;
    if (rows.isEmpty) {
      return {'available_credits': 0, 'used_credits': 0};
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>> consumeJobBoostCredit(String jobId) async {
    final result = await client.rpc(
      'consume_job_boost_credit',
      params: {'p_job_id': jobId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> getAdPreferences() async {
    final row = await client
        .from('user_ad_preferences')
        .select()
        .eq('user_id', requireUserId())
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> saveAdPreferences({
    required bool personalizedAdsAllowed,
    required bool adsConsentReady,
    required bool ageRestrictedAds,
  }) async {
    await client.from('user_ad_preferences').upsert({
      'user_id': requireUserId(),
      'personalized_ads_allowed': personalizedAdsAllowed,
      'ads_consent_ready': adsConsentReady,
      'age_restricted_ads': ageRestrictedAds,
      'last_prompted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
