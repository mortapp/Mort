import 'package:flutter/material.dart';
import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/features/auth/google_auth_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _activationProfileUnderTest = bool.fromEnvironment(
  'MORT_GOOGLE_AUTH_ACTIVATION_TEST',
  defaultValue: false,
);

void main() {
  test(
    'closed-test compile configuration activates approved Google Auth',
    () {
      expect(AppConfig.releaseStage, 'closed_test');
      expect(AppConfig.googleAuthEnabled, isTrue);
      expect(
        AppConfig.authRedirectUrl,
        'com.mortapp.mobile://app/auth-callback',
      );
      expect(AppConfig.validationErrors, isEmpty);
      expect(AppConfig.publicMarketplaceEnabled, isFalse);
      expect(AppConfig.marketplacePaymentsEnabled, isFalse);
      expect(AppConfig.adsEnabled, isFalse);
      expect(AppConfig.iapEnabled, isFalse);
      expect(AppConfig.remotePushEnabled, isFalse);
    },
    skip: !_activationProfileUnderTest,
  );

  testWidgets(
    'Continue with Google is visible and enabled',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: GoogleAuthSection())),
        ),
      );
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    },
    skip: !_activationProfileUnderTest,
  );
}
