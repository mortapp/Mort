import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/services/supabase_service.dart';

/// Leaked-password protection via HaveIBeenPwned's k-anonymity range API,
/// executed through the backend `leaked-password-check` Edge Function so the
/// device never contacts the third-party API directly.
///
/// Only the first five characters of the password's SHA-1 hash are sent to
/// MORT's own backend; the full hash never leaves the device.
///
/// Availability policy (matches the web app's lib/leaked-password.ts):
/// fail open on network/API errors — a temporary outage must not lock users
/// out — but a password confirmed to appear in a known breach corpus is
/// always rejected.
class LeakedPasswordCheck {
  LeakedPasswordCheck._();

  static const String leakedPasswordCode = 'leaked_password';
  static const String leakedPasswordMessage =
      'This password appears in a public data breach. Choose a stronger, '
      'unique password.';

  /// Returns true only when the password is confirmed to appear in a known
  /// breach corpus. Returns false when the check is unavailable (fail open)
  /// or when the password is clean.
  static Future<bool> isLeaked(String password) async {
    if (!SupabaseService.isInitialized) return false;
    final digest = sha1.convert(utf8.encode(password)).toString().toUpperCase();
    if (digest.length != 40) return false;
    final prefix = digest.substring(0, 5);
    final suffix = digest.substring(5);
    try {
      final response = await SupabaseService.client.functions.invoke(
        'leaked-password-check',
        body: {'sha1Prefix': prefix},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (data['ok'] != true) return false;
      final suffixes = data['suffixes'];
      if (suffixes is! List) return false;
      return suffixes.any((entry) => entry == suffix);
    } catch (_) {
      // Fail open: a backend outage must not block account creation.
      return false;
    }
  }
}
