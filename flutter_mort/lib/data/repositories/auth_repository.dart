import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../services/supabase_service.dart';

class AuthRepository {
  bool get isConfigured => SupabaseService.isConfigured;

  User? get currentUser => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser
      : null;

  Stream<AuthState> get authStateChanges {
    if (!SupabaseService.isInitialized) return const Stream<AuthState>.empty();
    return SupabaseService.client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.resolvedAuthRedirectUrl,
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final email = currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'This account cannot use password reauthentication. Sign out and sign in again before deleting the account.',
      );
    }
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword(String email) {
    return SupabaseService.client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConfig.resolvedAuthRedirectUrl,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
