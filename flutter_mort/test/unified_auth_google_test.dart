import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/auth/oauth_flow.dart';
import 'package:flutter_mort/data/repositories/auth_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthRepository extends AuthRepository {
  @override
  User? get currentUser => null;
}

Future<void> _pumpAuth(
  WidgetTester tester, {
  UnifiedAuthMode initialMode = UnifiedAuthMode.signIn,
  bool googleEnabled = true,
  bool smallScreen = false,
  bool keyboard = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  if (smallScreen) {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        googleAuthEnabledProvider.overrideWithValue(googleEnabled),
        oauthFlowStateProvider.overrideWith(
          (ref) =>
              Stream<OAuthFlowSnapshot>.value(const OAuthFlowSnapshot.idle()),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: textScaler,
          viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
        ),
        child: MaterialApp(home: UnifiedAuthScreen(initialMode: initialMode)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'public sign-in shows Continue with Google above the email form',
    (tester) async {
      await _pumpAuth(tester);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsNothing);
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Hierarchy: Google button, then "or", then the manual form.
      final googleTop = tester
          .getTopLeft(
            find.ancestor(
              of: find.text('Continue with Google'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .dy;
      final orTop = tester.getTopLeft(find.text('or')).dy;
      final emailTop = tester.getTopLeft(find.text('Email')).dy;
      expect(googleTop, lessThan(orTop));
      expect(orTop, lessThan(emailTop));
    },
  );

  testWidgets('public sign-up shows Sign up with Google', (tester) async {
    await _pumpAuth(tester, initialMode: UnifiedAuthMode.signUp);

    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets(
    'Google controls disappear when owner configuration disables them',
    (tester) async {
      await _pumpAuth(tester, googleEnabled: false);

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('or'), findsNothing);
      expect(find.text('Email'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow screen with keyboard open and large text scale does not overflow',
    (tester) async {
      await _pumpAuth(
        tester,
        smallScreen: true,
        keyboard: true,
        textScaler: const TextScaler.linear(1.5),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  test('Google controls use the real existing Supabase OAuth path', () {
    final source = File(
      'lib/features/auth/google_auth_screens.dart',
    ).readAsStringSync();

    expect(source, contains('signInWithGoogle()'));
    expect(source, contains('oauthStates'));
    expect(source, isNot(contains('signInWithIdToken')));
    expect(source, isNot(contains('providerToken')));
    expect(source, isNot(contains('providerRefreshToken')));
    // No second account system: no Firebase, no local mock success.
    expect(source, isNot(contains('FirebaseAuth')));
    expect(source, isNot(contains('MockGoogle')));
  });

  test(
    'Google section renders once, above the form, isolated from reviewer flow',
    () {
      final unified = File(
        'lib/features/auth/unified_auth_screen.dart',
      ).readAsStringSync();

      // Exactly one Google section, gated out of the reviewer identifier
      // flow, and the sign-up variant is wired to the sign-up mode.
      expect('GoogleAuthSection('.allMatches(unified).length, 1);
      expect(unified, contains('if (!_reviewerIdentifierEntered) ...['));
      expect(unified, contains('GoogleAuthSection(signUp: !_isSignIn),'));

      // Existing and new users both land on the single account-status
      // decision point, which routes into the canonical onboarding flow.
      final googleScreens = File(
        'lib/features/auth/google_auth_screens.dart',
      ).readAsStringSync();
      expect(googleScreens, contains("this.successRoute = '/account-status'"));
      expect(googleScreens, contains("context.go('/account-status')"));
    },
  );
}
