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
    this.handoffUrl,
    this.handoffExpiresAt,
    this.status = 'pending',
  });

  final String id;
  final VerificationEnvironment environment;
  final String provider;
  final String providerReference;
  final bool testMode;
  final bool documentsAllowed;
  final Uri? handoffUrl;
  final DateTime? handoffExpiresAt;
  final String status;
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
      status: response['status'] as String? ?? 'pending',
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

class HostedProductionVerificationProvider
    implements ProductionVerificationProvider {
  const HostedProductionVerificationProvider(this._createSession);

  final Future<Map<String, dynamic>> Function() _createSession;

  @override
  Future<VerificationSession> createSession() async {
    final response = await _createSession();
    final uri = Uri.tryParse(response['handoff_url'] as String? ?? '');
    final expiresAt = DateTime.tryParse(
      response['handoff_expires_at'] as String? ?? '',
    )?.toUtc();
    final now = DateTime.now().toUtc();
    if (response['environment'] != 'production' ||
        response['documents_collected_by_mort'] != false ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(now) ||
        expiresAt.isAfter(now.add(const Duration(minutes: 31)))) {
      throw const MortCodedError(
        'provider_handoff_invalid',
        'The secure verification handoff could not be validated.',
      );
    }
    return VerificationSession(
      id: response['session_request_id'] as String? ?? '',
      environment: VerificationEnvironment.production,
      provider: response['provider'] as String? ?? 'approved_provider',
      providerReference: '',
      testMode: false,
      documentsAllowed: true,
      handoffUrl: uri,
      handoffExpiresAt: expiresAt,
      status: response['status'] as String? ?? 'pending',
    );
  }
}

IdentityVerificationProvider providerForStatus(
  IdentityVerificationStatus status, {
  required Future<Map<String, dynamic>> Function() createSandboxSession,
  required Future<Map<String, dynamic>> Function() createProductionSession,
}) {
  if (status.verificationMode == 'sandbox' && status.sandboxEligible) {
    return SandboxVerificationProvider(createSandboxSession);
  }
  if (status.verificationMode == 'production' &&
      status.productionProviderAvailable) {
    return HostedProductionVerificationProvider(createProductionSession);
  }
  return const DisabledVerificationProvider();
}
