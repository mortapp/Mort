import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'MORT',
      packageName: 'com.mortapp.mobile',
      version: '0.9.11',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('startup failure renders an honest retry action', (tester) async {
    var attempts = 0;
    Future<void> initialize() async {
      attempts++;
      throw StateError('offline');
    }

    await tester.pumpWidget(
      ProviderScope(child: MortBootstrap(initialize: initialize)),
    );
    await tester.pumpAndSettle();

    expect(find.text('MORT could not start'), findsOneWidget);
    expect(find.text('Retry startup'), findsOneWidget);
    final retryButton = tester.widget<MortButton>(
      find.byWidgetPredicate(
        (widget) => widget is MortButton && widget.label == 'Retry startup',
      ),
    );
    retryButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('startup waits for initialization before rendering app', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(child: MortBootstrap(initialize: () => completer.future)),
    );

    expect(find.text('Restoring your session...'), findsOneWidget);
    expect(completer.isCompleted, isFalse);
    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('MORT cannot start securely'), findsOneWidget);
  });

  testWidgets('busy button prevents repeat taps and shows progress', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MortButton(
            label: 'Submit',
            busyLabel: 'Submitting...',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Submitting...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Submitting...'));
    expect(taps, 0);
  });

  testWidgets(
    'startup configuration failure is distinguished from network failure',
    (tester) async {
      Future<void> initialize() async {
        throw const AppConfigValidationException([
          'hosted Supabase public configuration is missing',
        ]);
      }

      await tester.pumpWidget(
        ProviderScope(child: MortBootstrap(initialize: initialize)),
      );
      await tester.pumpAndSettle();

      expect(find.text('MORT could not start'), findsOneWidget);
      expect(
        find.textContaining('secure setup on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('Check your connection'), findsNothing);
      // Internal validation details must never reach the UI.
      expect(find.textContaining('hosted Supabase'), findsNothing);
      expect(find.text('Retry startup'), findsOneWidget);
    },
  );

  testWidgets(
    'maintenance mode renders the maintenance surface without initializing',
    (tester) async {
      var attempts = 0;
      Future<void> initialize() async {
        attempts++;
      }

      await tester.pumpWidget(
        ProviderScope(
          child: MortBootstrap(maintenanceMode: true, initialize: initialize),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MORT is briefly offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(attempts, 0);
    },
  );

  testWidgets('version below the approved minimum renders the update surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MortBootstrap(
          currentAppVersion: '0.9.10',
          initialize: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MORT needs an update'), findsOneWidget);
    expect(find.textContaining('0.9.10'), findsOneWidget);
    expect(find.text('Update MORT'), findsOneWidget);
    expect(find.text('Retry startup'), findsOneWidget);
  });

  testWidgets('version at or above the minimum proceeds through startup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MortBootstrap(
          currentAppVersion: '1.0.0',
          initialize: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MORT cannot start securely'), findsOneWidget);
  });

  group('app version gate', () {
    test('equal version is supported', () {
      expect(AppConfig.isAppVersionSupported('0.9.11'), isTrue);
    });

    test('newer version is supported', () {
      expect(AppConfig.isAppVersionSupported('1.0.0'), isTrue);
    });

    test('older version is unsupported', () {
      expect(AppConfig.isAppVersionSupported('0.9.10'), isFalse);
    });

    test('explicit minimum is honored', () {
      expect(
        AppConfig.isAppVersionSupported('1.2.3', minimum: '1.2.4'),
        isFalse,
      );
      expect(
        AppConfig.isAppVersionSupported('1.2.4', minimum: '1.2.4'),
        isTrue,
      );
    });

    test('unparseable version fails closed', () {
      expect(AppConfig.isAppVersionSupported('not-a-version'), isFalse);
    });

    test('short and suffixed versions parse', () {
      expect(AppConfig.isAppVersionSupported('0.9', minimum: '0.9.0'), isTrue);
      expect(
        AppConfig.isAppVersionSupported('0.9.12-beta', minimum: '0.9.11'),
        isTrue,
      );
    });
  });
}
