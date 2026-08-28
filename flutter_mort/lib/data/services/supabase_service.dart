import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';
import 'secure_session_storage.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;
  static LocalStorage? _sessionStorage;

  static bool get isConfigured => AppConfig.isSupabaseConfigured;
  static bool get isInitialized => _initialized && isConfigured;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured || _initialized) return;
    final sessionStorage = kIsWeb
        ? SharedPreferencesLocalStorage(persistSessionKey: mortSecureSessionKey)
        : MortSecureSessionStorage();
    _sessionStorage = sessionStorage;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        detectSessionInUri: true,
        localStorage: sessionStorage,
      ),
    );
    _initialized = true;
  }

  static Future<void> clearPersistedSession() async {
    await _sessionStorage?.removePersistedSession();
  }

  static SupabaseClient get client {
    if (!isInitialized) throw const MortBackendNotConfiguredError();
    return Supabase.instance.client;
  }
}
