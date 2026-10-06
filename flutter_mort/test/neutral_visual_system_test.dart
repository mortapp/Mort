import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/features/monetization/widgets/mort_pro_paywall_content.dart';
import 'package:flutter_mort/features/safety/emergency_panel.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  test('native startup keeps white surfaces in either device theme', () {
    for (final folder in ['values', 'values-night']) {
      final styles = File(
        'android/app/src/main/res/$folder/styles.xml',
      ).readAsStringSync();
      expect(styles, contains('Theme.AppCompat.Light.NoActionBar'));
      expect(styles, isNot(contains('?android:colorBackground')));
      expect(styles, contains('android:windowLightStatusBar'));
    }
    expect(
      File(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ).readAsStringSync(),
      contains('@android:color/white'),
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>UIUserInterfaceStyle</key>'));
    expect(plist, contains('<string>Light</string>'));
    for (final comment in RegExp(r'<!--([\s\S]*?)-->').allMatches(plist)) {
      expect(
        comment[1],
        isNot(contains('--')),
        reason: 'XML comments cannot contain double hyphens',
      );
    }
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('SystemChrome.setSystemUIOverlayStyle('));
    expect(main, contains('statusBarIconBrightness: Brightness.dark'));
    expect(
      main,
      contains('systemNavigationBarIconBrightness: Brightness.dark'),
    );
  });

  test('shared feature surfaces and text match the white classic theme', () {
    expect(MortColors.bg, MortClassicColors.canvas);
    expect(MortTheme.classic().chipTheme.checkmarkColor, MortClassicColors.ink);
    for (final surface in [
      MortColors.card,
      MortColors.cardAlt,
      MortColors.bgElevated,
    ]) {
      expect(surface.computeLuminance(), greaterThan(.8));
      expect(contrast(MortColors.text, surface), greaterThanOrEqualTo(7));
      expect(
        contrast(MortColors.textSecondary, surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(MortColors.textMuted, surface),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(MortColors.primary, MortClassicColors.ink);
    expect(
      contrast(MortColors.premium, MortClassicColors.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(MortColors.white, MortColors.primary),
      greaterThanOrEqualTo(7),
    );
  });

  test(
    'app chrome and progression art are neutral; pet artwork is separate',
    () {
      final violations = <String>[];
      final webLoader = File('web/index.html').readAsStringSync();
      for (final match in RegExp(
        r'#([0-9A-Fa-f]{6})\b',
      ).allMatches(webLoader)) {
        final hex = match[1]!.toLowerCase();
        if (hex.substring(0, 2) != hex.substring(2, 4) ||
            hex.substring(2, 4) != hex.substring(4, 6)) {
          violations.add('web/index.html: $hex');
        }
      }
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.dart') &&
                    !f.path.endsWith('mort_pet_colors.dart'),
              )) {
        if (file.readAsStringSync().contains('MortPetColors')) {
          final path = file.path.replaceAll('\\', '/');
          expect(
            {
              'lib/features/companion/companion_catalog.dart',
              'lib/features/companion/companion_avatar.dart',
              'lib/features/companion/companion_studio_screen.dart',
              'lib/features/guide/mort_mascots.dart',
            },
            contains(path),
            reason: 'Character colors must not leak into app chrome',
          );
        }
        for (final match in RegExp(
          r'Color\(0x([0-9A-Fa-f]{8})\)',
        ).allMatches(file.readAsStringSync())) {
          final hex = match[1]!;
          if (hex.substring(2, 4).toLowerCase() !=
                  hex.substring(4, 6).toLowerCase() ||
              hex.substring(4, 6).toLowerCase() !=
                  hex.substring(6, 8).toLowerCase()) {
            violations.add('${file.path}: $hex');
          }
        }
      }
      for (final file
          in Directory('assets/gamification')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.svg'))) {
        for (final match in RegExp(
          r'#([0-9A-Fa-f]{6})\b',
        ).allMatches(file.readAsStringSync())) {
          final hex = match[1]!.toLowerCase();
          if (hex.substring(0, 2) != hex.substring(2, 4) ||
              hex.substring(2, 4) != hex.substring(4, 6))
            violations.add('${file.path}: $hex');
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  testWidgets(
    'paywall has white canvas and black paid action above free exit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: MortTheme.classic(),
          home: Scaffold(
            body: MortProPaywallContent(
              plans: const [
                MortProPlan(
                  id: r'$rc_annual',
                  name: 'Annual',
                  price: 'store price',
                ),
              ],
              loading: false,
              busy: false,
              onPurchase: (_) {},
              onRestore: () {},
              onRetry: () {},
              onClose: () {},
              onTerms: () {},
              onPrivacy: () {},
            ),
          ),
        ),
      );
      final surface =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(MortProPaywallContent),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(surface.color, MortClassicColors.canvas);
      expect(surface.gradient, isNull);
      final selectedPlan =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(const Key(r'plan-$rc_annual')),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect((selectedPlan.border! as Border).top.color, MortClassicColors.ink);
      expect(selectedPlan.gradient, isNull);
      final paid = tester.widget<FilledButton>(
        find.byKey(const Key('pro-continue')),
      );
      expect(paid.style!.backgroundColor!.resolve({}), MortClassicColors.ink);
      expect(
        paid.style!.foregroundColor!.resolve({}),
        MortClassicColors.canvas,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('pro-continue-free'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('pro-continue'))).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'emergency panel is readable on white and keeps emergency actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MortTheme.classic(),
          home: Scaffold(
            body: EmergencyPanel(
              onAlert: () async => const SafetyActionReceipt(),
              onCallEmergency: () async {},
              onShare: () async => const SafetyActionReceipt(),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(EmergencyPanel),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, MortClassicColors.canvas);
      expect(find.text('Call 911'), findsOneWidget);
      expect(find.text('Alert My Safety Contacts'), findsOneWidget);
      final defaultStyle = tester.widget<DefaultTextStyle>(
        find
            .descendant(
              of: find.byType(EmergencyPanel),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(
        contrast(defaultStyle.style.color!, MortClassicColors.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
