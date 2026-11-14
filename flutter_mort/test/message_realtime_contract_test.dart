import 'package:flutter_mort/data/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MortMessage production payload compatibility', () {
    test('parses conversation_id from raw Realtime row', () {
      final message = MortMessage.fromMap({
        'id': 'message-1',
        'conversation_id': 'conversation-1',
        'sender_id': 'sender-1',
        'body': 'What time should I arrive?',
        'moderation_status': 'approved',
        'moderation_reason': null,
        'created_at': '2026-11-14T12:00:00Z',
      });

      expect(message.threadId, 'conversation-1');
      expect(message.scannerStatus, 'approved');
      expect(message.body, 'What time should I arrive?');
    });

    test('continues to parse the RPC thread_id envelope', () {
      final message = MortMessage.fromMap({
        'id': 'message-2',
        'thread_id': 'conversation-2',
        'sender_id': 'sender-2',
        'body': 'See you at 4.',
        'scanner_status': 'flagged',
        'scanner_reason': 'Held for safety review.',
      });

      expect(message.threadId, 'conversation-2');
      expect(message.scannerStatus, 'flagged');
      expect(message.flagged, isTrue);
    });
  });
}
