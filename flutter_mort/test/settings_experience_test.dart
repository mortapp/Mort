import 'package:flutter/material.dart';
import 'package:flutter_mort/core/preferences/mort_experience_preferences.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/settings/experience_settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('experience preferences persist every user-controlled value', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(mortExperiencePreferencesProvider.future);
    final controller = container.read(
      mortExperiencePreferencesProvider.notifier,
    );
    await controller.setReducedMotion(true);
    await controller.setReducedTransparency(true);
    await controller.setHighContrast(true);
    await controller.setHapticsEnabled(false);

    final saved = container
        .read(mortExperiencePreferencesProvider)
        .requireValue;
    expect(saved.reducedMotion, isTrue);
    expect(saved.reducedTransparency, isTrue);
    expect(saved.highContrast, isTrue);
    expect(saved.hapticsEnabled, isFalse);

    final storage = await SharedPreferences.getInstance();
    expect(storage.getBool('mort.preference.reduced_motion'), isTrue);
    expect(storage.getBool('mort.preference.reduced_transparency'), isTrue);
    expect(storage.getBool('mort.preference.high_contrast'), isTrue);
    expect(storage.getBool('mort.preference.haptics_enabled'), isFalse);
  });

  testWidgets('Settings groups controls and opens working accessibility', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2408);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/accessibility',
          builder: (_, _) => const ExperienceSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(),
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('PRIVACY AND SAFETY'), findsOneWidget);
    expect(find.text('NOTIFICATIONS AND ACCESSIBILITY'), findsOneWidget);

    final accessibility = find.text('Accessibility');
    await tester.ensureVisible(accessibility);
    await tester.tap(accessibility);
    await tester.pumpAndSettle();

    expect(find.text('How MORT feels'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);
    expect(find.text('Reduce transparency'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Reduce motion'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(mortExperiencePreferencesProvider)
          .requireValue
          .reducedMotion,
      isTrue,
    );
  });

  testWidgets('reduced transparency removes live blur', (tester) async {
    Widget app(bool reducedTransparency) => MaterialApp(
      home: Scaffold(
        body: MortExperiencePreferencesScope(
          preferences: MortExperiencePreferences(
            reducedTransparency: reducedTransparency,
          ),
          child: const LiquidGlassContainer(
            liveBlur: true,
            allowAndroidBlur: true,
            child: Text('Glass'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(app(false));
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(app(true));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
