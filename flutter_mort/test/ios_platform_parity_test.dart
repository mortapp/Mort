import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mort/core/auth/oauth_flow.dart';
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_mort/services/screen_security_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS platform parity contract (iOS V6).
///
/// This pins the unconditional iOS-native contracts plus the iOS
/// target-platform behavior of shared platform services.
void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final podfile = File('ios/Podfile').readAsStringSync();
  final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final sceneDelegate = File(
    'ios/Runner/SceneDelegate.swift',
  ).readAsStringSync();

  group('iOS Info.plist contract', () {
    test('registers the exact MORT URL scheme used by the OAuth callback', () {
      expect(
        infoPlist,
        contains('<string>com.mortapp.mobile</string>'),
        reason: 'the scheme must match MortOAuthCallbackPolicy.nativeScheme',
      );
      expect(infoPlist, contains('FlutterDeepLinkingEnabled'));
      expect(
        MortOAuthCallbackPolicy.nativeScheme,
        'com.mortapp.mobile',
        reason: 'policy and platform registration must stay in lockstep',
      );
    });

    test('declares only the sensitive permissions the app actually uses', () {
      expect(infoPlist, contains('NSCameraUsageDescription'));
      expect(infoPlist, contains('NSPhotoLibraryUsageDescription'));
      expect(infoPlist, contains('NSFaceIDUsageDescription'));
      expect(infoPlist, contains('NSLocationWhenInUseUsageDescription'));
    });

    test('never requests background location or background modes', () {
      expect(
        infoPlist,
        isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')),
      );
      expect(infoPlist, isNot(contains('UIBackgroundModes')));
    });

    test('keeps App Transport Security strict', () {
      expect(infoPlist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(infoPlist, isNot(contains('NSExceptionDomains')));
    });

    test('carries the MORT identity and portrait-first orientation policy', () {
      expect(infoPlist, contains('<string>MORT</string>'));
      expect(infoPlist, contains('UIInterfaceOrientationPortrait'));
      expect(infoPlist, contains('UISceneDelegateClassName'));
    });
  });

  group('iOS Xcode project contract', () {
    test('uses the real production bundle identity', () {
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile;'),
      );
      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.mortapp.mobile.RunnerTests;'),
        reason: 'test target uses the derived test identifier',
      );
    });

    test('pins the deployment target consistently at iOS 15.0', () {
      expect(pbxproj, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
      expect(podfile, contains("platform :ios, '15.0'"));
      expect(
        podfile,
        contains(
          "config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'",
        ),
        reason: 'Podfile post_install keeps pods at the same floor',
      );
    });

    test('fabricates no capabilities it cannot back', () {
      expect(
        pbxproj,
        isNot(contains('CODE_SIGN_ENTITLEMENTS')),
        reason:
            'no APNs or Sign in with Apple entitlement until provider '
            'configuration and legal gates actually exist',
      );
      expect(pbxproj, contains('GENERATE_INFOPLIST_FILE = YES;'));
    });
  });

  group('iOS native privacy shield contract', () {
    test('AppDelegate wires the shared screen-security channel', () {
      expect(appDelegate, contains('mort/native_security'));
      expect(appDelegate, contains('"setSecureScreen"'));
    });

    test('shield reacts to inactive state and screen capture', () {
      expect(appDelegate, contains('willResignActiveNotification'));
      expect(appDelegate, contains('didBecomeActiveNotification'));
      expect(appDelegate, contains('capturedDidChangeNotification'));
    });

    test('shield is decorative only and hidden from accessibility', () {
      expect(appDelegate, contains('accessibilityElementsHidden = true'));
      expect(appDelegate, contains('mort_privacy_shield'));
    });

    test('SceneDelegate uses the Flutter scene lifecycle', () {
      expect(sceneDelegate, contains('FlutterSceneDelegate'));
    });
  });

  group('shared services under TargetPlatform.iOS', () {
    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      ScreenSecurityService.setPlatformSetter((_) async {});
      await ScreenSecurityService.debugReset();
      ScreenSecurityService.setPlatformSetter(null);
    });

    test('screen security engages native protection on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <bool>[];
      ScreenSecurityService.setPlatformSetter((enabled) async {
        calls.add(enabled);
      });

      await ScreenSecurityService.acquire();
      await ScreenSecurityService.acquire();
      await ScreenSecurityService.release();

      expect(calls, [true], reason: 'nested acquires produce one enable');
      await ScreenSecurityService.release();
      expect(calls, [true, false], reason: 'final release disables once');
    });

    test(
      'missing iOS local-auth plugin degrades gracefully instead of crashing',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final capability = await DeviceAuthenticationService().capability();

        expect(capability.supported, isFalse);
        expect(capability.hasEnrolledBiometrics, isFalse);
        expect(capability.label, 'Unavailable');

        final result = await DeviceAuthenticationService().authenticate(
          'Unlock private MORT content.',
        );
        expect(result.succeeded, isFalse);
        expect(result.status, DeviceAuthenticationStatus.unavailable);
        expect(
          result.message,
          'Device authentication is unavailable on this device.',
        );
      },
    );
  });

  group('iOS OAuth callback policy edge cases', () {
    test('cold-start callback without query still requires the exact route', () {
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('com.mortapp.mobile://app/auth-callback'),
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('com.mortapp.mobile://app/auth-callback/extra'),
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('fragment-encoded state is preserved through normalization', () {
      final normalized = MortOAuthCallbackPolicy.normalize(
        Uri.parse('/auth-callback?code=opaque#step=2'),
        isWeb: false,
      );
      expect(normalized.fragment, 'step=2');
      expect(normalized.queryParameters['code'], 'opaque');
    });

    test('truncated percent-escapes in fragments are hostile, never trusted', () {
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('com.mortapp.mobile://app/auth-callback#%E0%80'),
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('hostile fragments can never crash the approval check', () {
      for (final fragment in ['%=', '%%', '%E0%80', '%=broken']) {
        final uri = Uri.parse(
          'com.mortapp.mobile://app/auth-callback#$fragment',
        );
        expect(
          () => MortOAuthCallbackPolicy.isApproved(uri, isWeb: false),
          returnsNormally,
        );
      }
    });
  });

  test('services channel name matches the native registration', () {
    const channel = MethodChannel('mort/native_security');
    expect(channel.name, 'mort/native_security');
    expect(appDelegate, contains('mort/native_security'));
  });
}
