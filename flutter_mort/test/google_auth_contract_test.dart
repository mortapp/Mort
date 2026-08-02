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
  final supabaseService = File(
    '${Directory.current.path}/lib/data/services/supabase_service.dart',
  ).readAsStringSync();
  final secureSessionStorage = File(
    '${Directory.current.path}/lib/data/services/secure_session_storage.dart',
  ).readAsStringSync();
  final routeAccess = File(
    '${Directory.current.path}/lib/core/routing/route_access.dart',
  ).readAsStringSync();
  final accountStatusUi = File(
    '${Directory.current.path}/lib/features/mort_screens.dart',
  ).readAsStringSync();
  final closedAabBuild = File(
    '${root.path}/scripts/build-closed-test-aab.ps1',
  ).readAsStringSync();
  final closedApkBuild = File(
    '${root.path}/scripts/build-closed-test-apk.ps1',
  ).readAsStringSync();
  final releaseBuild = File(
    '${root.path}/scripts/android-release-profile-common.ps1',
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
  final profileBootstrapMigration = File(
    '${root.path}/supabase/migrations/20260729050735_mort_0_9_9_google_profile_bootstrap.sql',
  ).readAsStringSync();

  test('Google uses the supported PKCE browser flow with minimum scopes', () {
    expect(authRepository, contains('signInWithOAuth('));
    expect(authRepository, contains('OAuthProvider.google'));
    expect(authRepository, contains("scopes: 'openid email profile'"));
    expect(authRepository, contains('LaunchMode.externalApplication'));
    expect(authRepository, isNot(contains('signInWithIdToken')));
    expect(authRepository, isNot(contains('providerToken')));
    expect(authRepository, isNot(contains('providerRefreshToken')));
    expect(supabaseService, contains('authFlowType: AuthFlowType.pkce'));
  });

  test('provider token nulls never gate a valid Supabase session', () {
    expect(authRepository, isNot(contains('providerToken')));
    expect(authRepository, isNot(contains('providerRefreshToken')));
    expect(authRepository, contains('OAuthSessionReadinessPolicy.isReady'));
    expect(authRepository, contains('hasSession: session != null'));
    expect(authRepository, contains('hasUser: user != null'));
  });

  test('callback identity is exact across Dart, Android, and iOS', () {
    expect(appConfig, contains("'com.mortapp.mobile://app/auth-callback'"));
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

  test('closed-test builds activate Google with the approved callback', () {
    for (final build in [closedAabBuild, closedApkBuild]) {
      expect(build, contains(r'-GoogleAuthEnabled $true'));
    }
    expect(releaseBuild, contains('MORT_AUTH_REDIRECT_URL'));
    expect(releaseBuild, contains("'com.mortapp.mobile://app/auth-callback'"));
    expect(releaseBuild, contains('GOOGLE_AUTH_ENABLED = '));
    expect(
      releaseBuild,
      contains(
        "throw 'Google Auth activation is approved only for the closed-test profile.'",
      ),
    );
  });

  test('session completion and restoration remain Supabase owned', () {
    expect(authRepository, contains('auth.currentSession'));
    expect(authRepository, contains('auth.currentUser'));
    expect(authRepository, contains('AuthChangeEvent.initialSession'));
    expect(authRepository, contains('AuthChangeEvent.signedIn'));
    expect(authRepository, contains('AuthChangeEvent.userUpdated'));
    expect(authRepository, contains('onError:'));
    expect(authRepository, contains('_completeOAuthOnce'));
    expect(authRepository, contains("rpc('ensure_my_profile')"));
    expect(
      secureSessionStorage,
      contains("'mort.rakjydmgwwgtdislanbt.auth.session.v1'"),
    );
    expect(secureSessionStorage, contains('persistSession('));
    expect(secureSessionStorage, contains('removePersistedSession('));
  });

  test('new and existing accounts retain onboarding and role guards', () {
    expect(routeAccess, contains('profile == null'));
    expect(routeAccess, contains('!profile.onboardingCompleted'));
    expect(routeAccess, contains('RouteAccessDecision.accountRestricted'));
    for (final route in [
      "UserRole.teen => '/teen/home'",
      "UserRole.adult => '/adult/home'",
      "UserRole.guardian => '/guardian/home'",
      "UserRole.admin => '/admin/home'",
      "null => '/onboarding/role'",
    ]) {
      expect(accountStatusUi, contains(route));
    }
    expect(authRepository, contains('OAuthFlowStage.accountSuspended'));
    expect(authRepository, contains('OAuthFlowStage.accountDeletionPending'));
  });

  test('Auth bootstrap creates one idempotent profile without a role', () {
    final initialMigration = File(
      '${root.path}/supabase/migrations/202607070001_initial_mort.sql',
    ).readAsStringSync();
    expect(
      initialMigration,
      contains('id uuid primary key references auth.users(id)'),
    );
    expect(initialMigration, contains('create trigger on_auth_user_created'));
    expect(
      migration,
      contains('insert into public.profiles (id, display_name)'),
    );
    expect(migration, contains('on conflict (id) do nothing'));
    expect(migration, isNot(contains('insert into public.profiles (id, role')));
    expect(profileBootstrapMigration, contains('private.ensure_my_profile()'));
    expect(profileBootstrapMigration, contains('public.ensure_my_profile()'));
    expect(profileBootstrapMigration, contains('from auth.users as auth_user'));
    expect(
      profileBootstrapMigration,
      contains('left join public.profiles as profile'),
    );
    expect(profileBootstrapMigration, contains('on conflict (id) do nothing'));
    expect(
      profileBootstrapMigration,
      isNot(contains('insert into public.profiles (id, role')),
    );
    expect(
      profileBootstrapMigration,
      isNot(contains('update public.profiles')),
    );
    expect(
      profileBootstrapMigration,
      contains('security definer\nset search_path = \'\''),
    );
    expect(
      profileBootstrapMigration,
      contains('revoke all on function public.ensure_my_profile()'),
    );
    expect(
      profileBootstrapMigration,
      contains("tgname = 'on_auth_user_created'"),
    );
  });

  test('the Auth insert trigger is provider-agnostic for future users', () {
    final triggerStart = profileBootstrapMigration.indexOf(
      'create or replace function public.handle_new_auth_user()',
    );
    final triggerEnd = profileBootstrapMigration.indexOf(
      'create or replace function private.ensure_my_profile()',
    );
    final triggerContract = profileBootstrapMigration.substring(
      triggerStart,
      triggerEnd,
    );
    expect(triggerContract, contains('new.id'));
    expect(triggerContract, contains('new.raw_user_meta_data'));
    expect(triggerContract, isNot(contains('auth.identities')));
    expect(triggerContract, isNot(contains("provider = 'google'")));
  });

  test('callback waits for warm, delayed, and cold-start session events', () {
    expect(authRepository, contains('_hasAuthenticatedSession'));
    expect(authRepository, contains('AuthChangeEvent.initialSession'));
    expect(authRepository, contains('state.session != null'));
    expect(authUi, contains('oauthStates.listen('));
    expect(authUi, contains('_handleOAuthState'));
    expect(authUi, contains("context.go('/account-status')"));
  });

  test(
    'post-login failures are categorized without provider token wording',
    () {
      final combined = '$authRepository\n$authUi';
      for (final stage in [
        'OAuthFlowStage.sessionExchangeFailed',
        'OAuthFlowStage.profileBootstrapFailed',
        'OAuthFlowStage.accountSuspended',
        'OAuthFlowStage.accountDeletionPending',
        'OAuthFlowStage.networkUnavailable',
      ]) {
        expect(combined, contains(stage));
      }
      for (final removedCopy in [
        'Google sign-in needs attention',
        'Google authentication could not finish',
        'No private token was stored',
        'Sign-in not completed',
      ]) {
        expect(combined, isNot(contains(removedCopy)));
      }
    },
  );

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
    expect(
      profileBootstrapMigration,
      contains("'correlation_id', gen_random_uuid()::text"),
    );
    expect(profileBootstrapMigration, isNot(contains('raw_app_meta_data')));
  });

  test('no OAuth or server secret identifier is embedded as a value', () {
    final combined = '$authRepository\n$authUi\n$appConfig';
    expect(combined, isNot(contains('client_secret=')));
    expect(combined, isNot(contains('service_role=')));
    expect(combined, isNot(contains('ya29.')));
    expect(authRepository, isNot(contains('debugPrint(')));
    expect(authRepository, isNot(contains('print(')));
  });
}
