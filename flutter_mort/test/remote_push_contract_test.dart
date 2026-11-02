import 'dart:io';
import 'dart:convert';

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
    expect(preferences.pushEnabled, isFalse);
    expect(preferences.categories['new_messages'], isFalse);
    expect(preferences.quietStart, '22:15:00');
    expect(preferences.timezoneName, 'America/Indiana/Indianapolis');
    expect(preferences.copyWith(pushEnabled: false).pushEnabled, isFalse);
  });

  test('Firebase stays dormant and Supabase remains the notification backend', () {
    final appConfig = File(
      'lib/core/config/app_config.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/services/push/push_notification_coordinator.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/services/push/remote_push_provider.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final app = File('lib/app.dart').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final repository = File(
      'lib/data/repositories/notifications_repository.dart',
    ).readAsStringSync();
    final edge = File(
      '../supabase/functions/send-push/index.ts',
    ).readAsStringSync();
    expect(appConfig, contains('static const remotePushEnabled = false;'));
    expect(appConfig, contains('FIREBASE_ANDROID_APP_ID'));
    expect(appConfig, contains('FIREBASE_IOS_APP_ID'));
    expect(
      provider,
      contains(
        'RemotePushProvider createRemotePushProvider() =>\n    const DisabledRemotePushProvider();',
      ),
    );
    expect(coordinator, isNot(contains('register_my_push_device_v2')));
    expect(coordinator, isNot(contains('unregister_my_push_devices_v2')));
    expect(repository, isNot(contains('register_my_push_device_v2')));
    expect(repository, isNot(contains('unregister_my_push_devices_v2')));
    expect(repository, contains(".from('notifications')"));
    expect(repository, contains("'p_push_enabled': false"));
    expect(main, isNot(contains('configureRemotePushBackgroundHandler();')));
    expect(app, isNot(contains('foregroundMessages.listen')));
    expect(app, isNot(contains('openedMessages.listen')));
    expect(
      androidManifest,
      contains(
        'android:name="com.google.firebase.provider.FirebaseInitProvider"',
      ),
    );
    expect(
      androidManifest,
      contains(
        'android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"',
      ),
    );
    expect(
      androidManifest,
      contains(
        'android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver"',
      ),
    );
    expect(
      androidManifest,
      contains(
        'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingInitProvider',
      ),
    );
    expect(
      androidManifest,
      contains(
        'io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingBackgroundService',
      ),
    );
    expect(
      androidManifest,
      contains(
        'android:name="com.google.firebase.components.ComponentDiscoveryService"',
      ),
    );
    expect(androidManifest, contains('tools:node="remove"'));
    expect(
      androidManifest,
      contains('android.permission.POST_NOTIFICATIONS" tools:node="remove"'),
    );
    expect(
      iosInfoPlist,
      isNot(contains('NSUserNotificationsUsageDescription')),
    );
    expect(provider, contains("@pragma('vm:entry-point')"));
    expect(provider, contains('FirebaseMessaging.onMessage'));
    expect(provider, contains('dormant source per product direction'));
    expect(edge, contains('const remotePushDeliveryEnabled = false;'));
    expect(edge, contains('code: "remote_push_disabled"'));
    expect(
      edge.indexOf('if (!remotePushDeliveryEnabled)'),
      lessThan(edge.indexOf('const payload = await readPayload(request);')),
    );
  });

  test('Firebase remote push stays dormant in app and every release profile', () {
    final appConfig = File(
      'lib/core/config/app_config.dart',
    ).readAsStringSync();
    final provider = File(
      'lib/services/push/remote_push_provider.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/services/push/push_notification_coordinator.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final screen = File(
      'lib/features/notifications/notification_center_screen.dart',
    ).readAsStringSync();
    final profileFile = Map<String, dynamic>.from(
      jsonDecode(
            File('../config/mort-release-profiles.json').readAsStringSync(),
          )
          as Map,
    );
    final profiles = Map<String, dynamic>.from(profileFile['profiles'] as Map);

    expect(appConfig, contains('static const remotePushEnabled = false;'));
    expect(
      provider,
      contains(
        'RemotePushProvider createRemotePushProvider() =>\n    const DisabledRemotePushProvider();',
      ),
    );
    expect(main, isNot(contains('configureRemotePushBackgroundHandler();')));
    expect(coordinator, isNot(contains('register_my_push_device_v2')));
    expect(coordinator, isNot(contains('unregister_my_push_devices_v2')));
    expect(screen, contains('Updates in this inbox are provided by Supabase.'));
    expect(screen, contains('Device push alerts are turned off.'));
    expect(screen, isNot(contains('Allow remote alerts')));
    for (final entry in profiles.entries) {
      final profile = Map<String, dynamic>.from(entry.value as Map);
      expect(profile['remotePushEnabled'], isFalse, reason: entry.key);
    }
  });

  test(
    'permissions screen does not request push while remote alerts are disabled',
    () {
      final screen = File(
        'lib/features/settings/native_permissions_screen.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/native_permissions_service.dart',
      ).readAsStringSync();

      expect(screen, contains('does not request device push permission'));
      expect(screen, isNot(contains('requestPermissionAndRegister()')));
      expect(screen, isNot(contains('PushNotificationCoordinator')));
      expect(service, isNot(contains('requestNotifications()')));
    },
  );
}
