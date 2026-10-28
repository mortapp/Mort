import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/notification_item.dart';
import 'package:flutter_mort/data/repositories/notifications_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/notifications/notification_center_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationsRepository extends NotificationsRepository {
  int getPreferencesCalls = 0;
  int getPushStatusCalls = 0;

  @override
  Future<List<MortNotificationItem>> listMine() async => const [];

  @override
  Future<NotificationPreferences> getPreferences() async {
    getPreferencesCalls += 1;
    return const NotificationPreferences(
      pushEnabled: true,
      categories: {},
      quietHoursEnabled: false,
      quietStart: '21:00:00',
      quietEnd: '07:00:00',
      timezoneName: 'UTC',
    );
  }

  @override
  Future<PushRegistrationStatus> getPushStatus() async {
    getPushStatusCalls += 1;
    return const PushRegistrationStatus(
      remotePushEnabled: false,
      activeDeviceCount: 0,
      provider: 'disabled',
      providerDeliveryVerified: false,
    );
  }
}

void main() {
  test('unknown push provider defaults to disabled, never FCM', () {
    final status = PushRegistrationStatus.fromMap(const {
      'remote_push_enabled': false,
      'active_device_count': 0,
    });

    expect(status.provider, 'disabled');
  });

  testWidgets('explains remote alerts are disabled and inbox updates remain', (
    tester,
  ) async {
    final repository = _FakeNotificationsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(home: NotificationCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Remote alerts are disabled in this app. In-app updates remain available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Disabled for this app'), findsOneWidget);
    expect(repository.getPreferencesCalls, 0);
    expect(repository.getPushStatusCalls, 0);

    final remoteAlertsSwitch = tester.widget<SwitchListTile>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Remote alerts',
      ),
    );
    expect(remoteAlertsSwitch.value, isFalse);
    expect(remoteAlertsSwitch.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
