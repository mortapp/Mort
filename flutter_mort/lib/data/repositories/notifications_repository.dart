import '../models/notification_item.dart';
import 'repository_base.dart';

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
}
