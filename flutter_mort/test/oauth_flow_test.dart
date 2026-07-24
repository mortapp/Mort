import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/auth/oauth_flow.dart';

void main() {
  group('MortOAuthCallbackPolicy', () {
    test('accepts only the exact registered native callback', () {
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('com.mortapp.mobile://app/auth-callback?code=opaque'),
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse(
            'com.mortapp.mobile://other-host/auth-callback?code=opaque',
          ),
          isWeb: false,
        ),
        isFalse,
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('mort://auth-callback?code=opaque'),
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('accepts exact HTTPS web callback and rejects open redirects', () {
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('https://mort-web.vercel.app/auth-callback?code=opaque'),
          isWeb: true,
        ),
        isTrue,
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse(
            'https://mort-web.vercel.app.evil.example/auth-callback?code=opaque',
          ),
          isWeb: true,
        ),
        isFalse,
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('https://mort-web.vercel.app/other?code=opaque'),
          isWeb: true,
        ),
        isFalse,
      );
    });

    test('rejects callbacks that place bearer tokens in the URL', () {
      for (final parameter in ['access_token', 'refresh_token', 'id_token']) {
        expect(
          MortOAuthCallbackPolicy.isApproved(
            Uri.parse(
              'com.mortapp.mobile://app/auth-callback?$parameter=must-not-appear',
            ),
            isWeb: false,
          ),
          isFalse,
        );
      }
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse(
            'com.mortapp.mobile://app/auth-callback#access_token=must-not-appear',
          ),
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('normalizes the exact native route emitted by the router', () {
      final normalized = MortOAuthCallbackPolicy.normalize(
        Uri.parse('/auth-callback?code=opaque'),
        isWeb: false,
      );
      expect(
        normalized.toString(),
        'com.mortapp.mobile://app/auth-callback?code=opaque',
      );
      expect(
        MortOAuthCallbackPolicy.isApproved(
          Uri.parse('/auth-callback?code=opaque'),
          isWeb: false,
        ),
        isTrue,
      );
    });

    test('maps cancellation and state mismatch to safe states', () {
      expect(
        MortOAuthCallbackPolicy.providerFailure(
          Uri.parse(
            'com.mortapp.mobile://app/auth-callback?error=access_denied&error_description=private',
          ),
        ).stage,
        OAuthFlowStage.providerCanceled,
      );
      final mismatch = MortOAuthCallbackPolicy.providerFailure(
        Uri.parse(
          'com.mortapp.mobile://app/auth-callback?error_code=bad_oauth_state',
        ),
      );
      expect(mismatch.stage, OAuthFlowStage.stateMismatch);
      expect(mismatch.message, isNot(contains('private')));
    });
  });

  group('OAuthLaunchGate', () {
    test('prevents duplicate launches and enforces a short cooldown', () {
      final gate = OAuthLaunchGate(cooldown: const Duration(seconds: 2));
      final start = DateTime.utc(2026, 7, 23);
      expect(gate.tryAcquire(start), isTrue);
      expect(gate.tryAcquire(start), isFalse);
      gate.release(start);
      expect(gate.tryAcquire(start.add(const Duration(seconds: 1))), isFalse);
      expect(gate.tryAcquire(start.add(const Duration(seconds: 2))), isTrue);
    });
  });
}
