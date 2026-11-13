import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/services/supabase_service.dart';

/// Leaked-password protection via HaveIBeenPwned's k-anonymity range API,
/// executed through the backend `leaked-password-check` Edge Function.
///
/// The SHA-1 digest is calculated on-device. Only its first five hexadecimal
/// characters are sent to MORT's backend; the backend sends that prefix to
/// HaveIBeenPwned and returns matching suffixes. The plaintext password and
/// full digest are never sent to either service.
///
/// Availability policy: fail open on network/API errors — a temporary outage
/// must not lock users out — but a password confirmed to appear in a known
/// breach corpus is always rejected.
class LeakedPasswordCheck {
  LeakedPasswordCheck._();

  static const String leakedPasswordCode = 'leaked_password_compromised';
  static const String leakedPasswordMessage =
      'This password appears in a public data breach. Choose a stronger, '
      'unique password.';

  /// The first five uppercase hexadecimal characters of the password's
  /// SHA-1 digest, as required by HaveIBeenPwned's range API.
  static String sha1PrefixForPassword(String password) {
    final digest = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    return digest.substring(0, 5);
  }

  /// Interprets the backend's documented {ok, degraded, suffixes} response.
  /// A degraded or malformed response is unavailable, not a clean result.
  static bool responseContainsPassword(
    String password,
    Map<String, dynamic> data,
  ) {
    if (data['ok'] != true || data['degraded'] == true) return false;
    final suffixes = data['suffixes'];
    if (suffixes is! List) return false;

    final digest = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    final expectedSuffix = digest.substring(5);
    return suffixes.whereType<String>().any(
      (suffix) => suffix.trim().toUpperCase() == expectedSuffix,
    );
  }

  /// Returns true only when the password is confirmed to appear in a known
  /// breach corpus. Returns false when the check is unavailable (fail open)
  /// or when the password is clean.
  static Future<bool> isLeaked(String password) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      final response = await SupabaseService.client.functions.invoke(
        'leaked-password-check',
        body: {'sha1Prefix': sha1PrefixForPassword(password)},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      return responseContainsPassword(password, data);
    } catch (_) {
      // Fail open: a backend outage must not block account creation.
      return false;
    }
  }
}
