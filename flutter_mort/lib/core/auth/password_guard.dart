import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/mort_error.dart';

/// Client for the `password-guard` Edge Function.
///
/// Every password MORT sets (sign-up, recovery, change) goes through this
/// function. It enforces the password policy and the HaveIBeenPwned
/// leaked-password check on the server and fails closed when the check is
/// unavailable. The database rejects password writes that did not pass
/// through it, so there is no client-side fallback: calling
/// `auth.signUp` / `auth.updateUser(password:)` directly will fail.
class PasswordGuard {
  const PasswordGuard(this._client);

  final SupabaseClient _client;

  static const functionName = 'password-guard';

  static const Map<String, String> messages = {
    'password_required': 'Enter a password.',
    'password_too_short': 'Use at least 12 characters.',
    'password_too_long': 'Use a password of 72 bytes or fewer.',
    'password_invalid_characters':
        'Passwords cannot contain tabs or other control characters.',
    'password_complexity_required':
        'Use uppercase, lowercase, a number, and a symbol.',
    'password_contains_email': 'Your password cannot contain your email.',
    'leaked_password_compromised':
        'This password appears in a public data breach. Choose a stronger, unique password.',
    'leaked_password_check_unavailable':
        'MORT could not check this password against known breaches right now. Try again in a few minutes.',
    'password_guard_unconfigured':
        'Account security checks are unavailable right now. Try again later.',
    'email_invalid': 'Enter a valid email.',
    'dob_invalid': 'Enter your full date of birth.',
    'rate_limited': 'Too many attempts. Wait a minute and try again.',
    'authentication_required':
        'Your session expired. Request a new link and try again.',
    'over_email_send_rate_limit':
        'Too many emails were sent recently. Try again later.',
    'user_already_exists': 'An account with this email may already exist.',
  };

  static MortCodedError errorFor(Object? details, {int? status}) {
    final code = details is Map && details['code'] is String
        ? details['code'] as String
        : 'password_guard_failed';
    final message =
        messages[code] ??
        (status != null && status >= 500
            ? 'MORT could not complete this request. Check your date of birth and try again.'
            : 'MORT could not complete this request. Try again.');
    return MortCodedError(code, message);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is Map && data['ok'] == true) {
        return Map<String, dynamic>.from(data);
      }
      throw errorFor(data, status: response.status);
    } on FunctionException catch (error) {
      throw errorFor(error.details, status: error.status);
    }
  }

  /// Returns true when Auth issued a session immediately (email
  /// confirmation disabled); false when the user must confirm by email.
  Future<bool> signUp({
    required String email,
    required String password,
    required String dateOfBirthIso,
    String? displayName,
    String? redirectTo,
  }) async {
    final result = await _invoke({
      'action': 'signup',
      'email': email,
      'password': password,
      'date_of_birth': dateOfBirthIso,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (redirectTo != null && redirectTo.isNotEmpty) 'redirect_to': redirectTo,
    });
    final auth = result['auth'];
    final refreshToken = auth is Map ? auth['refresh_token'] : null;
    if (refreshToken is String && refreshToken.isNotEmpty) {
      await _client.auth.setSession(refreshToken);
      return true;
    }
    return false;
  }

  /// Sets a new password for the signed-in (or recovery-session) user.
  Future<void> updatePassword(String password) async {
    if (_client.auth.currentSession == null) {
      throw errorFor(const {'code': 'authentication_required'});
    }
    await _invoke({'action': 'update_password', 'password': password});
  }
}
