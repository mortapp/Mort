import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('legal document action returns to its invoking route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/onboarding/safety',
      routes: [
        GoRoute(
          path: '/onboarding/safety',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/legal/terms'),
              child: const Text('Open terms'),
            ),
          ),
        ),
        GoRoute(
          path: '/legal/terms',
          builder: (_, _) => const LegalDocScreen(title: 'Terms'),
        ),
        GoRoute(
          path: '/legal-center',
          builder: (_, _) => const Scaffold(body: Text('Legal center')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open terms'));
    await tester.pumpAndSettle();

    final action = find.byWidgetPredicate(
      (widget) => widget is MortButton && widget.label == 'Back',
    );
    expect(action, findsOneWidget);
    expect(find.text('Back to settings'), findsNothing);

    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/onboarding/safety');
    expect(find.text('Open terms'), findsOneWidget);
  });

  testWidgets('direct legal document action falls back to legal center', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/legal/terms',
      routes: [
        GoRoute(
          path: '/legal/terms',
          builder: (_, _) => const LegalDocScreen(title: 'Terms'),
        ),
        GoRoute(
          path: '/legal-center',
          builder: (_, _) => const Scaffold(body: Text('Legal center')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    final action = find.byWidgetPredicate(
      (widget) => widget is MortButton && widget.label == 'Back',
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/legal-center');
    expect(find.text('Legal center'), findsOneWidget);
  });
}
