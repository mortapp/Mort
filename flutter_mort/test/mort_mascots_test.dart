import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/guide/mascot_picker_screen.dart';
import 'package:flutter_mort/features/guide/mascot_preference.dart';
import 'package:flutter_mort/features/guide/mort_guide_intro.dart';
import 'package:flutter_mort/features/guide/mort_mascots.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('mascot inventory', () {
    testWidgets('Pip exists as a real vector mascot', (tester) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MortMascotView(mascot: MortMascotId.pip)),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Pip the penguin, MORT Guide mascot')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is MortMascotPainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Mochi exists as a real vector mascot', (tester) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MortMascotView(mascot: MortMascotId.mochi)),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Mochi the kitten, MORT Guide mascot')),
        findsOneWidget,
      );
    });

    testWidgets('Scout exists as a real vector mascot', (tester) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MortMascotView(mascot: MortMascotId.scout)),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Scout the dog, MORT Guide mascot')),
        findsOneWidget,
      );
    });

    testWidgets('every mascot renders every state without exceptions', (
      tester,
    ) async {
      addTearDown(tester.ensureSemantics);
      for (final mascot in MortMascotId.values) {
        for (final state in MortMascotState.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MortMascotView(mascot: mascot, state: state),
              ),
            ),
          );
          await tester.pump();
          expect(
            find.byType(MortMascotView),
            findsOneWidget,
            reason: '$mascot/$state should render',
          );
        }
      }
    });

    testWidgets('no mascot state is a placeholder circle or emoji', (
      tester,
    ) async {
      final source = File(
        'lib/features/guide/mort_mascots.dart',
      ).readAsStringSync();
      expect(source, contains('class MortMascotPainter'));
      expect(source, contains('CustomPainter'));
      // Every state is drawn by the painter, not substituted.
      for (final state in MortMascotState.values) {
        expect(source, contains(state.name));
      }
      expect(source, isNot(contains('Placeholder')));
    });
  });

  group('reduced motion', () {
    testWidgets('system reduced motion freezes the animation loop', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: MortMascotView(mascot: MortMascotId.pip)),
          ),
        ),
      );
      await tester.pump();
      final state = tester.state<MortMascotViewState>(
        find.byType(MortMascotView),
      );
      expect(state.isAnimating, isFalse);
    });

    testWidgets('explicit reducedMotion freezes the animation loop', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MortMascotView(
              mascot: MortMascotId.mochi,
              reducedMotion: true,
            ),
          ),
        ),
      );
      await tester.pump();
      final state = tester.state<MortMascotViewState>(
        find.byType(MortMascotView),
      );
      expect(state.isAnimating, isFalse);
    });

    testWidgets('safety-serious pose is always static', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MortMascotView(
              mascot: MortMascotId.scout,
              state: MortMascotState.safetySerious,
            ),
          ),
        ),
      );
      await tester.pump();
      final state = tester.state<MortMascotViewState>(
        find.byType(MortMascotView),
      );
      expect(state.isAnimating, isFalse);
    });

    testWidgets('idle animates when motion is allowed and disposes cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MortMascotView(mascot: MortMascotId.pip)),
        ),
      );
      await tester.pump();
      expect(
        tester
            .state<MortMascotViewState>(find.byType(MortMascotView))
            .isAnimating,
        isTrue,
      );
      // Lifecycle-safe: removing the widget disposes the controller.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      expect(tester.takeException(), isNull);
    });
  });

  group('guide state mapping', () {
    test('safety escalation always wins', () {
      expect(
        guideMascotStateFor(
          safetyEscalation: true,
          sending: true,
          justAnswered: true,
          composing: true,
        ),
        MortMascotState.safetySerious,
      );
    });

    test('sending maps to thinking', () {
      expect(
        guideMascotStateFor(
          safetyEscalation: false,
          sending: true,
          justAnswered: true,
          composing: true,
        ),
        MortMascotState.thinking,
      );
    });

    test('fresh answer maps to success', () {
      expect(
        guideMascotStateFor(
          safetyEscalation: false,
          sending: false,
          justAnswered: true,
          composing: true,
        ),
        MortMascotState.success,
      );
    });

    test('composing maps to listening, otherwise idle', () {
      expect(
        guideMascotStateFor(
          safetyEscalation: false,
          sending: false,
          justAnswered: false,
          composing: true,
        ),
        MortMascotState.listening,
      );
      expect(
        guideMascotStateFor(
          safetyEscalation: false,
          sending: false,
          justAnswered: false,
          composing: false,
        ),
        MortMascotState.idle,
      );
    });
  });

  group('mascot preference persistence', () {
    test('starts closed (null) and survives provider rebuild', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(mascotPreferenceProvider.future), isNull);

      await container
          .read(mascotPreferenceProvider.notifier)
          .choose(MortMascotId.mochi);
      expect(
        await container.read(mascotPreferenceProvider.future),
        MortMascotId.mochi,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(MortMascotPreferenceController.storageKey),
        'mochi',
      );

      container.invalidate(mascotPreferenceProvider);
      expect(
        await container.read(mascotPreferenceProvider.future),
        MortMascotId.mochi,
      );
    });

    test('unknown stored values fail closed to the introduction', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        MortMascotPreferenceController.storageKey: 'sparkles-the-unicorn',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(mascotPreferenceProvider.future), isNull);
    });

    test(
      'changing mascot only writes its own key and never touches auth/session',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(mascotPreferenceProvider.notifier)
            .choose(MortMascotId.scout);

        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getKeys(),
          equals(<String>{MortMascotPreferenceController.storageKey}),
        );

        // Source guarantee: the mascot preference layer has no auth or
        // session surface at all.
        final source = File(
          'lib/features/guide/mascot_preference.dart',
        ).readAsStringSync();
        expect(source, isNot(contains('Supabase')));
        expect(source, isNot(matches(RegExp('auth', caseSensitive: false))));
        expect(source, isNot(contains('session')));
      },
    );
  });

  group('picker screen', () {
    Widget harness() => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MortMascotPickerScreen(),
                  ),
                ),
                child: const Text('open picker'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('shows Pip, Mochi, and Scout previews', (tester) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(harness());
      await tester.tap(find.text('open picker'));
      // Mascots animate on an infinite loop, so settle with timed pumps.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Pip the penguin'), findsOneWidget);
      expect(find.text('Mochi the kitten'), findsOneWidget);
      expect(find.text('Scout the dog'), findsOneWidget);
      expect(find.text('Choose your Guide UI'), findsOneWidget);
      for (final mascot in MortMascotId.values) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is MortMascotView && widget.mascot == mascot,
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('choosing Mochi persists and pops back', (tester) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(harness());
      await tester.tap(find.text('open picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Mochi the kitten'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 5));

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(MortMascotPreferenceController.storageKey),
        'mochi',
      );
      // Popped back to the harness home.
      expect(find.text('open picker'), findsOneWidget);
      expect(find.text('Choose your Guide UI'), findsNothing);
    });

    testWidgets('renders at 200% text scale without exceptions', (
      tester,
    ) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(body: MortMascotPickerScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is MortMascotPainter,
        ),
        findsNWidgets(3),
      );
    });
  });

  group('first-open introduction', () {
    testWidgets('shows all three companions and unlocks once picked', (
      tester,
    ) async {
      addTearDown(tester.ensureSemantics);
      var started = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MortGuideWelcomeView(onStart: () => started = true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Meet your MORT Guide companion'), findsOneWidget);
      expect(find.text('Pip the penguin'), findsOneWidget);
      expect(find.text('Mochi the kitten'), findsOneWidget);
      expect(find.text('Scout the dog'), findsOneWidget);
      expect(find.textContaining('AI may make mistakes'), findsOneWidget);

      // Continue is locked until a companion is picked.
      final startButton = tester.widget<MortButton>(
        find.widgetWithText(MortButton, 'Pick a companion to continue'),
      );
      expect(startButton.onPressed, isNull);
      expect(started, isFalse);

      await tester.tap(find.text('Mochi the kitten'));
      await tester.pump();
      final startFinder = find.widgetWithText(MortButton, 'Start with Mochi');
      await tester.ensureVisible(startFinder);
      await tester.pump();
      await tester.tap(startFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(started, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(MortMascotPreferenceController.storageKey),
        'mochi',
      );
    });

    testWidgets('welcome keeps the approved safety banner copy', (
      tester,
    ) async {
      addTearDown(tester.ensureSemantics);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: MortGuideWelcomeView(onStart: () {})),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MortSafetyBanner), findsOneWidget);
      expect(find.text('Meet your MORT Guide companion'), findsOneWidget);
      expect(
        tester.widget<MortSafetyBanner>(find.byType(MortSafetyBanner)).message,
        contains('MORT Guide is not emergency, legal, or medical assistance'),
      );
    });
  });

  group('contract', () {
    test('guide screen and router are wired to the mascot system', () {
      final screen = File(
        'lib/features/guide/mort_guide_screens.dart',
      ).readAsStringSync();
      final router = File(
        'lib/core/routing/app_router.dart',
      ).readAsStringSync();

      expect(screen, contains('MortGuideWelcomeView'));
      expect(screen, contains('guideMascotStateFor'));
      expect(
        screen,
        contains(
          'safetyEscalation: _safetyEscalation,\n'
          '      sending: _sending,',
        ),
      );
      expect(screen, contains("context.go('/guide/mascot')"));
      expect(router, contains("'/guide/mascot'"));
      expect(router, contains('MortMascotPickerScreen'));
    });

    test('mascots use the approved MORT palette only', () {
      final source = File(
        'lib/features/guide/mort_mascots.dart',
      ).readAsStringSync();
      for (final token in [
        'MortColors.void_',
        'MortColors.graphite',
        'MortColors.silver',
        'MortColors.softWhite',
        'MortColors.night3',
        'MortColors.night4',
      ]) {
        expect(source, contains(token));
      }
      // Restrained deep-steel atmosphere; no saturated novelty colors.
      expect(source, isNot(matches(RegExp(r'0xFF[0-9A-F]{2}(FF00|00FF)'))));
    });
  });
}
