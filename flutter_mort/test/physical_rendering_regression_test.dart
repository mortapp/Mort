import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
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
