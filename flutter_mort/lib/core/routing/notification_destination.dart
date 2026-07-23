import '../../data/models/profile.dart';

final _notificationUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String notificationDestination(Map<String, dynamic> data, UserRole? role) {
  final threadId = _uuid(data['threadId']);
  if (threadId != null) return '/messages/$threadId';

  final supportTicketId = _uuid(data['supportTicketId']);
  if (supportTicketId != null) return '/support/ticket/$supportTicketId';

  if (_uuid(data['reviewId']) != null) return '/settings/reviews';
  if (_uuid(data['guardianLinkId']) != null) {
    return '/settings/guardian-mode';
  }

  final applicationId = _uuid(data['applicationId']);
  if (applicationId != null) {
    return switch (role) {
      UserRole.adult => '/adult/applicants/$applicationId',
      UserRole.guardian => '/guardian/approvals/$applicationId',
      UserRole.teen => '/teen/applications/$applicationId',
      _ => '/account-status',
    };
  }

  final jobId = _uuid(data['jobId']);
  if (jobId != null) {
    return switch (role) {
      UserRole.adult => '/adult/jobs/$jobId',
      UserRole.teen => '/teen/jobs/$jobId',
      _ => '/account-status',
    };
  }

  if (_uuid(data['safetyPingId']) != null) {
    return switch (role) {
      UserRole.admin => '/admin/safety-pings',
      UserRole.guardian => '/guardian/safety-pings',
      UserRole.teen => '/teen/safety',
      _ => '/account-status',
    };
  }
  return '/account-status';
}

String? _uuid(Object? value) {
  final candidate = value?.toString().trim();
  return candidate != null && _notificationUuid.hasMatch(candidate)
      ? candidate.toLowerCase()
      : null;
}
