import 'repository_base.dart';

class AnalyticsPreference {
  const AnalyticsPreference({
    required this.productAnalyticsOptIn,
    this.consentVersion,
    this.consentedAt,
  });

  final bool productAnalyticsOptIn;
  final String? consentVersion;
  final DateTime? consentedAt;

  factory AnalyticsPreference.fromMap(Map<String, dynamic> value) =>
      AnalyticsPreference(
        productAnalyticsOptIn: value['product_analytics_opt_in'] == true,
        consentVersion: value['consent_version'] as String?,
        consentedAt: DateTime.tryParse(value['consented_at']?.toString() ?? ''),
      );
}

class ObservabilityRepository extends RepositoryBase {
  Future<AnalyticsPreference> analyticsPreference() async {
    requireUserId();
    final result = await client.rpc('get_my_analytics_preferences');
    final value = Map<String, dynamic>.from(result as Map);
    _requireSuccess(value, 'Analytics privacy settings are unavailable.');
    return AnalyticsPreference.fromMap(value);
  }

  Future<AnalyticsPreference> updateAnalyticsPreference(bool optIn) async {
    requireUserId();
    final result = await client.rpc(
      'update_my_analytics_preferences',
      params: {
        'p_product_analytics_opt_in': optIn,
        'p_consent_version': 'analytics-2026-07',
      },
    );
    final value = Map<String, dynamic>.from(result as Map);
    _requireSuccess(value, 'Analytics privacy settings could not be updated.');
    return analyticsPreference();
  }

  Future<void> recordProductEvent({
    required String eventName,
    required String surface,
    required String outcome,
    required String platform,
    required String appVersion,
    required String releaseStage,
    required String clientRequestId,
  }) async {
    requireUserId();
    await client.rpc(
      'record_my_product_analytics',
      params: {
        'p_event_name': eventName,
        'p_surface': surface,
        'p_outcome': outcome,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_release_stage': releaseStage,
        'p_client_request_id': clientRequestId,
      },
    );
  }

  Future<void> recordOperationalEvent({
    required String eventType,
    required String safeCode,
    required String correlationId,
    required String platform,
    required String appVersion,
    required String releaseStage,
    required String clientRequestId,
  }) async {
    requireUserId();
    await client.rpc(
      'record_my_client_operational_event',
      params: {
        'p_event_type': eventType,
        'p_safe_code': safeCode,
        'p_correlation_id': correlationId,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_release_stage': releaseStage,
        'p_client_request_id': clientRequestId,
      },
    );
  }

  void _requireSuccess(Map<String, dynamic> result, String fallback) {
    if (result['ok'] == true) return;
    throw StateError(result['code']?.toString() ?? fallback);
  }
}
