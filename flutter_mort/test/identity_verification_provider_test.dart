import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/data/models/trust_safety.dart';
import 'package:flutter_mort/services/identity_verification_provider.dart';

void main() {
  test('disabled provider cannot create a session', () {
    const provider = DisabledVerificationProvider();
    expect(provider.createSession, throwsA(isA<MortCodedError>()));
  });

  test('sandbox provider creates a no-document test session', () async {
    const id = '5311a913-1881-4cff-81a1-8402ed97b173';
    const reference = 'sandbox-5311a913-1881-4cff-81a1-8402ed97b173';
    final provider = SandboxVerificationProvider(
      () async => {
        'id': id,
        'environment': 'sandbox',
        'provider': 'mort_sandbox',
        'provider_reference': reference,
        'test_mode': true,
        'documents_allowed': false,
      },
    );

    final session = await provider.createSession();
    expect(session.environment, VerificationEnvironment.sandbox);
    expect(session.testMode, isTrue);
    expect(session.documentsAllowed, isFalse);
  });

  test('server mode selects disabled or sandbox provider', () {
    final disabled = providerForStatus(
      status(mode: 'disabled'),
      createSandboxSession: () async => <String, dynamic>{},
    );
    final sandbox = providerForStatus(
      status(mode: 'sandbox', sandboxEligible: true),
      createSandboxSession: () async => <String, dynamic>{},
    );

    expect(disabled, isA<DisabledVerificationProvider>());
    expect(sandbox, isA<SandboxVerificationProvider>());
  });
}

IdentityVerificationStatus status({
  required String mode,
  bool sandboxEligible = false,
}) {
  return IdentityVerificationStatus.fromMap({
    'status': 'unverified',
    'verification_level': 0,
    'marketplace_enabled': false,
    'guardian_mode_optional': true,
    'verification_mode': mode,
    'production_verified': false,
    'sandbox_eligible': sandboxEligible,
    'test_mode': mode == 'sandbox',
    'submissions_enabled': sandboxEligible,
    'production_provider_available': false,
  });
}
