import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final privacyManifest = File(
    'ios/Runner/PrivacyInfo.xcprivacy',
  ).readAsStringSync();
  final releaseEntitlements = File(
    'ios/Runner/Runner.release.entitlements',
  ).readAsStringSync();
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('iOS bundles a non-tracking privacy manifest', () {
    expect(privacyManifest, contains('<key>NSPrivacyTracking</key>'));
    expect(privacyManifest, contains('<false/>'));
    expect(
      privacyManifest,
      contains('NSPrivacyCollectedDataTypeProductInteraction'),
    );
    expect(
      privacyManifest,
      isNot(contains('NSPrivacyCollectedDataTypePaymentInfo')),
    );
    expect(infoPlist, isNot(contains('NSUserTrackingUsageDescription')));
  });

  test('release and profile bundle privacy resources and production push', () {
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(
      RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.release\.entitlements;',
      ).allMatches(project).length,
      2,
    );
    expect(releaseEntitlements, contains('<key>aps-environment</key>'));
    expect(releaseEntitlements, contains('<string>production</string>'));
  });

  test('rank and Motion Token assets use the shared Flutter bundle', () {
    expect(pubspec, contains('assets/gamification/ranks/'));
    expect(pubspec, contains('assets/gamification/tokens/'));
    expect(pubspec, contains('assets/gamification/badges/'));
  });
}
