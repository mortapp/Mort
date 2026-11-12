import '../../data/services/supabase_service.dart';

/// Leaked-password protection via HaveIBeenPwned's k-anonymity range API,
/// executed through the backend `leaked-password-check` Edge Function.
///
/// The password travels only to MORT's own backend over HTTPS (the same
/// trust boundary as the Supabase Auth call that follows); the Edge
/// Function hashes it locally and sends only the first five characters of
/// the SHA-1 digest to HaveIBeenPwned, so the plain password is never
/// shared with the third-party service.
///
/// Availability policy (matches the web app's lib/leaked-password.ts):
/// fail open on network/API errors — a temporary outage must not lock
/// users out — but a password confirmed to appear in a known breach
/// corpus is always rejected.
class LeakedPasswordCheck {
  LeakedPasswordCheck._();

  static const String leakedPasswordCode = 'leaked_password_compromised';
  static const String leakedPasswordMessage =
      'This password appears in a public data breach. Choose a stronger, '
      'unique password.';

  /// Returns true only when the password is confirmed to appear in a known
  /// breach corpus. Returns false when the check is unavailable (fail open)
  /// or when the password is clean.
  static Future<bool> isLeaked(String password) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      final response = await SupabaseService.client.functions.invoke(
        'leaked-password-check',
        body: {'password': password},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (data['check_unavailable'] == true) return false;
      return data['leaked'] == true;
    } catch (_) {
      // Fail open: a backend outage must not block account creation.
      return false;
    }
  }
}
