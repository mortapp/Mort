import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_mort/data/repositories/notifications_repository.dart';
import 'package:flutter_mort/services/push/remote_push_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permanent notification denial maps to denied permission', () {
    expect(
      remotePushPermissionFromFirebase(AuthorizationStatus.denied),
      RemotePushPermission.denied,
    );
  });

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

  test(
    'user preference cannot claim remote delivery while server delivery is off',
    () {
      final status = PushRegistrationStatus.fromMap({
        'remote_push_enabled': true,
        'push_preference_enabled': true,
        'delivery_available': false,
        'active_device_count': 1,
        'provider': 'fcm',
        'provider_delivery_verified': false,
      });

      expect(status.remotePushEnabled, isFalse);
      expect(status.pushPreferenceEnabled, isTrue);
      expect(status.deliveryAvailable, isFalse);
    },
  );

  test('unknown server availability fails closed for remote push status', () {
    final status = PushRegistrationStatus.fromMap({
      'remote_push_enabled': true,
      'push_preference_enabled': true,
      'active_device_count': 1,
    });

    expect(status.remotePushEnabled, isFalse);
    expect(status.deliveryAvailable, isFalse);
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
    expect(repository, contains('get_my_push_status_v2'));
    expect(repository, contains('get_push_delivery_availability'));
    expect(coordinator, contains('deliveryAvailable()'));
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

  test('permissions screen couples notification approval to registration', () {
    final screen = File(
      'lib/features/settings/native_permissions_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/native_permissions_service.dart',
    ).readAsStringSync();

    expect(screen, contains('requestPermissionAndRegister()'));
    expect(screen, contains('!_pushCoordinator.configured'));
    expect(screen, contains('Remote push is disabled in this build'));
    expect(service, isNot(contains('requestNotifications()')));
  });

  test('sign-out revokes backend tokens when app-side push is disabled', () {
    final coordinator = File(
      'lib/services/push/push_notification_coordinator.dart',
    ).readAsStringSync();
    final start = coordinator.indexOf('Future<void> prepareForSignOut(');
    final end = coordinator.indexOf(
      'Future<String> localTimezoneName()',
      start,
    );
    final signOut = coordinator.substring(start, end);

    expect(signOut, contains('unregisterDevices('));
    expect(signOut, isNot(contains('!_provider.configured')));
    expect(signOut, contains('if (_provider.configured)'));
  });
}
