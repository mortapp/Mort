import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auth uses open hierarchy and keeps fields ahead of atmosphere', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: UnifiedAuthScreen())),
    );
    await tester.pump();

    expect(find.byType(MortHeader), findsOneWidget);
    expect(find.byType(MortGlassHeader), findsNothing);
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('Access MORT'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.textContaining('mort-closed-pilot'), findsNothing);
  });

  testWidgets('create-account auth remains overflow-free at 150 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(
            home: UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Create account'), findsWidgets);
  });
}
