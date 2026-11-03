import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_wordmark_reveal.dart';
import 'package:flutter_mort/core/widgets/mort_motion_mark.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entry presents one concise midnight hierarchy', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );
    await tester.pump();

    expect(find.byType(MortMotionMark), findsOneWidget);
    expect(find.byType(MortWordmarkReveal), findsOneWidget);
    expect(find.text('Earn nearby. Move smart.'), findsOneWidget);
    expect(find.text('Enter MORT'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final screen = tester.widget<MortScreen>(find.byType(MortScreen));
    expect(screen.atmosphereFocalLayer, isNotNull);
  });

  testWidgets('entry remains scroll-safe at 150 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(home: SplashScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter MORT'), findsOneWidget);
  });
}
