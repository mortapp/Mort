import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/reviewer/reviewer_session.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/reviewer/reviewer_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reviewer identifier', () {
    test('accepts only the exact ASCII lowercase identifier', () {
      expect(
        isExactPlayReviewerIdentifier(
          playReviewerIdentifier,
          reviewerModeEnabled: true,
        ),
        isTrue,
      );
      expect(
        isExactPlayReviewerIdentifier(
          '  $playReviewerIdentifier\r\n',
          reviewerModeEnabled: true,
        ),
        isTrue,
      );

      for (final value in [
        'play-review+anything@mortapp.test',
        'PLAY-REVIEWER@mortapp.test',
        'play-review@otherdomain.test',
        'play-review @mortapp.test',
        'play-review@mortapp.test anything',
        'play-review@mortapp.t\u0435st',
        'play-review@mortapp.test\u00a0',
      ]) {
        expect(
          isExactPlayReviewerIdentifier(value, reviewerModeEnabled: true),
          isFalse,
          reason: value,
        );
      }
    });

    test('normal registration rejects the reserved identifier', () {
      expect(
        rejectReservedPlayReviewerIdentifier(
          playReviewerIdentifier,
          reviewerModeEnabled: true,
        ),
        contains('reserved'),
      );
      expect(
        rejectReservedPlayReviewerIdentifier(
          'person@example.com',
          reviewerModeEnabled: true,
        ),
        isNull,
      );
    });
  });

  group('isolated reviewer session', () {
    test('starts without credentials and refuses a production session', () {
      final session = ReviewerSession(reviewerModeEnabled: true);
      expect(
        session.start(
          identifier: playReviewerIdentifier,
          productionSessionPresent: true,
        ),
        isFalse,
      );
      expect(session.isActive, isFalse);

      expect(
        session.start(
          identifier: playReviewerIdentifier,
          productionSessionPresent: false,
        ),
        isTrue,
      );
      expect(session.isActive, isTrue);
    });

    test('role switching and ordinary navigation preserve local state', () {
      final session = _activeSession();
      session.selectRole(ReviewerRole.admin);
      session.toggleAction('admin-audit');
      expect(session.selectedRole, ReviewerRole.admin);
      expect(session.completedActions, contains('admin-audit'));

      session.selectRole(ReviewerRole.teen);
      expect(session.completedActions, contains('admin-audit'));
    });

    test('sign out clears state and process restart is expired', () {
      final session = _activeSession();
      session.toggleAction('teen-apply');
      session.exit();
      expect(session.isActive, isFalse);
      expect(session.completedActions, isEmpty);
      expect(ReviewerSession(reviewerModeEnabled: true).isActive, isFalse);
    });

    test('demo PINs work only in the active local session', () {
      final session = _activeSession();
      expect(session.confirmStartPin('000000'), isFalse);
      expect(session.confirmStartPin(reviewerStartPin), isTrue);
      expect(session.confirmCompletionPin('123456'), isFalse);
      expect(session.confirmCompletionPin(reviewerCompletionPin), isTrue);
      session.exit();
      expect(session.confirmStartPin(reviewerStartPin), isFalse);
    });

    test('proof, payment, and admin actions mutate only local state', () {
      final session = _activeSession();
      session.attachSyntheticProof();
      session.advanceSyntheticPayment();
      session.toggleAction('admin-shutdown');
      expect(session.syntheticProofAttached, isTrue);
      expect(session.paymentState, 'Authorization pending');
      expect(session.completedActions, contains('admin-shutdown'));
    });
  });

  group('reviewer UI', () {
    testWidgets('exact identifier hides password and normal auth actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewerModeEnabledProvider.overrideWithValue(true)],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        playReviewerIdentifier,
      );
      await tester.pump();

      expect(find.text('Continue as Play Reviewer'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Forgot password'), findsNothing);
      expect(find.text('Create account'), findsNothing);
    });

    testWidgets('ordinary email keeps password authentication', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewerModeEnabledProvider.overrideWithValue(true)],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'person@example.com',
      );
      await tester.pump();

      expect(find.text('Continue as Play Reviewer'), findsNothing);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Forgot password'), findsOneWidget);
    });

    for (final role in ReviewerRole.values) {
      testWidgets('${role.name} demo role renders', (tester) async {
        final session = _activeSession()..selectRole(role);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [reviewerSessionProvider.overrideWith((ref) => session)],
            child: MaterialApp(home: ReviewerRoleExperience(role: role)),
          ),
        );
        await tester.pump();
        expect(find.text('${role.label} review experience'), findsOneWidget);
        expect(find.text('Google Play Review Mode'), findsOneWidget);
        expect(find.text('Synthetic demonstration data'), findsOneWidget);
      });
    }
  });

  group('source boundaries', () {
    final reviewerSource = File(
      'lib/features/reviewer/reviewer_screens.dart',
    ).readAsStringSync();
    final sessionSource = File(
      'lib/core/reviewer/reviewer_session.dart',
    ).readAsStringSync();
    final routerSource = File(
      'lib/core/routing/app_router.dart',
    ).readAsStringSync();
    final migrationSource = File(
      '../supabase/migrations/20260726024327_reserve_play_reviewer_identifier.sql',
    ).readAsStringSync();

    test('reviewer code has no production repository or SDK path', () {
      final combined = '$reviewerSource\n$sessionSource';
      for (final forbidden in [
        'package:supabase',
        'SupabaseService',
        'RepositoryProvider',
        '.functions.invoke',
        '.rpc(',
        'package:flutter_stripe',
        "import '../../data/",
        'service_role',
        'access_token',
        'shared_preferences',
        'secure_storage',
      ]) {
        expect(
          combined.toLowerCase(),
          isNot(contains(forbidden.toLowerCase())),
        );
      }
    });

    test('all reviewer routes use the dedicated local guard', () {
      for (final path in [
        '/review',
        '/review/teen',
        '/review/adult',
        '/review/guardian',
        '/review/support',
        '/review/admin',
      ]) {
        expect(routerSource, contains("_reviewer('$path'"));
      }
      expect(routerSource, contains('productionSessionPresent'));
      expect(routerSource, contains('ReviewerSessionRequiredScreen'));
    });

    test('server reserves the identifier before auth user creation', () {
      expect(
        migrationSource,
        contains('before insert or update of email on auth.users'),
      );
      expect(migrationSource, contains(playReviewerIdentifier));
      expect(migrationSource, contains('security invoker'));
      expect(
        migrationSource,
        contains('revoke all on function public.reject_reserved'),
      );
      expect(migrationSource, isNot(contains('security definer')));
    });
  });
}

ReviewerSession _activeSession() {
  final session = ReviewerSession(reviewerModeEnabled: true);
  final started = session.start(
    identifier: playReviewerIdentifier,
    productionSessionPresent: false,
  );
  if (!started) throw StateError('Reviewer test session did not start.');
  return session;
}
