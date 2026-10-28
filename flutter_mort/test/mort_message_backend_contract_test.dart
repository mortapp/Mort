import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/message.dart';

void main() {
  group('MortMessage backend field compatibility', () {
    test('maps the production conversation and moderation columns', () {
      final message = MortMessage.fromMap({
        'id': 'message-1',
        'conversation_id': 'conversation-1',
        'sender_id': 'sender-1',
        'body': 'Hi there',
        'moderation_status': 'approved',
        'created_at': '2026-10-28T12:00:00Z',
      });

      expect(message.threadId, 'conversation-1');
      expect(message.scannerStatus, 'clean');
      expect(message.body, 'Hi there');
    });

    test('fails closed for held and unknown moderation states', () {
      final held = MortMessage.fromMap({
        'id': 'message-2',
        'conversation_id': 'conversation-1',
        'sender_id': 'sender-1',
        'body': 'Pending message',
        'moderation_status': 'held_for_safety',
      });
      final unknown = MortMessage.fromMap({
        'id': 'message-4',
        'conversation_id': 'conversation-1',
        'sender_id': 'sender-1',
        'body': 'Unrecognized moderation state',
        'moderation_status': 'new_backend_state',
      });
      final removed = MortMessage.fromMap({
        'id': 'message-3',
        'thread_id': 'conversation-1',
        'sender_id': 'sender-1',
        'body': 'Removed message',
        'scanner_status': 'removed',
      });

      expect(held.flagged, isTrue);
      expect(unknown.flagged, isTrue);
      expect(removed.blocked, isTrue);
    });
  });
}
