// Manual visual QA only. Synthetic status and prices are visibly labelled;
// these renders are not device, delivery, purchase or provider evidence.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/monetization/widgets/mort_pro_paywall_content.dart';
import 'package:flutter_mort/features/safety/emergency_panel.dart';
import 'package:flutter_mort/features/safety/safety_calm_surface.dart';
import '../test/helpers/mort_widget_harness.dart';

class _VisualSafety extends SafetyRepository {
  @override
  Future<Map<String, dynamic>> getRuntime() async => {
    'ok': true,
    'safety_state': 'attention',
    'job_title': 'QA local organizing task',
    'application_id': '00000000-0000-4000-8000-000000000001',
    'guardian_count': 1,
    'trusted_count': 1,
    'review_hold': true,
  };
  @override
  Future<Map<String, dynamic>> getSafetyCenterConfig() async => {
    'emergency_phone_uri': 'tel:911',
  };
  @override
  Future<List<Map<String, dynamic>>> listActiveJobCheckins() async => [];
}

void main() {
  const output = String.fromEnvironment('MORT_QA_RENDER_DIR');
  const fonts = String.fromEnvironment('MORT_QA_FONT_DIR');
  testMortWidgets(
    'Render current landing, Safety and refined paywall for visual inspection',
    (tester) async {
      if (output.isEmpty || fonts.isEmpty)
        throw StateError(
          'Provide explicit QA output and Flutter material font directories.',
        );
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto');
        for (final file in [
          'roboto-regular.ttf',
          'roboto-light.ttf',
          'roboto-bold.ttf',
        ]) {
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File('$fonts/$file').readAsBytes()),
            ),
          );
        }
        await loader.load();
        // Widget tests default unspecified text styles to the square Ahem face.
        // Try normal Material fonts for fallback styles. The test engine may
        // retain preloaded Ahem; this is not native font certification.
        final fallback = FontLoader('Ahem');
        for (final file in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
          fallback.addFont(
            Future.value(
              ByteData.sublistView(await File('$fonts/$file').readAsBytes()),
            ),
          );
        }
        await fallback.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File('$fonts/materialicons-regular.otf').readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final profile = Profile(
        id: 'qa-visual-only',
        role: UserRole.teen,
        displayName: 'QA Teen',
        username: 'qa_preview',
        dob: DateTime(2011, 1, 15),
        city: 'QA city',
        state: 'IN',
        onboardingCompleted: true,
        accountStatus: 'active',
        verificationStatus: 'approved',
        paymentPreference: 'none',
      );
      Future<void> render(
        String filename,
        String label,
        Widget child, {
        double height = 844,
        Future<void> Function()? check,
      }) async {
        await tester.binding.setSurfaceSize(Size(390, height));
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              safetyRepositoryProvider.overrideWithValue(_VisualSafety()),
              currentProfileProvider.overrideWithValue(
                AsyncValue.data(profile),
              ),
              backendConnectionStatusProvider.overrideWith((_) async => false),
            ],
            child: MaterialApp(
              theme: MortTheme.dark(),
              home: RepaintBoundary(
                key: boundaryKey,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(390, height),
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: const Color(0xFF142235),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(child: SafetyCalmSurface(child: child)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await Directory(output).create(recursive: true);
          await File(
            '$output/$filename',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        if (check != null) await check();
        await tester.pumpWidget(const SizedBox.shrink());
      }

      await render(
        'MORT_LANDING_CURRENT_UI_2026-09-27.png',
        'QA render • current landing • backend offline',
        const SplashScreen(),
      );
      await render(
        'MORT_SAFETY_CENTER_QA_2026-09-27.png',
        'QA render • synthetic Safety status • no alert sent',
        const SafetyCenterScreen(),
      );
      await render(
        'MORT_EMERGENCY_PANEL_QA_2026-09-27.png',
        'QA render • no alert, call or location action performed',
        EmergencyPanel(
          onAlert: () async => const SafetyActionReceipt(),
          onShare: () async => const SafetyActionReceipt(),
          onCallEmergency: () async {},
          onCallGuardian: () async {},
          onCallTrusted: () async {},
          onLeave: () async {},
        ),
      );
      var freeContinues = 0;
      var purchases = 0;
      await render(
        'MORT_PRO_PAYWALL_QA_SAMPLE_PRICES_2026-09-27.png',
        'QA render • sample prices • no purchase performed',
        MortProPaywallContent(
          plans: const [
            MortProPlan(id: r'$rc_weekly', name: 'Weekly', price: '\$1.09'),
            MortProPlan(id: r'$rc_monthly', name: 'Monthly', price: '\$3.49'),
            MortProPlan(id: r'$rc_annual', name: 'Annual', price: '\$29.99'),
            MortProPlan(
              id: r'$rc_lifetime',
              name: 'Lifetime',
              price: '\$99.99',
            ),
          ],
          loading: false,
          busy: false,
          onPurchase: (_) => purchases++,
          onRestore: () {},
          onRetry: () {},
          onClose: () => freeContinues++,
          onTerms: () {},
          onPrivacy: () {},
        ),
        height: 1200,
        check: () async {
          final free = find.byKey(const Key('pro-continue-free'));
          expect(free, findsOneWidget);
          await tester.ensureVisible(free);
          expect(
            tester.getTopLeft(free).dy,
            greaterThan(
              tester.getBottomLeft(find.byKey(const Key('pro-continue'))).dy,
            ),
          );
          await tester.tap(free);
          expect(freeContinues, 1);
          expect(purchases, 0);
        },
      );
    },
  );
}
