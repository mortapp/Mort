import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entry presents the classic white hierarchy', (tester) async {
    await _pumpEntry(tester);

    expect(find.text('MORT'), findsOneWidget);
    expect(find.text('Earn nearby. Move smart.'), findsOneWidget);
    expect(find.widgetWithText(MortButton, 'Enter MORT'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sign in'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('entry keeps actions visible on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpEntry(tester);

    final wordmark = tester.getRect(find.text('MORT'));
    final cta = tester.getRect(find.widgetWithText(MortButton, 'Enter MORT'));
    final signIn = tester.getRect(find.widgetWithText(TextButton, 'Sign in'));
    expect(wordmark.center.dx, closeTo(180, 2));
    expect(cta.top, greaterThan(wordmark.bottom));
    expect(signIn.top, greaterThan(cta.bottom));
    expect(signIn.bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry remains scroll-safe at 150 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpEntry(tester, scale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.text('Enter MORT'), findsOneWidget);
  });
}

Future<void> _pumpEntry(WidgetTester tester, {double scale = 1}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backendConnectionStatusProvider.overrideWith((ref) async => true),
      ],
      child: MaterialApp(
        theme: MortTheme.classic(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const SplashScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}
