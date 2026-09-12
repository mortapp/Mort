import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme does not synthesize off-palette container colors', () {
    final scheme = MortTheme.dark().colorScheme;

    expect(scheme.primary, MortColors.accent);
    expect(scheme.primaryContainer, MortColors.lineStrong);
    expect(scheme.onPrimaryContainer, MortColors.text);
    expect(scheme.surfaceContainer, MortColors.card);
    expect(scheme.surfaceContainerHighest, MortColors.bgElevated);
    expect(scheme.outline, MortColors.lineStrong);
  });

  test('canonical typography uses only refined light and semibold weights', () {
    final typography = MortTheme.dark().textTheme;
    final definedStyles = <TextStyle?>[
      typography.displayLarge,
      typography.displayMedium,
      typography.displaySmall,
      typography.headlineLarge,
      typography.headlineMedium,
      typography.headlineSmall,
      typography.titleLarge,
      typography.titleMedium,
      typography.titleSmall,
      typography.bodyLarge,
      typography.bodyMedium,
      typography.bodySmall,
      typography.labelLarge,
      typography.labelMedium,
      typography.labelSmall,
    ];

    expect(
      definedStyles.map((style) => style?.fontWeight).toSet(),
      equals(<FontWeight?>{FontWeight.w300, FontWeight.w600}),
    );
  });

  testWidgets(
    'canonical button variants stay legible, sized, and inert by state',
    (tester) async {
      var activations = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              MortButton(label: 'Primary', onPressed: () => activations++),
              MortButton(
                label: 'Secondary',
                style: MortButtonStyle.secondary,
                onPressed: () => activations++,
              ),
              MortButton(
                label: 'Tertiary',
                style: MortButtonStyle.tertiary,
                onPressed: () => activations++,
              ),
              const MortButton(
                label: 'Destructive',
                style: MortButtonStyle.danger,
              ),
              const MortButton(label: 'Loading', busy: true),
            ],
          ),
        ),
      );

      for (final label in ['Primary', 'Secondary', 'Tertiary']) {
        expect(
          tester.getSize(find.widgetWithText(ElevatedButton, label)).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.text(label));
      }
      await tester.tap(find.text('Destructive'));
      await tester.tap(find.text('Loading'));
      expect(activations, 3);

      final tertiary = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Tertiary'),
      );
      expect(
        tertiary.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      final destructive = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Destructive'),
      );
      final destructiveSurface = destructive.style!.backgroundColor!.resolve(
        <WidgetState>{},
      )!;
      final destructiveText = destructive.style!.foregroundColor!.resolve(
        <WidgetState>{},
      )!;
      expect(destructiveSurface, MortColors.dangerDeep);
      expect(
        _contrast(destructiveSurface, destructiveText),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets('toggle exposes state and uses a neutral active treatment', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      _host(
        MortToggle(
          label: 'Guardian visibility',
          value: true,
          onChanged: (value) => changed = value,
        ),
      ),
    );

    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
    expect(toggle.activeTrackColor, MortColors.silver);
    expect(
      tester.getSize(find.byType(SwitchListTile)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('Guardian visibility'));
    expect(changed, isFalse);
  });

  testWidgets('status and state cards remain distinct at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SingleChildScrollView(
          child: Column(
            children: [
              MortStatusCard(
                title: 'Identity and eligibility verification',
                message: 'Review is in progress.',
                statusLabel: 'Pending guardian and staff review',
              ),
              MortLoadingState(label: 'Loading jobs', fullScreen: false),
              MortEmptyState(title: 'No jobs', message: 'Try again later.'),
              MortErrorState(title: 'Could not load', message: 'Retry safely.'),
            ],
          ),
        ),
        size: const Size(320, 1200),
        textScaler: const TextScaler.linear(2),
      ),
    );

    final title = find.text('Identity and eligibility verification');
    final status = find.text('Pending guardian and staff review');
    expect(status, findsOneWidget);
    expect(
      tester.getTopLeft(status).dy,
      greaterThan(tester.getTopLeft(title).dy),
    );
    expect(find.text('Loading jobs'), findsOneWidget);
    expect(find.text('No jobs'), findsOneWidget);
    expect(find.text('Could not load'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive card preserves its label and tap behavior', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      _host(
        MortGlassCard(
          padding: EdgeInsets.zero,
          semanticLabel: 'Open job summary',
          onTap: () => tapped = true,
          child: const Text('Job summary'),
        ),
      ),
    );

    final cardSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Open job summary' &&
          widget.properties.button == true,
    );
    expect(cardSemantics, findsOneWidget);
    final semantics = tester.getSemantics(cardSemantics);
    expect(semantics.flagsCollection.isButton, isTrue);
    final cardSize = tester.getSize(cardSemantics);
    expect(cardSize.width, greaterThanOrEqualTo(44));
    expect(cardSize.height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('Job summary'));
    expect(tapped, isTrue);
    semanticsHandle.dispose();
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Widget _host(
  Widget child, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: textScaler),
    child: MaterialApp(
      theme: MortTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
