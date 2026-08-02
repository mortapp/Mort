import 'dart:io';

import 'package:flutter_mort/data/repositories/notifications_repository.dart';
import 'package:flutter_mort/services/push/remote_push_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled provider is a safe no-op', () async {
    const provider = DisabledRemotePushProvider();
    await provider.initialize();
    expect(provider.configured, isFalse);
    expect(await provider.permissionStatus(), RemotePushPermission.unavailable);
    expect(await provider.registrationToken(), isNull);
    expect(await provider.initialMessage(), isNull);
    await provider.deleteToken();
  });

  test('notification preferences parse all server-controlled settings', () {
    final preferences = NotificationPreferences.fromMap({
      'push_enabled': true,
      'categories': {'application_updates': true, 'new_messages': false},
      'quiet_hours_enabled': true,
      'quiet_start': '22:15:00',
      'quiet_end': '06:45:00',
      'timezone_name': 'America/Indiana/Indianapolis',
    });
    expect(preferences.pushEnabled, isTrue);
    expect(preferences.categories['new_messages'], isFalse);
    expect(preferences.quietStart, '22:15:00');
    expect(preferences.timezoneName, 'America/Indiana/Indianapolis');
    expect(preferences.copyWith(pushEnabled: false).pushEnabled, isFalse);
  });

  test('mobile push source keeps provider secrets server-side', () {
    final appConfig = File(
      'lib/core/config/app_config.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/services/push/push_notification_coordinator.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/services/push/remote_push_provider.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/data/repositories/notifications_repository.dart',
    ).readAsStringSync();
    final edge = File(
      '../supabase/functions/send-push/index.ts',
    ).readAsStringSync();

    expect(appConfig, contains("defaultValue: false"));
    expect(appConfig, contains('FIREBASE_ANDROID_APP_ID'));
    expect(appConfig, contains('FIREBASE_IOS_APP_ID'));
    expect(coordinator, contains('registerDevice('));
    expect(coordinator, contains('unregisterDevices('));
    expect(repository, contains('register_my_push_device_v2'));
    expect(repository, contains('unregister_my_push_devices_v2'));
    expect(provider, contains("@pragma('vm:entry-point')"));
    expect(provider, contains('getInitialMessage'));
    expect(provider, contains('onMessageOpenedApp'));
    expect(edge, contains('FCM_SERVICE_ACCOUNT_PRIVATE_KEY'));
    expect(edge, contains('service_claim_push_events'));
    expect(edge, contains('genericCopy'));
    for (final source in [appConfig, coordinator, provider]) {
      expect(source, isNot(contains('FCM_SERVICE_ACCOUNT_PRIVATE_KEY')));
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    }
  });
}
