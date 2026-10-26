import 'package:flutter_mort/services/push/push_registration_workflow.dart';
import 'package:flutter_mort/services/push/remote_push_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved push opt-out prevents automatic token registration', () async {
    var permissionChecks = 0;
    var tokenReads = 0;
    var registrations = 0;

    final registered = await PushRegistrationWorkflow().run(
      deliveryAvailable: () async => true,
      pushPreferenceEnabled: () async => false,
      permissionStatus: () async {
        permissionChecks++;
        return RemotePushPermission.authorized;
      },
      registrationToken: () async {
        tokenReads++;
        return 'fresh-fcm-registration-token';
      },
      register: (_, _) async {
        registrations++;
      },
    );

    expect(registered, isFalse);
    expect(permissionChecks, 0);
    expect(tokenReads, 0);
    expect(registrations, 0);
  });

  test(
    'enabled preference registers only after delivery and permission checks',
    () async {
      var registrations = 0;
      final calls = <String>[];

      final registered = await PushRegistrationWorkflow().run(
        deliveryAvailable: () async {
          calls.add('delivery');
          return true;
        },
        pushPreferenceEnabled: () async {
          calls.add('preference');
          return true;
        },
        permissionStatus: () async {
          calls.add('permission');
          return RemotePushPermission.authorized;
        },
        registrationToken: () async {
          calls.add('token');
          return 'fresh-fcm-registration-token';
        },
        register: (token, permission) async {
          calls.add('register');
          expect(token, 'fresh-fcm-registration-token');
          expect(permission, RemotePushPermission.authorized);
          registrations++;
        },
      );

      expect(registered, isTrue);
      expect(registrations, 1);
      expect(calls, ['delivery', 'preference', 'permission', 'token', 'register']);
    },
  );
}
