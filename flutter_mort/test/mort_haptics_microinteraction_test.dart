import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mort/core/preferences/mort_experience_preferences.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

/// Canonical microinteraction contract: every canonical button activation
/// fires exactly one preference-gated selection haptic. Disabled controls and
/// a disabled haptics preference remain silent while actions stay usable.
void main() {
  final List<MethodCall> calls = <MethodCall>[];

  void captureHaptics(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method.startsWith('HapticFeedback')) calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    calls.clear();
  }

  void expectSingleSelectionClick() {
    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
    expect(
      calls.single.arguments,
      'HapticFeedbackType.selectionClick',
      reason: 'the haptic must be the selection tick, not an impact',
    );
  }

  Future<void> pumpButton(
    WidgetTester tester, {
    required Widget child,
    MortExperiencePreferences preferences = const MortExperiencePreferences(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MortExperiencePreferencesScope(
          preferences: preferences,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  testMortWidgets('canonical button fires one selection haptic and activates', (
    tester,
  ) async {
    captureHaptics(tester);
    var activations = 0;
    await pumpButton(
      tester,
      child: MortButton(label: 'Continue', onPressed: () => activations++),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(activations, 1);
    expectSingleSelectionClick();
  });

  testMortWidgets('disabled haptics preference suppresses the haptic only', (
    tester,
  ) async {
    captureHaptics(tester);
    var activations = 0;
    await pumpButton(
      tester,
      preferences: const MortExperiencePreferences(hapticsEnabled: false),
      child: MortButton(label: 'Continue', onPressed: () => activations++),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(activations, 1);
    expect(calls, isEmpty);
  });

  testMortWidgets('disabled canonical button neither activates nor buzzes', (
    tester,
  ) async {
    captureHaptics(tester);
    var activations = 0;
    await pumpButton(
      tester,
      child: MortButton(label: 'Continue', onPressed: null),
    );
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();

    expect(activations, 0);
    expect(calls, isEmpty);
  });

  testMortWidgets(
    'canonical icon button fires one selection haptic and activates',
    (tester) async {
      captureHaptics(tester);
      var activations = 0;
      await pumpButton(
        tester,
        child: MortIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => activations++,
        ),
      );
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();

      expect(activations, 1);
      expectSingleSelectionClick();
      expect(
        find.byTooltip('Refresh'),
        findsOneWidget,
        reason: 'icon-only controls keep their semantic tooltip',
      );
    },
  );
}
