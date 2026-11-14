import '../../data/services/supabase_service.dart';

/// Leaked-password protection via HaveIBeenPwned's k-anonymity range API,
/// executed through the backend `leaked-password-check` Edge Function.
///
/// The password is sent only to MORT's authenticated backend over HTTPS.
/// The Edge Function hashes it server-side and sends only the first five
/// SHA-1 digest characters to HaveIBeenPwned; the plaintext password is
/// never sent to the third-party service or written to logs.
///
/// Availability policy: fail open on network/API errors — a temporary
/// provider outage must not lock users out — but a confirmed breached
/// password is always rejected.
class LeakedPasswordCheck {
  LeakedPasswordCheck._();

  static const String leakedPasswordCode = 'leaked_password_compromised';
  static const String leakedPasswordMessage =
      'This password appears in a public data breach. Choose a stronger, '
      'unique password.';

  /// Interprets the deployed Edge Function contract. A degraded response
  /// is unavailable, not evidence that the password is clean.
  static bool responseIsLeaked(Map<String, dynamic> data) {
    if (data['check_unavailable'] == true) return false;
    return data['leaked'] == true;
  }

  /// Returns true only when the backend confirms the password is breached.
  /// Returns false when the check is unavailable (fail open) or clean.
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
      return responseIsLeaked(data);
    } catch (_) {
      // Fail open: a backend outage must not block account creation.
      return false;
    }
  }
}
