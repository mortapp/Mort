import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mort/features/guide/mascot_picker_screen.dart';
import 'package:flutter_mort/features/guide/mort_guide_intro.dart';
import 'package:flutter_mort/features/guide/mort_mascots.dart';

/// Stage 7 visual-QA pressure test (master directive): the approved small
/// reference device is 570x1230. Key Guide surfaces must stay renderable and
/// overflow-free there, on the extreme narrow 320x686 floor, and at 200% text
/// scale — without being hardcoded for one screen.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size logicalSize,
    Widget child,
  ) async {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  const pressures = <String, Size>{
    'small 570x1230 reference device': Size(570, 1230),
    'extreme narrow 320x686 floor': Size(320, 686),
    'tall representative 412x915 phone': Size(412, 915),
  };

  for (final entry in pressures.entries) {
    group('mascot picker at ${entry.key}', () {
      testWidgets('renders all three companions without exceptions', (
        tester,
      ) async {
        addTearDown(tester.ensureSemantics);
        await pumpAt(tester, entry.value, const MortMascotPickerScreen());
        expect(tester.takeException(), isNull);
        expect(find.text('Choose your Guide UI'), findsOneWidget);
        expect(find.text('Pip the penguin'), findsOneWidget);
        expect(find.text('Mochi the kitten'), findsOneWidget);
        expect(find.text('Scout the dog'), findsOneWidget);
      });
    });

    group('guide welcome at ${entry.key}', () {
      testWidgets('renders all three companions without exceptions', (
        tester,
      ) async {
        addTearDown(tester.ensureSemantics);
        await pumpAt(
          tester,
          entry.value,
          const MortGuideWelcomeView(onStart: _noop),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Meet your MORT Guide companion'), findsOneWidget);
        expect(find.text('Pip the penguin'), findsOneWidget);
        expect(find.text('Mochi the kitten'), findsOneWidget);
        expect(find.text('Scout the dog'), findsOneWidget);
      });
    });
  }

  testWidgets('picker survives 200% text scale on the small reference', (
    tester,
  ) async {
    addTearDown(tester.ensureSemantics);
    tester.view.physicalSize = const Size(570, 1230);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(body: const MortMascotPickerScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Choose your Guide UI'), findsOneWidget);
  });

  testWidgets('every mascot state paints on the 570x1230 reference', (
    tester,
  ) async {
    for (final mascot in MortMascotId.values) {
      for (final state in MortMascotState.values) {
        await pumpAt(
          tester,
          const Size(570, 1230),
          MortMascotView(mascot: mascot, state: state),
        );
        expect(tester.takeException(), isNull, reason: '$mascot/$state');
      }
    }
  });
}

void _noop() {}
