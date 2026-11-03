import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets('unified auth switches modes without losing entered email', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: mortTestTheme(MortTheme.dark()),
          home: const UnifiedAuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WELCOME BACK'), findsOneWidget);
    var fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields, hasLength(2));
    await tester.enterText(
      find.byType(TextFormField).first,
      'teen@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'SignIn1!');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final createMode = find.text('Create account').first;
    await tester.ensureVisible(createMode);
    await tester.pumpAndSettle();
    await tester.tap(createMode);
    await tester.pumpAndSettle();

    expect(find.text('NEW ACCOUNT'), findsOneWidget);
    expect(find.textContaining('Use at least 12 characters'), findsOneWidget);
    fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, 'teen@example.com');
    expect(fields.last.controller?.text, isEmpty);

    await tester.enterText(find.byType(TextFormField).last, 'NewAccount1!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final signInMode = find.text('Sign in').first;
    await tester.ensureVisible(signInMode);
    await tester.pumpAndSettle();
    await tester.tap(signInMode);
    await tester.pumpAndSettle();

    fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, 'teen@example.com');
    expect(fields.last.controller?.text, 'SignIn1!');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unified auth is overflow-free on Samsung at 1.3 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2408);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: mortTestTheme(MortTheme.dark()),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access MORT'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign In mode shows "Continue with Google" button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleAuthEnabledProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signIn),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsNothing);
    expect(find.byIcon(Icons.login_rounded), findsWidgets);
  });

  testWidgets('Sign Up mode shows "Sign up with Google" button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleAuthEnabledProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW ACCOUNT'), findsOneWidget);
    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('Google auth button survives narrow screen with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [googleAuthEnabledProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 300),
              textScaler: TextScaler.linear(1.2),
            ),
            child: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
