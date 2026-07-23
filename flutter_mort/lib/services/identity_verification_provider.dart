import '../core/errors/mort_error.dart';
import '../data/models/trust_safety.dart';

enum VerificationEnvironment { sandbox, production }

enum VerificationEvidenceType {
  governmentId,
  schoolId,
  selfieLiveness,
  addressEvidence,
  providerAssertion,
}

enum VerificationDecision { approved, rejected, needsReview }

enum VerificationFailureReason {
  disabled,
  sandboxAccountRequired,
  providerNotConfigured,
  signatureInvalid,
  replayedEvent,
  accountBindingMismatch,
  unknownResult,
}

class VerificationSession {
  const VerificationSession({
    required this.id,
    required this.environment,
    required this.provider,
    required this.providerReference,
    required this.testMode,
    required this.documentsAllowed,
  });

  final String id;
  final VerificationEnvironment environment;
  final String provider;
  final String providerReference;
  final bool testMode;
  final bool documentsAllowed;
}

class VerificationResult {
  const VerificationResult({
    required this.environment,
    required this.decision,
    required this.provider,
    required this.providerReference,
    required this.productionEligible,
  });

  final VerificationEnvironment environment;
  final VerificationDecision decision;
  final String provider;
  final String providerReference;
  final bool productionEligible;
}

abstract interface class IdentityVerificationProvider {
  Future<VerificationSession> createSession();
}

class DisabledVerificationProvider implements IdentityVerificationProvider {
  const DisabledVerificationProvider();

  @override
  Future<VerificationSession> createSession() {
    throw const MortCodedError(
      'identity_verification_disabled',
      'Identity verification is not accepting public submissions yet.',
    );
  }
}

class SandboxVerificationProvider implements IdentityVerificationProvider {
  const SandboxVerificationProvider(this._createSession);

  final Future<Map<String, dynamic>> Function() _createSession;

  @override
  Future<VerificationSession> createSession() async {
    final response = await _createSession();
    if (response['environment'] != 'sandbox' || response['test_mode'] != true) {
      throw const MortCodedError(
        'sandbox_environment_mismatch',
        'The backend did not return an isolated sandbox session.',
      );
    }
    return VerificationSession(
      id: response['id'] as String,
      environment: VerificationEnvironment.sandbox,
      provider: response['provider'] as String? ?? 'mort_sandbox',
      providerReference: response['provider_reference'] as String,
      testMode: true,
      documentsAllowed: response['documents_allowed'] == true,
    );
  }
}

abstract interface class ProductionVerificationProvider
    implements IdentityVerificationProvider {}

class UnavailableProductionVerificationProvider
    implements ProductionVerificationProvider {
  const UnavailableProductionVerificationProvider();

  @override
  Future<VerificationSession> createSession() {
    throw const MortCodedError(
      'production_provider_not_configured',
      'Production identity verification is unavailable until an approved provider is connected.',
    );
  }
}

IdentityVerificationProvider providerForStatus(
  IdentityVerificationStatus status, {
  required Future<Map<String, dynamic>> Function() createSandboxSession,
}) {
  if (status.verificationMode == 'sandbox' && status.sandboxEligible) {
    return SandboxVerificationProvider(createSandboxSession);
  }
  if (status.verificationMode == 'production' &&
      status.productionProviderAvailable) {
    return const UnavailableProductionVerificationProvider();
  }
  return const DisabledVerificationProvider();
}
