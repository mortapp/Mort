import 'package:flutter/material.dart';
import 'package:flutter_mort/features/monetization/widgets/mort_pro_paywall_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plans = [
    MortProPlan(id: r'$rc_weekly', name: 'Weekly', price: '€1,09'),
    MortProPlan(id: r'$rc_monthly', name: 'Monthly', price: '€3,49'),
    MortProPlan(id: r'$rc_annual', name: 'Annual', price: '€29,99'),
    MortProPlan(id: r'$rc_lifetime', name: 'Lifetime', price: '€99,99'),
  ];

  Future<void> show(
    WidgetTester tester, {
    List<MortProPlan> available = plans,
    bool loading = false,
    bool busy = false,
    void Function(String)? purchase,
    VoidCallback? restore,
    VoidCallback? terms,
    VoidCallback? privacy,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: MortProPaywallContent(
              plans: available,
              loading: loading,
              busy: busy,
              onPurchase: purchase ?? (_) {},
              onRestore: restore ?? () {},
              onRetry: () {},
              onClose: () {},
              onTerms: terms ?? () {},
              onPrivacy: privacy ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('four real localized prices render; annual is selected', (
    tester,
  ) async {
    await show(tester);
    for (final plan in plans) {
      expect(find.text(plan.price), findsOneWidget);
    }
    expect(find.text('Best value'), findsOneWidget);
    expect(find.text('Continue with Annual'), findsOneWidget);
    expect(
      find.textContaining('Core work and safety stay free.'),
      findsOneWidget,
    );
  });

  testWidgets('selected plan drives purchase; lifetime is one time', (
    tester,
  ) async {
    String? purchased;
    await show(tester, purchase: (id) => purchased = id);
    await tester.ensureVisible(
      find.byKey(const Key('plan-${r'$rc_lifetime'}')),
    );
    await tester.tap(find.byKey(const Key('plan-${r'$rc_lifetime'}')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock Lifetime'), findsOneWidget);
    expect(find.text('One-time purchase. No renewal.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('pro-continue')));
    await tester.tap(find.byKey(const Key('pro-continue')));
    expect(purchased, r'$rc_lifetime');
  });

  testWidgets('missing annual falls back and restore remains available', (
    tester,
  ) async {
    var restored = false;
    await show(
      tester,
      available: plans.take(2).toList(),
      restore: () => restored = true,
    );
    expect(find.text('Best value'), findsNothing);
    expect(find.text('Continue with Weekly'), findsOneWidget);
    await tester.ensureVisible(find.text('Restore Purchases'));
    await tester.tap(find.text('Restore Purchases'));
    expect(restored, isTrue);
  });

  testWidgets('loading and busy states prevent duplicate purchase', (
    tester,
  ) async {
    var purchases = 0;
    await show(
      tester,
      available: const [],
      loading: true,
      purchase: (_) => purchases++,
    );
    expect(find.text('Loading plans…'), findsOneWidget);
    expect(find.text('Continue with Annual'), findsNothing);
    await show(tester, busy: true, purchase: (_) => purchases++);
    await tester.ensureVisible(find.byKey(const Key('pro-continue')));
    await tester.tap(find.byKey(const Key('pro-continue')));
    expect(purchases, 0);
  });

  testWidgets('terms and privacy actions stay linked', (tester) async {
    var termsOpened = false;
    var privacyOpened = false;
    await show(
      tester,
      terms: () => termsOpened = true,
      privacy: () => privacyOpened = true,
    );
    await tester.ensureVisible(find.text('Terms'));
    await tester.tap(find.text('Terms'));
    await tester.tap(find.text('Privacy'));
    expect(termsOpened, isTrue);
    expect(privacyOpened, isTrue);
  });

  testWidgets('small screen with large text remains scrollable', (
    tester,
  ) async {
    await show(tester, size: const Size(320, 640), textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('pro-continue')));
    expect(tester.takeException(), isNull);
    expect(find.text('Continue with Annual'), findsOneWidget);
  });
}
