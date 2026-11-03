import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/notification_item.dart';
import 'package:flutter_mort/data/repositories/notifications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/notifications/notification_center_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'saved push preference remains visible and can be disabled while delivery is off',
    (tester) async {
      final repository = _NotificationsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationCenterScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Allow remote alerts'),
      );
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNotNull);
    },
  );
}

class _NotificationsRepository extends NotificationsRepository {
  @override
  Future<List<MortNotificationItem>> listMine() async => const [];

  @override
  Future<NotificationPreferences> getPreferences() async =>
      const NotificationPreferences(
        pushEnabled: true,
        categories: {},
        quietHoursEnabled: false,
        quietStart: '21:00:00',
        quietEnd: '07:00:00',
        timezoneName: 'UTC',
      );

  @override
  Future<PushRegistrationStatus> getPushStatus() async =>
      const PushRegistrationStatus(
        remotePushEnabled: false,
        pushPreferenceEnabled: true,
        deliveryAvailable: false,
        activeDeviceCount: 0,
        provider: 'fcm',
        providerDeliveryVerified: false,
      );
}
