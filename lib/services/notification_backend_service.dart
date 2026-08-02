import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/backend_notification.dart';

class NotificationBackendService {
  NotificationBackendService._();
  static final NotificationBackendService instance =
      NotificationBackendService._();
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> loadNotificationsForUser(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      return response.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> markAllReadForUser(String userId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendNotification(BackendNotification n) async {
    try {
      await _client.from('notifications').insert({
        'user_id': n.profileId,
        'title': n.title,
        'body': n.body,
        'notification_type': 'general',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
