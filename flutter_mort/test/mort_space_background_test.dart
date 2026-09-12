import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('space background paints a deterministic seeded atmosphere', (
    tester,
  ) async {
    Future<Uint8List> pixelsFor(int seed) async {
      await tester.pumpWidget(_host(seed: seed));
      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is MortSpacePainter,
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(160, 240);
      customPaint.painter!.paint(canvas, size);
      final picture = recorder.endRecording();
      return (await tester.runAsync(() async {
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        picture.dispose();
        return data!.buffer.asUint8List();
      }))!;
    }

    final first = await pixelsFor(41);
    final repeated = await pixelsFor(41);
    final different = await pixelsFor(42);

    expect(repeated, orderedEquals(first));
    expect(different, isNot(orderedEquals(first)));
  });

  testWidgets('space background isolates paint and preserves its child', (
    tester,
  ) async {
    await tester.pumpWidget(_host(seed: 7));

    final background = find.byType(MortSpaceBackground);
    expect(background, findsOneWidget);
    expect(
      find.descendant(of: background, matching: find.byType(RepaintBoundary)),
      findsOneWidget,
    );
    expect(find.text('Production screen'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the atmosphere static', (tester) async {
    await tester.pumpWidget(_host(seed: 7, disableAnimations: true));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('unchanged seeds reuse the precomputed painter across rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(_host(seed: 7));
    final first = _spacePainter(tester);
    await tester.pumpWidget(_host(seed: 7));
    final repeated = _spacePainter(tester);
    await tester.pumpWidget(_host(seed: 8));
    final changed = _spacePainter(tester);

    expect(repeated, same(first));
    expect(changed, isNot(same(first)));
  });
}

CustomPainter _spacePainter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is MortSpacePainter,
        ),
      )
      .painter!;
}

Widget _host({required int seed, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      theme: MortTheme.dark(),
      home: MortSpaceBackground(
        seed: seed,
        child: const Center(child: Text('Production screen')),
      ),
    ),
  );
}
