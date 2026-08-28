import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS deployment target satisfies the locked FlutterFire minimum', () {
    final project = File(
      '${Directory.current.path}/ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;')));
  });

  test(
    'iOS native plugins use the canonical Flutter CocoaPods integration',
    () {
      final podfile = File(
        '${Directory.current.path}/ios/Podfile',
      ).readAsStringSync();
      final debugConfig = File(
        '${Directory.current.path}/ios/Flutter/Debug.xcconfig',
      ).readAsStringSync();
      final releaseConfig = File(
        '${Directory.current.path}/ios/Flutter/Release.xcconfig',
      ).readAsStringSync();

      expect(podfile, contains("platform :ios, '15.0'"));
      expect(podfile, contains('flutter_ios_podfile_setup'));
      expect(podfile, contains('flutter_install_all_ios_pods'));
      expect(podfile, contains('flutter_additional_ios_build_settings'));
      expect(debugConfig, contains('Pods-Runner.debug.xcconfig'));
      expect(releaseConfig, contains('Pods-Runner.release.xcconfig'));
    },
  );

  test('iOS shields sensitive content in app snapshots and active capture', () {
    final appDelegate = File(
      '${Directory.current.path}/ios/Runner/AppDelegate.swift',
    ).readAsStringSync();
    final screenSecurity = File(
      '${Directory.current.path}/lib/services/screen_security_service.dart',
    ).readAsStringSync();

    expect(appDelegate, contains('mort/native_security'));
    expect(appDelegate, contains('setSecureScreen'));
    expect(appDelegate, contains('applicationRegistrar.messenger()'));
    expect(appDelegate, contains('willResignActiveNotification'));
    expect(appDelegate, contains('capturedDidChangeNotification'));
    expect(appDelegate, contains('window.screen.isCaptured'));
    expect(appDelegate, contains('mort_privacy_shield'));
    expect(screenSecurity, contains('TargetPlatform.iOS'));
  });
}
