import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/message.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/auth_repository.dart';
import 'package:flutter_mort/data/repositories/messaging_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeMessageSubscription implements MortMessageSubscription {
  bool canceled = false;

  @override
  Future<void> cancel() async {
    canceled = true;
  }
}

class _FakeAuthRepository extends AuthRepository {
  @override
  User? get currentUser => null;
}

class _FakeMessagingRepository extends MessagingRepository {
  final subscription = _FakeMessageSubscription();
  final requestedQueries = <String>[];
  final sendRequestIds = <String?>[];
  var markReadCount = 0;
  var sendAttempts = 0;

  final firstThread = MessageThread(
    id: 'thread-1',
    jobId: 'job-1',
    applicationId: 'application-1',
    teenId: 'teen-1',
    adultId: 'adult-1',
    lifecycleStatus: 'active',
    updatedAt: DateTime.utc(2026, 8, 8, 14),
    unreadCount: 3,
    jobTitle: 'Lawn mowing',
    counterpartyId: 'adult-1',
    counterpartyDisplayName: 'Jamie S.',
    counterpartyRole: 'adult',
    counterpartyVerificationStatus: 'approved',
    lastMessagePreview: 'Can we confirm the schedule?',
    lastMessageAt: DateTime.utc(2026, 8, 8, 14),
  );

  @override
  Future<MessageThreadPage> listThreadsPage({
    String query = '',
    MessageThreadPageCursor? cursor,
    int limit = 20,
  }) async {
    requestedQueries.add(query);
    if (cursor != null) {
      return MessageThreadPage(
        items: [
          MessageThread(
            id: 'thread-2',
            jobId: 'job-2',
            lifecycleStatus: 'read_only',
            updatedAt: DateTime.utc(2026, 8, 7),
            jobTitle: 'Leaf cleanup',
            counterpartyDisplayName: 'Morgan T.',
          ),
        ],
        hasMore: false,
      );
    }
    return MessageThreadPage(
      items: [firstThread],
      hasMore: true,
      nextCursor: MessageThreadPageCursor(
        updatedAt: firstThread.updatedAt!,
        id: firstThread.id,
      ),
    );
  }

  @override
  Future<MessagePage> listMessagesPage(
    String threadId, {
    MessagePageCursor? cursor,
    int limit = 40,
  }) async => MessagePage(
    items: [
      MortMessage(
        id: 'message-1',
        threadId: threadId,
        senderId: 'adult-1',
        body: 'The public library entrance works for me.',
        scannerStatus: 'clean',
        createdAt: DateTime.utc(2026, 8, 8, 14),
      ),
    ],
    hasMore: false,
    lifecycleStatus: 'active',
    thread: firstThread,
  );

  @override
  MortMessageSubscription subscribeToMessages(
    String threadId,
    void Function(MortMessage message) onInsert,
  ) => subscription;

  @override
  Future<void> markThreadRead(String threadId) async {
    markReadCount += 1;
  }

  @override
  Future<MortMessage> sendSafeMessage(
    String threadId,
    String body, {
    String? clientRequestId,
  }) async {
    sendAttempts += 1;
    sendRequestIds.add(clientRequestId);
    if (sendAttempts == 1) throw StateError('temporary network failure');
    return MortMessage(
      id: 'message-sent',
      threadId: threadId,
      senderId: 'teen-1',
      body: body,
      scannerStatus: 'clean',
      createdAt: DateTime.utc(2026, 8, 8, 14, 5),
    );
  }
}

Profile _teenProfile() => Profile(
  id: 'teen-1',
  role: UserRole.teen,
  displayName: 'Teen Tester',
  username: 'teen_tester',
  dob: DateTime(2010, 1, 1),
  city: 'Test City',
  state: 'TS',
  onboardingCompleted: true,
  accountStatus: 'active',
  verificationStatus: 'approved',
  paymentPreference: 'none',
);

void main() {
  test('thread page parses public-safe context and keyset cursor', () {
    final page = MessageThreadPage.fromMap({
      'items': [
        {
          'id': 'thread-1',
          'job_title': 'Lawn mowing',
          'counterparty_display_name': 'Jamie S.',
          'last_message_preview': 'Schedule confirmed.',
          'unread_count': 2,
        },
      ],
      'has_more': true,
      'next_cursor': {'updated_at': '2026-08-08T14:00:00Z', 'id': 'thread-1'},
    });

    expect(page.items.single.jobTitle, 'Lawn mowing');
    expect(page.items.single.counterpartyDisplayName, 'Jamie S.');
    expect(page.items.single.unreadCount, 2);
    expect(page.nextCursor?.id, 'thread-1');
  });

  testWidgets('conversation list renders context, searches, and paginates', (
    tester,
  ) async {
    final repository = _FakeMessagingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseReadyProvider.overrideWithValue(true),
          messagingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jamie S.'), findsOneWidget);
    expect(find.text('Lawn mowing'), findsOneWidget);
    expect(find.text('Can we confirm the schedule?'), findsOneWidget);
    expect(find.text('3 unread'), findsOneWidget);

    await tester.ensureVisible(find.text('Load more conversations'));
    await tester.tap(find.text('Load more conversations'));
    await tester.pumpAndSettle();
    expect(find.text('Morgan T.'), findsOneWidget);
    expect(find.text('Leaf cleanup'), findsOneWidget);

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search by participant or job',
    );
    await tester.enterText(search, 'mowing');
    await tester.tap(find.text('Search conversations'));
    await tester.pumpAndSettle();
    expect(repository.requestedQueries.last, 'mowing');
  });

  testWidgets('thread exposes safety context and retries one failed send', (
    tester,
  ) async {
    final repository = _FakeMessagingRepository();
    final auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(auth),
          currentProfileProvider.overrideWithValue(
            AsyncValue.data(_teenProfile()),
          ),
        ],
        child: const MaterialApp(
          home: MessageThreadScreen(threadId: 'thread-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jamie S.'), findsOneWidget);
    expect(find.text('Job: Lawn mowing'), findsOneWidget);
    expect(find.text('Report participant'), findsOneWidget);
    expect(find.text('Block participant'), findsOneWidget);
    expect(find.textContaining('Job chat is text-only'), findsOneWidget);
    expect(repository.markReadCount, greaterThanOrEqualTo(1));

    final composer = find.byType(TextFormField);
    expect(composer, findsOneWidget);
    await tester.enterText(composer, 'I can meet at 3 PM.');
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Message not sent'), findsOneWidget);
    expect(find.text('Retry send'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry send'));
    await tester.tap(find.text('Retry send'));
    await tester.pumpAndSettle();

    expect(find.text('I can meet at 3 PM.'), findsOneWidget);
    expect(repository.sendAttempts, 2);
    expect(repository.sendRequestIds[0], isNotNull);
    expect(repository.sendRequestIds[1], repository.sendRequestIds[0]);
  });

  test('messaging migration keeps participant and evidence boundaries', () {
    final migration = File(
      '../supabase/migrations/20260808010000_message_thread_context_and_pagination.sql',
    ).readAsStringSync();

    expect(migration, contains('public.is_thread_participant(thread.id)'));
    expect(migration, contains('participant.user_id = v_user_id'));
    expect(migration, contains('(thread.updated_at, thread.id)'));
    expect(migration, contains('from public, anon'));
    expect(migration, isNot(contains('raw_body')));
    expect(migration, isNot(contains('exact_address')));
    expect(migration, isNot(contains('message_safety_evidence')));
  });
}
