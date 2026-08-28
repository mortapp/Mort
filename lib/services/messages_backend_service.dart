import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesBackendService {
  MessagesBackendService._();
  static final MessagesBackendService instance = MessagesBackendService._();
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> loadConversations() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('conversations')
          .select('id, participant_one, participant_two, created_at')
          .or('participant_one.eq.${user.id},participant_two.eq.${user.id}')
          .order('created_at', ascending: false);

      final conversations = <Map<String, dynamic>>[];
      for (final row in response.cast<Map<String, dynamic>>()) {
        final conversationId = row['id']?.toString();
        final participantOne = row['participant_one']?.toString();
        final participantTwo = row['participant_two']?.toString();
        if (conversationId == null) continue;

        final otherUserId = participantOne == user.id
            ? participantTwo
            : participantOne;
        if (otherUserId == null) continue;

        final latestMessages = await _client
            .from('messages')
            .select('id, sender_id, body, created_at')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1);

        final latestMessage =
            latestMessages.isNotEmpty
            ? Map<String, dynamic>.from(latestMessages.first as Map)
            : null;

        conversations.add({
          'id': conversationId,
          'conversation_id': conversationId,
          'sender_id': otherUserId,
          'recipient_id': otherUserId,
          'content': latestMessage?['body'] ?? '',
          'created_at': latestMessage?['created_at'] ?? row['created_at'],
          'other_user_id': otherUserId,
        });
      }

      return conversations;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadMessages(String otherUserId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final conversationsResponse = await _client
          .from('conversations')
          .select('id, participant_one, participant_two')
          .or('participant_one.eq.${user.id},participant_two.eq.${user.id}')
          .limit(100);

      String? conversationId;
      for (final row in conversationsResponse.cast<Map<String, dynamic>>()) {
        final participantOne = row['participant_one']?.toString();
        final participantTwo = row['participant_two']?.toString();
        if ((participantOne == user.id && participantTwo == otherUserId) ||
            (participantOne == otherUserId && participantTwo == user.id)) {
          conversationId = row['id']?.toString();
          break;
        }
      }

      if (conversationId == null) return [];

      final response = await _client
          .from('messages')
          .select('id, sender_id, body, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return response.cast<Map<String, dynamic>>().map((message) {
        return {
          'id': message['id'],
          'conversation_id': conversationId,
          'sender_id': message['sender_id'],
          'recipient_id': otherUserId,
          'content': message['body'],
          'created_at': message['created_at'],
          'body': message['body'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  Future<bool> sendMessage(String recipientId, String content) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final conversationId = await _ensureConversation(user.id, recipientId);
      if (conversationId == null) return false;

      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'body': content,
        'moderation_status': 'approved',
      });
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  Future<String?> _ensureConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final existingResponse = await _client
          .from('conversations')
          .select('id, participant_one, participant_two')
          .or(
            'participant_one.eq.$currentUserId,participant_two.eq.$currentUserId',
          )
          .limit(100);

      for (final row in existingResponse.cast<Map<String, dynamic>>()) {
        final participantOne = row['participant_one']?.toString();
        final participantTwo = row['participant_two']?.toString();
        if ((participantOne == currentUserId &&
                participantTwo == otherUserId) ||
            (participantOne == otherUserId &&
                participantTwo == currentUserId)) {
          return row['id']?.toString();
        }
      }
    
      final createdResponse = await _client
          .from('conversations')
          .insert({
            'participant_one': currentUserId,
            'participant_two': otherUserId,
          })
          .select('id')
          .single();
      return createdResponse['id']?.toString();
    } catch (e) {
      debugPrint('Error ensuring conversation: $e');
      return null;
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('blocked_users').insert({
        'blocker_id': user.id,
        'blocked_id': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> reportMessage(String messageId, String reason) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('reports').insert({
        'reporter_id': user.id,
        'message_id': messageId,
        'reason': reason,
        'details': 'Reported from the MORT app',
        'status': 'open',
      });
      return true;
    } catch (e) {
      debugPrint('Error reporting message: $e');
      return false;
    }
  }
}

class SafeMessage {
  static bool containsUnsafeContent(String content) {
    final patterns = [
      RegExp(r'\+1?\d{9,}'),
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      RegExp(r'(?:Cash)?[Aa]pp|Venmo|Zelle|PayPal'),
      RegExp(r'@\w+'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }
    return false;
  }

  static String? getUnsafeContentError(String content) {
    if (containsUnsafeContent(content)) {
      return 'Keep contact info and payment details off MORT for safety.';
    }
    return null;
  }
}
