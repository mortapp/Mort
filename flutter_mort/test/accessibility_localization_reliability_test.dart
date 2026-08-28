import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/core/widgets/mort_design_components.dart';
import 'package:flutter_mort/data/models/job.dart';
import 'package:flutter_mort/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN semantics report progress without exposing entered digits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          MortLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: MortPinPad(value: '42', onChanged: (_) {}),
        ),
      ),
    );

    final pin = find.bySemanticsLabel('Secure 6-digit job PIN entry');
    expect(pin, findsOneWidget);
    expect(tester.getSemantics(pin).value, '2 of 6 digits entered');
    expect(find.bySemanticsLabel('PIN digit 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete last PIN digit'), findsOneWidget);
    expect(find.bySemanticsLabel('42'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('\u2022')), findsNothing);
    semantics.dispose();
  });

  test(
    'Spanish resources generate but remain outside the enabled app locale',
    () async {
      final spanish = await MortLocalizations.delegate.load(const Locale('es'));
      expect(spanish.retryAccountCheck, 'Reintentar comprobacion de cuenta');
      expect(MortLocalizations.supportedLocales, contains(const Locale('es')));
    },
  );

  test('money formatting accepts explicit locale and currency', () {
    expect(formatCents(1234, locale: 'en_US', currency: 'USD'), r'$12.34');
  });

  test('session cache fallback is visibly marked stale by the model', () {
    const page = JobPage(items: [], hasMore: false);
    expect(page.servedFromSessionCache, isFalse);
    expect(page.asSessionCacheFallback().servedFromSessionCache, isTrue);
  });
}
