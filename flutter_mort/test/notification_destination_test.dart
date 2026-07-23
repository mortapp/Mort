import 'package:flutter_mort/core/routing/notification_destination.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '123e4567-e89b-42d3-a456-426614174000';

  test('notification routes use role-correct UUID destinations', () {
    expect(
      notificationDestination({'applicationId': id}, UserRole.teen),
      '/teen/applications/$id',
    );
    expect(
      notificationDestination({'applicationId': id}, UserRole.adult),
      '/adult/applicants/$id',
    );
    expect(
      notificationDestination({'supportTicketId': id}, UserRole.guardian),
      '/support/ticket/$id',
    );
    expect(
      notificationDestination({'threadId': id}, UserRole.teen),
      '/messages/$id',
    );
  });

  test('forged paths, URLs, and unknown roles fail closed', () {
    for (final payload in [
      {'threadId': '../../admin/users'},
      {'jobId': 'https://attacker.example'},
      {'applicationId': '$id/../../admin'},
      {'route': '/admin/users'},
    ]) {
      expect(
        notificationDestination(payload, UserRole.teen),
        '/account-status',
      );
    }
    expect(
      notificationDestination({'jobId': id}, UserRole.guardian),
      '/account-status',
    );
  });

  test('safety pings route only to supported role surfaces', () {
    expect(
      notificationDestination({'safetyPingId': id}, UserRole.admin),
      '/admin/safety-pings',
    );
    expect(
      notificationDestination({'safetyPingId': id}, UserRole.guardian),
      '/guardian/safety-pings',
    );
    expect(
      notificationDestination({'safetyPingId': id}, UserRole.adult),
      '/account-status',
    );
  });
}
