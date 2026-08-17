import 'package:flutter/material.dart';
import 'package:flutter_mort/core/routing/mort_page_transitions.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route builders omit motion when reduced motion is active', (
    tester,
  ) async {
    late BuildContext reducedMotionContext;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reducedMotionContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final route = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    const child = Text('Destination');
    const animation = AlwaysStoppedAnimation<double>(0.5);
    for (final builder in const <PageTransitionsBuilder>[
      MortFiniteFadePageTransitionsBuilder(),
      MortCupertinoPageTransitionsBuilder(),
    ]) {
      final result = builder.buildTransitions<void>(
        route,
        reducedMotionContext,
        animation,
        animation,
        child,
      );
      expect(result, same(child));
    }
  });

  testWidgets('confirmation sheets protect the bottom safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => MortConfirmSheet.show(
              context,
              title: 'Confirm action',
              message: 'This is a synthetic confirmation.',
            ),
            child: const Text('Open confirmation'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
  });
}
