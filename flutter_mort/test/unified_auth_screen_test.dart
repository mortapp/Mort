import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unified auth switches modes without losing entered email', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const UnifiedAuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
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

    expect(find.text('Age-gated'), findsOneWidget);
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
          theme: MortTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access MORT'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
