import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = File(
    'lib/data/repositories/auth_repository.dart',
  ).readAsStringSync();
  final settings = File(
    'lib/features/settings/account_management_screens.dart',
  ).readAsStringSync();
  final providers = File(
    'lib/data/repositories/providers.dart',
  ).readAsStringSync();
  final service = File(
    'lib/data/services/supabase_service.dart',
  ).readAsStringSync();

  test('ordinary logout is explicitly local and global logout is separate', () {
    expect(auth, contains('signOutLocal() => _signOut(SignOutScope.local)'));
    expect(auth, contains('signOutGlobal() => _signOut(SignOutScope.global)'));
    expect(auth, contains('Future<void> signOut() => signOutLocal()'));
    expect(settings, contains('Sign out on this device'));
    expect(settings, contains('Sign out on all devices'));
    expect(settings, contains('Sign out on every device?'));
  });

  test('logout clears persisted auth and user-scoped provider state', () {
    expect(auth, contains('SupabaseService.clearPersistedSession()'));
    expect(service, contains('removePersistedSession()'));
    expect(settings, contains('invalidateUserScopedProviders(ref)'));
    for (final provider in [
      'currentProfileProvider',
      'openJobsProvider',
      'messagingRepositoryProvider',
      'notificationsRepositoryProvider',
      'supportRepositoryProvider',
    ]) {
      expect(providers, contains('ref.invalidate($provider)'));
    }
  });

  test('delete account stays a separate explicit workflow', () {
    expect(settings, contains('class AccountDeletionRequestScreen'));
    expect(settings, contains("route: '/settings/account-deletion'"));
    expect(settings, isNot(contains('deleteUser(')));
  });
}
