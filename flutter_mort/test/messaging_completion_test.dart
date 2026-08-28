import 'dart:async';
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
  void Function(MortMessage message)? _onInsert;

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
  ) {
    _onInsert = onInsert;
    return subscription;
  }

  void emit(MortMessage message) => _onInsert?.call(message);

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

class _OutOfOrderThreadRepository extends MessagingRepository {
  final loadMore = Completer<MessageThreadPage>();
  final search = Completer<MessageThreadPage>();

  final initialThread = MessageThread(
    id: 'initial-thread',
    lifecycleStatus: 'active',
    updatedAt: DateTime.utc(2026, 8, 8, 14),
    counterpartyDisplayName: 'Initial Person',
  );

  @override
  Future<MessageThreadPage> listThreadsPage({
    String query = '',
    MessageThreadPageCursor? cursor,
    int limit = 20,
  }) {
    if (query == 'new search') return search.future;
    if (cursor != null) return loadMore.future;
    return Future.value(
      MessageThreadPage(
        items: [initialThread],
        hasMore: true,
        nextCursor: MessageThreadPageCursor(
          updatedAt: initialThread.updatedAt!,
          id: initialThread.id,
        ),
      ),
    );
  }
}

class _DeferredMessageSendRepository extends _FakeMessagingRepository {
  final sendCompleter = Completer<MortMessage>();

  @override
  Future<MortMessage> sendSafeMessage(
    String threadId,
    String body, {
    String? clientRequestId,
  }) {
    return sendCompleter.future;
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

  testWidgets('new search ignores an older pagination response', (
    tester,
  ) async {
    final repository = _OutOfOrderThreadRepository();
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

    await tester.ensureVisible(find.text('Load more conversations'));
    await tester.tap(find.text('Load more conversations'));
    await tester.pump();

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search by participant or job',
    );
    await tester.enterText(searchField, 'new search');
    await tester.tap(find.text('Search conversations'));
    await tester.pump();

    repository.search.complete(
      MessageThreadPage(
        items: [
          MessageThread(
            id: 'new-thread',
            lifecycleStatus: 'active',
            updatedAt: DateTime.utc(2026, 8, 9),
            counterpartyDisplayName: 'New Search Match',
          ),
        ],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Search Match'), findsOneWidget);

    repository.loadMore.complete(
      MessageThreadPage(
        items: [
          MessageThread(
            id: 'stale-thread',
            lifecycleStatus: 'active',
            updatedAt: DateTime.utc(2026, 8, 7),
            counterpartyDisplayName: 'Stale Old Result',
          ),
        ],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Search Match'), findsOneWidget);
    expect(find.text('Stale Old Result'), findsNothing);
    expect(find.text('Initial Person'), findsNothing);
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

  testWidgets('leaving a thread during send does not update disposed UI', (
    tester,
  ) async {
    final repository = _DeferredMessageSendRepository();
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

    await tester.enterText(find.byType(TextFormField), 'Pending message');
    await tester.ensureVisible(find.text('Send message'));
    await tester.tap(find.text('Send message'));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    repository.sendCompleter.complete(
      MortMessage(
        id: 'late-message',
        threadId: 'thread-1',
        senderId: 'teen-1',
        body: 'Pending message',
        scannerStatus: 'clean',
        createdAt: DateTime.utc(2026, 8, 16),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('realtime message bursts coalesce read acknowledgements', (
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
    final initialMarkReadCount = repository.markReadCount;

    for (var index = 0; index < 100; index += 1) {
      repository.emit(
        MortMessage(
          id: 'burst-$index',
          threadId: 'thread-1',
          senderId: 'adult-1',
          body: 'Synthetic burst message $index',
          scannerStatus: 'clean',
          createdAt: DateTime.utc(2026, 8, 8, 15, 0, index),
        ),
      );
    }

    await tester.pump(const Duration(milliseconds: 249));
    expect(repository.markReadCount, initialMarkReadCount);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(repository.markReadCount, initialMarkReadCount + 1);
    expect(find.text('Synthetic burst message 99'), findsOneWidget);
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
