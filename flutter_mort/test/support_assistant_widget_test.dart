import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/support_assistant_repository.dart';
import 'package:flutter_mort/features/support/support_assistant_screen.dart';

class _FakeSupportAssistantRepository extends SupportAssistantRepository {
  _FakeSupportAssistantRepository({
    this.configError,
    this.configCompleter,
    this.sendCompleter,
  });

  final Object? configError;
  final Completer<Map<String, dynamic>>? configCompleter;
  final Completer<SupportAssistantReply>? sendCompleter;

  @override
  Future<Map<String, dynamic>> getConfig() async {
    if (configError != null) throw configError!;
    if (configCompleter != null) return configCompleter!.future;
    return {'ok': true, 'assistant_enabled': true};
  }

  @override
  Future<SupportAssistantReply> send({
    required String message,
    String? conversationId,
  }) async {
    if (sendCompleter != null) return sendCompleter!.future;
    return _reply(message);
  }

  SupportAssistantReply _reply(String question) => SupportAssistantReply(
    conversationId: 'conversation-qa',
    message: SupportAssistantMessage(
      id: 'assistant-message-qa',
      role: 'assistant',
      content: 'Open the jobs feed and choose Apply on an eligible job.',
      createdAt: DateTime(2026, 7, 29),
      responseMode: 'deterministic',
      safetyLevel: 0,
      citations: const [
        SupportAssistantCitation(
          id: 'citation-qa',
          title: 'Jobs and applications',
          navigationRoute: '/jobs',
        ),
      ],
    ),
    citations: const [
      SupportAssistantCitation(
        id: 'citation-qa',
        title: 'Jobs and applications',
        navigationRoute: '/jobs',
      ),
    ],
    classification: const {'level': 0, 'intent': 'jobs_or_applications'},
  );
}

Widget _app(SupportAssistantRepository repository) => ProviderScope(
  overrides: [supportAssistantRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: SupportAssistantScreen()),
);

void main() {
  testWidgets('shows a deterministic loading state', (tester) async {
    final config = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      _app(_FakeSupportAssistantRepository(configCompleter: config)),
    );

    expect(find.text('Opening private MORT Support...'), findsOneWidget);
    config.complete({'ok': true, 'assistant_enabled': true});
    await tester.pumpAndSettle();
  });

  testWidgets('shows empty quick replies and private composer', (tester) async {
    await tester.pumpWidget(_app(_FakeSupportAssistantRepository()));
    await tester.pumpAndSettle();

    expect(find.text('What do you need help with?'), findsOneWidget);
    expect(find.text('How do I apply for a job?'), findsOneWidget);
    expect(find.byType(SupportAssistantComposer), findsOneWidget);
    expect(find.textContaining('Do not share passwords'), findsOneWidget);
  });

  testWidgets('shows a retryable error state', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeSupportAssistantRepository(
          configError: StateError('network connection unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support connection interrupted'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Reload'), findsOneWidget);
  });

  testWidgets('shows typing then renders answer and citation', (tester) async {
    final pending = Completer<SupportAssistantReply>();
    final repository = _FakeSupportAssistantRepository(sendCompleter: pending);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'How do I apply for a job?');
    final send = find.byTooltip('Send message');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pump();

    expect(find.byType(SupportAssistantTypingIndicator), findsOneWidget);
    pending.complete(repository._reply('How do I apply for a job?'));
    await tester.pumpAndSettle();

    expect(
      find.text('Open the jobs feed and choose Apply on an eligible job.'),
      findsOneWidget,
    );
    expect(find.text('Source: Jobs and applications'), findsOneWidget);
    expect(find.text('MORT - automated support'), findsOneWidget);
  });
}
