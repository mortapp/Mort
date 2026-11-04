import 'package:flutter_mort/core/errors/user_facing_error.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
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

  test('maps a concurrent application acceptance response as retryable', () {
    final message = userFacingError(
      const MortCodedError(
        'job_acceptance_in_progress_retry',
        'job_acceptance_in_progress_retry',
      ),
    );

    expect(message, contains('being accepted by someone else'));
    expect(message, contains('Refresh the application status'));
  });

  test(
    'maps stale application state to refresh instead of claiming success',
    () {
      expect(
        userFacingError(
          const MortCodedError(
            'stale_application_state',
            'stale_application_state',
          ),
        ),
        contains('Refresh before trying that action again'),
      );
    },
  );

  test('maps proposal check-in retry and unverifiable legacy responses', () {
    expect(
      userFacingError(Exception('idempotency_result_unverifiable')),
      contains('could not verify the earlier check-in request'),
    );
    expect(
      userFacingError(Exception('idempotency_key_reused')),
      contains('does not match the original check-in request'),
    );
  });

  test(
    'does not disclose authorization internals from check-in RPC failures',
    () {
      expect(
        userFacingError(Exception('checkin_not_authorized')),
        'That check-in is no longer available. Refresh Safety Center.',
      );
      expect(
        userFacingError(Exception('active_assignment_required')),
        'That job or check-in is no longer active. Refresh Safety Center.',
      );
    },
  );

  test('does not echo unknown backend errors', () {
    const sensitiveBackendText = 'database detail that must not reach UI';
    final result = userFacingError(Exception(sensitiveBackendText));
    expect(result, isNot(contains(sensitiveBackendText)));
    expect(result, 'Something went wrong. Please try again.');
  });
}
