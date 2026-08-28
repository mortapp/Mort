import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/core/routing/mort_page_transitions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'brand animation keeps transform matrix finite on SM-A146U size',
    (tester) async {
      await _pumpAtPhysicalProfile(
        tester,
        const Center(
          child: MortAnimatedBrandMark(size: 176, showWordmark: true),
        ),
      );

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('brand animation clamps non-finite dimensions before transform', (
    tester,
  ) async {
    await _pumpAtPhysicalProfile(
      tester,
      const Column(
        children: [
          MortAnimatedBrandMark(size: double.infinity),
          MortAnimatedBrandMark(size: double.nan),
          MortAnimatedBrandMark(size: -1),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Transform), findsWidgets);
  });

  testWidgets('Android route transitions avoid non-finite transform matrices', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2408)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: MortTheme.dark(),
        home: const _RouteProbe(label: 'OAuth callback'),
        routes: {
          '/account-status': (_) => const _RouteProbe(label: 'Account status'),
        },
      ),
    );

    final transitionTheme = MortTheme.dark().pageTransitionsTheme;
    expect(
      transitionTheme.builders[TargetPlatform.android],
      isA<MortFiniteFadePageTransitionsBuilder>(),
    );
    expect(mortFiniteTransitionUnit(double.nan), 1);
    expect(mortFiniteTransitionUnit(double.infinity), 1);
    expect(mortFiniteTransitionUnit(double.negativeInfinity), 1);
    expect(mortFiniteTransitionUnit(-0.5), 0);
    expect(mortFiniteTransitionUnit(1.5), 1);

    for (var i = 0; i < 12; i++) {
      key.currentState!.pushNamed('/account-status');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      _expectFiniteTransforms(tester);
      await tester.pumpAndSettle();
      _expectFiniteTransforms(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      _expectFiniteTransforms(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpAtPhysicalProfile(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1080, 2408)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 802.6666666667),
            devicePixelRatio: 3,
          ),
          child: child,
        ),
      ),
    ),
  );
}

void _expectFiniteTransforms(WidgetTester tester) {
  for (final transform in tester.widgetList<Transform>(
    find.byType(Transform),
  )) {
    expect(
      transform.transform.storage.every((value) => value.isFinite),
      isTrue,
    );
  }
  expect(tester.takeException(), isNull);
}

class _RouteProbe extends StatelessWidget {
  const _RouteProbe({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 802.6666666667),
          devicePixelRatio: 3,
        ),
        child: Center(child: Text(label)),
      ),
    );
  }
}
