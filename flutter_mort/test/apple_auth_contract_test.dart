import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final authRepository = File(
    '${Directory.current.path}/lib/data/repositories/auth_repository.dart',
  ).readAsStringSync();
  final appleUi = File(
    '${Directory.current.path}/lib/features/auth/apple_auth_screens.dart',
  ).readAsStringSync();
  final connectedAccountsUi = File(
    '${Directory.current.path}/lib/features/auth/google_auth_screens.dart',
  ).readAsStringSync();
  final appConfig = File(
    '${Directory.current.path}/lib/core/config/app_config.dart',
  ).readAsStringSync();
  final releaseProfile = File(
    '${Directory.current.path}/lib/core/config/release_profile.dart',
  ).readAsStringSync();
  final supabaseService = File(
    '${Directory.current.path}/lib/data/services/supabase_service.dart',
  ).readAsStringSync();
  final root = Directory.current.parent;
  final identityEventMigration = File(
    '${root.path}/supabase/migrations/20260723051250_mort_0_9_5_google_identity_controls.sql',
  ).readAsStringSync();
  final appleIdentityMigration = File(
    '${root.path}/supabase/migrations/20260820000000_apple_identity_controls.sql',
  ).readAsStringSync();

  test('Apple uses the same supported PKCE browser flow as Google', () {
    expect(authRepository, contains('OAuthProvider.apple'));
    expect(authRepository, contains("scopes: 'name email'"));
    expect(authRepository, contains('signInWithApple'));
    expect(authRepository, contains('linkAppleIdentity'));
    expect(authRepository, contains('unlinkAppleIdentity'));
    expect(authRepository, contains('LaunchMode.externalApplication'));
    expect(authRepository, isNot(contains('signInWithIdToken')));
    expect(authRepository, isNot(contains('providerToken')));
    expect(authRepository, isNot(contains('providerRefreshToken')));
    expect(supabaseService, contains('authFlowType: AuthFlowType.pkce'));
  });

  test('Apple Auth is gated the same way Google Auth is gated', () {
    expect(appConfig, contains('appleAuthEnabled'));
    expect(appConfig, contains("'APPLE_AUTH_ENABLED'"));
    expect(releaseProfile, contains('required this.appleAuthEnabled'));
    expect(
      releaseProfile,
      contains('Apple Auth must use the approved native PKCE callback'),
    );
  });

  test('Apple sign-in reuses the identical native callback as Google', () {
    expect(appConfig, contains("'com.mortapp.mobile://app/auth-callback'"));
    expect(authRepository, isNot(contains("'apple://")));
  });

  test('Apple UI has branding, duplicate-tap, and cancellation paths', () {
    expect(appleUi, contains('Continue with Apple'));
    expect(appleUi, contains('Cancel Apple sign-in'));
    expect(appleUi, contains('state.isBusy'));
    expect(appleUi, contains('Semantics('));
    expect(appleUi, contains('AppConfig.appleAuthEnabled'));
  });

  test(
    'Connected accounts screen manages Apple identities alongside Google',
    () {
      expect(connectedAccountsUi, contains('linkAppleIdentity'));
      expect(connectedAccountsUi, contains('unlinkAppleIdentity'));
      expect(connectedAccountsUi, contains('Connect Apple'));
      expect(connectedAccountsUi, contains('Disconnect Apple'));
      expect(connectedAccountsUi, contains('item.isApple'));
    },
  );

  test('identity model tracks Apple the same way it tracks Google', () {
    expect(authRepository, contains('required this.isApple'));
    expect(authRepository, contains("identity.provider == 'apple'"));
  });

  test('the server-side identity-audit RPC accepts Apple, not just Google', () {
    expect(identityEventMigration, contains("if v_provider <> 'google' then"));
    expect(
      appleIdentityMigration,
      contains("if v_provider not in ('google', 'apple') then"),
    );
    expect(
      appleIdentityMigration,
      contains(
        'create or replace function public.record_my_auth_identity_event(',
      ),
    );
    expect(appleIdentityMigration, contains('auth_apple_sign_in'));
    expect(appleIdentityMigration, contains('auth_apple_linked'));
    expect(appleIdentityMigration, contains('auth_apple_unlinked'));
    expect(
      appleIdentityMigration,
      contains(
        'revoke all on function public.record_my_auth_identity_event(text, text, uuid)',
      ),
    );
  });

  test('no OAuth or server secret identifier is embedded as a value', () {
    final combined = '$authRepository\n$appleUi';
    expect(combined, isNot(contains('client_secret=')));
    expect(combined, isNot(contains('service_role=')));
    expect(authRepository, isNot(contains('debugPrint(')));
    expect(authRepository, isNot(contains('print(')));
  });
}
