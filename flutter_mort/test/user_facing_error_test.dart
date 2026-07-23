import 'package:flutter_mort/core/errors/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps invalid credentials without exposing backend text', () {
    expect(
      userFacingError(Exception('AuthException: Invalid login credentials')),
      'Invalid email or password.',
    );
  });

  test('maps connectivity failures', () {
    expect(
      userFacingError(Exception('SocketException: failed host lookup')),
      'Check your connection and try again.',
    );
  });

  test('maps authorization failures', () {
    expect(
      userFacingError(Exception('new row violates row-level security policy')),
      'You do not have permission to do that.',
    );
  });

  test('does not echo unknown backend errors', () {
    const sensitiveBackendText = 'database detail that must not reach UI';
    final result = userFacingError(Exception(sensitiveBackendText));
    expect(result, isNot(contains(sensitiveBackendText)));
    expect(result, 'Something went wrong. Please try again.');
  });
}
