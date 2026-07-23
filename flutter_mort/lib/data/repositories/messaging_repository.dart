import '../models/message.dart';
import '../../core/errors/mort_error.dart';
import 'repository_base.dart';

class MessagingRepository extends RepositoryBase {
  Future<List<MessageThread>> listThreads() async {
    requireUserId();
    final rows = await client.rpc('get_my_message_threads');
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(MessageThread.fromMap).toList();
  }

  Future<List<MortMessage>> listMessages(String threadId) async {
    final rows = await client
        .from('messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(MortMessage.fromMap).toList();
  }

  Future<MortMessage> sendSafeMessage(String threadId, String body) async {
    final row = await client.rpc(
      'send_safe_message',
      params: {'p_thread_id': threadId, 'p_body': body.trim()},
    );
    return MortMessage.fromMap(Map<String, dynamic>.from(row as Map));
  }

  Future<void> markThreadRead(String threadId) async {
    final value = await client.rpc(
      'mark_message_thread_read',
      params: {'p_thread_id': threadId},
    );
    if (value is! Map) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected read-state response.',
      );
    }
    final result = Map<String, dynamic>.from(value);
    if (result['ok'] != true) {
      throw MortCodedError(
        (result['code'] as String?) ?? 'unknown_permission_failure',
        'The conversation read state could not be updated.',
      );
    }
  }
}
