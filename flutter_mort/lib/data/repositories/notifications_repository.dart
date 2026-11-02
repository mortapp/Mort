import '../models/notification_item.dart';
import 'repository_base.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.categories,
    required this.quietHoursEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.timezoneName,
  });

  final bool pushEnabled;
  final Map<String, bool> categories;
  final bool quietHoursEnabled;
  final String quietStart;
  final String quietEnd;
  final String timezoneName;

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    final rawCategories = Map<String, dynamic>.from(
      map['categories'] as Map? ?? const {},
    );
    return NotificationPreferences(
      // Remote device push is disabled for MORT. Keep server preferences
      // opted out while Supabase in-app notifications remain available.
      pushEnabled: false,
      categories: rawCategories.map(
        (key, value) => MapEntry(key, value == true),
      ),
      quietHoursEnabled: map['quiet_hours_enabled'] == true,
      quietStart: map['quiet_start']?.toString() ?? '21:00:00',
      quietEnd: map['quiet_end']?.toString() ?? '07:00:00',
      timezoneName: map['timezone_name']?.toString() ?? 'UTC',
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    Map<String, bool>? categories,
    bool? quietHoursEnabled,
    String? quietStart,
    String? quietEnd,
    String? timezoneName,
  }) => NotificationPreferences(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    categories: categories ?? this.categories,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    timezoneName: timezoneName ?? this.timezoneName,
  );
}

class NotificationsRepository extends RepositoryBase {
  Future<List<MortNotificationItem>> listMine() async {
    final rows = await client
        .from('notifications')
        .select()
        .eq('recipient_id', requireUserId())
        .order('created_at', ascending: false)
        .limit(60);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(MortNotificationItem.fromMap).toList();
  }

  Future<void> markRead(String id) async {
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead() async {
    await client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', requireUserId())
        .filter('read_at', 'is', null);
  }

  Future<NotificationPreferences> getPreferences() async {
    final response = Map<String, dynamic>.from(
      await client.rpc('get_my_notification_preferences') as Map,
    );
    _requireOk(response);
    return NotificationPreferences.fromMap(
      Map<String, dynamic>.from(response['preferences'] as Map),
    );
  }

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final response = Map<String, dynamic>.from(
      await client.rpc(
            'update_my_notification_preferences',
            params: {
              'p_push_enabled': false,
              'p_categories': preferences.categories,
              'p_quiet_hours_enabled': preferences.quietHoursEnabled,
              'p_quiet_start': preferences.quietStart,
              'p_quiet_end': preferences.quietEnd,
              'p_timezone_name': preferences.timezoneName,
            },
          )
          as Map,
    );
    _requireOk(response);
    return NotificationPreferences.fromMap(
      Map<String, dynamic>.from(response['preferences'] as Map),
    );
  }

  void _requireOk(Map<String, dynamic> response) {
    if (response['ok'] == true) return;
    throw StateError(
      response['code']?.toString() ?? 'notification_request_failed',
    );
  }
}
