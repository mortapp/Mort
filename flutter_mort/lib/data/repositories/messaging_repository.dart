import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  Future<MessagePage> listMessagesPage(
    String threadId, {
    MessagePageCursor? cursor,
    int limit = 40,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'list_thread_messages_page',
      params: {
        'p_thread_id': threadId,
        'p_cursor_created_at': cursor?.createdAt.toIso8601String(),
        'p_cursor_id': cursor?.id,
        'p_limit': limit,
      },
    );
    return MessagePage.fromMap(Map<String, dynamic>.from(value as Map));
  }

  Future<MortMessage> sendSafeMessage(
    String threadId,
    String body, {
    String? clientRequestId,
  }) async {
    try {
      final row = await client.rpc(
        'send_safe_message_v2',
        params: {
          'p_thread_id': threadId,
          'p_body': body.trim(),
          'p_client_request_id': clientRequestId ?? const Uuid().v4(),
        },
      );
      return MortMessage.fromMap(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      await recordOperationalFailure(
        eventType: 'message_delivery_failure',
        safeCode: 'message.send_failed',
      );
      rethrow;
    }
  }

  RealtimeChannel subscribeToMessages(
    String threadId,
    void Function(MortMessage message) onInsert,
  ) {
    requireUserId();
    final channel = client.channel(
      'job-thread:$threadId:${DateTime.now().microsecondsSinceEpoch}',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: threadId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onInsert(MortMessage.fromMap(payload.newRecord));
            }
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
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
