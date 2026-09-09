import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MortLogo exposes the approved asset, semantics, and wordmark', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const MortLogo(size: 64, showWordmark: true)),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, MortLogo.assetPath);
    expect(find.text('M O R T'), findsOneWidget);
    final logoSemantics = find.bySemanticsLabel('MORT arrow logo');
    expect(logoSemantics, findsOneWidget);
    expect(
      tester.getSemantics(logoSemantics),
      matchesSemantics(label: 'MORT arrow logo', isImage: true),
    );
    semantics.dispose();
  });

  testWidgets('MortLogo clamps non-finite dimensions to a safe size', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MortLogo(size: double.infinity)));

    final logoBoxFinder = find.descendant(
      of: find.byType(MortLogo),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == widget.height &&
            widget.width == 72,
      ),
    );
    expect(logoBoxFinder, findsOneWidget);
    final logoBox = tester.widget<SizedBox>(logoBoxFinder);
    expect(logoBox.width, 72);
    expect(logoBox.height, 72);
  });

  testWidgets('animated brand starts still when reduced motion is requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MortAnimatedBrandMark(), disableAnimations: true),
    );

    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(
        of: find.byType(MortAnimatedBrandMark),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(find.text('M O R T'), findsOneWidget);
  });
}

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: MortTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
