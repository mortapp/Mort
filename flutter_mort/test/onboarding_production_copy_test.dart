import 'package:flutter_mort/services/native_permissions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('notification permission labels report native truth', () {
    expect(notificationPermissionLabel(PermissionStatus.granted), 'Enabled');
    expect(
      notificationPermissionLabel(PermissionStatus.denied),
      'Not enabled yet',
    );
    expect(notificationPermissionLabel(PermissionStatus.restricted), 'Denied');
    expect(
      notificationPermissionLabel(PermissionStatus.permanentlyDenied),
      'Needs Settings',
    );
  });
}
