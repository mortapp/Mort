import 'package:flutter/material.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/support_repository.dart';
import 'package:flutter_mort/features/support/support_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSupportRepository extends SupportRepository {
  @override
  Future<SupportThread> getThread(String ticketId) async => SupportThread(
    ticket: SupportTicket(
      id: ticketId,
      caseNumber: 'MORT-TESTCASE123',
      subject: 'Start PIN help',
      category: 'start_finish_pin',
      priority: 'normal',
      status: 'waiting_on_staff',
      source: 'automated_support',
      waitingOnParty: 'staff',
      aiAssisted: true,
      humanReviewed: false,
      safeAttachmentCount: 0,
      createdAt: DateTime.utc(2026, 7, 22),
      updatedAt: DateTime.utc(2026, 7, 22),
    ),
    messages: [
      SupportTicketMessage(
        id: 'message-1',
        senderKind: 'user',
        source: 'automated_support',
        body: 'My start PIN expired.',
        createdAt: DateTime.utc(2026, 7, 22),
        safeAttachmentCount: 0,
      ),
      SupportTicketMessage(
        id: 'message-2',
        senderKind: 'automated_support',
        source: 'faq',
        body: 'Ask the adult to generate a new PIN in person.',
        createdAt: DateTime.utc(2026, 7, 22, 0, 1),
        safeAttachmentCount: 0,
      ),
    ],
  );
}

void main() {
  testWidgets(
    'new support conversation includes categories and quick replies',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: NewSupportConversationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('How can MORT help?'), findsOneWidget);
      expect(find.text('My picture will not update'), findsOneWidget);
      expect(find.text('A job PIN is not working'), findsOneWidget);
      expect(find.text('Report or block someone'), findsOneWidget);
      expect(find.textContaining('Do not include passwords'), findsOneWidget);
    },
  );

  testWidgets('support ticket distinguishes automated and human review state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(_FakeSupportRepository()),
        ],
        child: const MaterialApp(
          home: SupportTicketScreen(ticketId: 'ticket-widget-qa'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MORT-TESTCASE123'), findsOneWidget);
    expect(find.text('My start PIN expired.'), findsOneWidget);
    expect(
      find.text('Ask the adult to generate a new PIN in person.'),
      findsOneWidget,
    );
    expect(find.textContaining('A human has not reviewed'), findsOneWidget);
    expect(find.text('Request human review'), findsOneWidget);
    expect(find.text('Email fallback'), findsOneWidget);
  });
}
