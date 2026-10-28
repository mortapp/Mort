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
    expect(await provider.initialMessage(), isNull);
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

  test('no Firebase push worker is present in the production backend', () {
    final pushWorker = File('../supabase/functions/send-push/index.ts');
    final supabaseConfig = File('../supabase/config.toml').readAsStringSync();
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
    expect(pushWorker.existsSync(), isFalse);
    expect(supabaseConfig, isNot(contains('[functions.send-push]')));
    expect(appConfig, contains("defaultValue: false"));
    expect(appConfig, isNot(contains('FIREBASE_')));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('firebase_')),
    );
    expect(provider, isNot(contains('Firebase')));
    expect(createRemotePushProvider().configured, isFalse);
    expect(coordinator, isNot(contains('registerDevice(')));
    expect(coordinator, isNot(contains('unregisterDevices(')));
    expect(coordinator, isNot(contains('registrationToken')));
    expect(repository, isNot(contains('register_my_push_device_v2')));
    expect(repository, isNot(contains('unregister_my_push_devices_v2')));

    for (final source in [appConfig, coordinator, provider, repository]) {
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('FCM')));
      expect(source, isNot(contains('FCM_SERVICE_ACCOUNT_PRIVATE_KEY')));
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    }
  });

  test('permissions screen does not request OS access without a provider', () {
    final screen = File(
      'lib/features/settings/native_permissions_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/native_permissions_service.dart',
    ).readAsStringSync();

    expect(screen, contains('requestPermission()'));
    expect(screen, contains('!_pushCoordinator.configured'));
    expect(screen, contains('Remote push is disabled in this build'));
    expect(service, isNot(contains('requestNotifications()')));
  });
}
