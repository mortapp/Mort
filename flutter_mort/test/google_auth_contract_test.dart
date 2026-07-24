import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.parent;
  final authRepository = File(
    '${Directory.current.path}/lib/data/repositories/auth_repository.dart',
  ).readAsStringSync();
  final authUi = File(
    '${Directory.current.path}/lib/features/auth/google_auth_screens.dart',
  ).readAsStringSync();
  final appConfig = File(
    '${Directory.current.path}/lib/core/config/app_config.dart',
  ).readAsStringSync();
  final manifest = File(
    '${Directory.current.path}/android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final infoPlist = File(
    '${Directory.current.path}/ios/Runner/Info.plist',
  ).readAsStringSync();
  final migration = File(
    '${root.path}/supabase/migrations/20260723051250_mort_0_9_5_google_identity_controls.sql',
  ).readAsStringSync();

  test('Google uses the supported PKCE browser flow with minimum scopes', () {
    expect(authRepository, contains('signInWithOAuth('));
    expect(authRepository, contains('OAuthProvider.google'));
    expect(authRepository, contains("scopes: 'openid email profile'"));
    expect(authRepository, contains('LaunchMode.externalApplication'));
    expect(authRepository, isNot(contains('signInWithIdToken')));
    expect(authRepository, isNot(contains('providerToken')));
    expect(authRepository, isNot(contains('providerRefreshToken')));
  });

  test('callback identity is exact across Dart, Android, and iOS', () {
    expect(
      appConfig,
      contains("defaultValue: 'com.mortapp.mobile://app/auth-callback'"),
    );
    expect(manifest, contains('android:scheme="com.mortapp.mobile"'));
    expect(manifest, contains('android:host="app"'));
    expect(manifest, contains('android:path="/auth-callback"'));
    expect(manifest, contains('android:path="/auth-confirm"'));
    expect(manifest, contains('android:path="/auth-recovery"'));
    expect(
      appConfig,
      contains("defaultValue: 'com.mortapp.mobile://app/auth-confirm'"),
    );
    expect(
      appConfig,
      contains("defaultValue: 'com.mortapp.mobile://app/auth-recovery'"),
    );
    expect(infoPlist, contains('<string>com.mortapp.mobile</string>'));
    expect(manifest, isNot(contains('android:scheme="mort"')));
  });

  test(
    'Google UI has branding, duplicate-tap, cancellation, and legal paths',
    () {
      expect(authUi, contains('assets/branding/google_g.svg'));
      expect(authUi, contains('Continue with Google'));
      expect(authUi, contains('Cancel Google sign-in'));
      expect(authUi, contains('state.isBusy'));
      expect(authUi, contains('Semantics('));
      expect(authUi, contains('Connected accounts'));
      expect(authUi, contains('Disconnect Google'));
    },
  );

  test('identity audit verifies provider state and stays server owned', () {
    expect(migration, contains('from auth.identities as identity'));
    expect(migration, contains('provider_identity_not_connected'));
    expect(migration, contains('prior_link_event_required'));
    expect(
      migration,
      contains("public.check_rate_limit('auth_identity_event'"),
    );
    expect(
      migration,
      contains(
        'revoke all on function public.record_my_auth_identity_event(text, text, uuid)',
      ),
    );
    expect(migration, isNot(contains('raw_app_meta_data')));
  });

  test('no OAuth or server secret identifier is embedded as a value', () {
    final combined = '$authRepository\n$authUi\n$appConfig';
    expect(combined, isNot(contains('client_secret=')));
    expect(combined, isNot(contains('service_role=')));
    expect(combined, isNot(contains('ya29.')));
  });
}
