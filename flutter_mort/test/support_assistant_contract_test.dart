import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'mobile support assistant keeps privileged AI credentials server-side',
    () {
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(source, isNot(contains('ANTHROPIC_API_KEY')));
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(source, isNot(contains('service_role')));
      expect(source, isNot(contains('sk-ant-')));
    },
  );

  test(
    'assistant uses authenticated MORT endpoints and private attachment flow',
    () {
      final repository = _read(
        'lib/data/repositories/support_assistant_repository.dart',
      );

      expect(repository, contains("'support-chat'"));
      expect(repository, contains("'support-upload-authorize'"));
      expect(repository, contains("attachmentBucket = 'support-attachments'"));
      expect(repository, contains('SafeImageProcessor.proof'));
      expect(repository, contains('requestFullMetadata: false'));
      expect(repository, contains('.uploadBinary('));
      expect(repository, contains('client.functions.invoke'));
    },
  );

  test('support routes and human safety exits remain reachable', () {
    final router = _read('lib/core/routing/app_router.dart');
    final screen = _read('lib/features/support/support_assistant_screen.dart');

    expect(router, contains("'/support/chat'"));
    expect(router, contains("'/support/chat/history'"));
    expect(router, contains("'/support/chat/:conversationId'"));
    expect(screen, contains("label: 'Safety Center'"));
    expect(screen, contains("label: 'Talk to a person'"));
    expect(screen, contains('MORT - automated support'));
    expect(screen, contains('Source:'));
  });
}
