import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/config/release_profile.dart';
import 'package:flutter_mort/features/guardian/teen_consent_draft.dart';

void main() {
  bool allowed({
    bool optedIn = true,
    String stage = 'internal_test',
    MortReleaseProfile profile = MortReleaseProfile.automatedTest,
    String url = 'https://127.0.0.1:54431',
    bool fixtureMode = false,
  }) => allowTeenConsentReplicaDraft(
    optedIn: optedIn,
    stage: stage,
    profile: profile,
    backendUrl: url,
    fixtureMode: fixtureMode,
  );

  test('only an explicitly enabled TLS loopback QA replica is allowed', () {
    expect(allowed(), isTrue);
    expect(allowed(url: 'https://10.0.2.2:54431'), isTrue);
    expect(allowed(optedIn: false), isFalse);
    expect(allowed(stage: 'closed_test'), isFalse);
    expect(allowed(profile: MortReleaseProfile.production), isFalse);
    expect(allowed(fixtureMode: true), isFalse);
    expect(allowed(url: 'http://127.0.0.1'), isFalse);
    expect(allowed(url: 'https://qa.supabase.co'), isFalse);
    expect(allowed(url: 'https://localhost.example.org'), isFalse);
    expect(allowed(url: 'https://localhost@example.org'), isFalse);
    expect(teenConsentReplicaDraftEnabled, isFalse);
  });

  Map<String, dynamic> response({
    String status = 'required',
    Object contract = 1,
    Object version = 1,
    bool ok = true,
  }) => {
    'ok': ok,
    'contract_version': contract,
    'consent_version': version,
    'status': status,
    'request_id': 'synthetic-request-id',
    'expires_at': null,
  };

  test('projects all documented states to typed, non-identifying data', () {
    for (final state in TeenConsentState.values) {
      final parsed = TeenConsentStatus.fromRpc(
        response(status: state.wireValue, version: 2),
      );
      expect(parsed.state, state);
      expect(parsed.version, 2);
      expect(parsed.state.label, isNot(contains('synthetic-request-id')));
    }
    expect(
      TeenConsentState.readyForStaffReview.label,
      'Staff review is still required.',
    );
  });

  test('denials and unknown or malformed states fail closed', () {
    for (final result in [
      null,
      <String, dynamic>{'ok': false, 'code': 'not_eligible'},
      response(ok: false),
      response(contract: 2),
      response(contract: 1.0),
      response(version: 0),
      response(version: '1'),
      response(status: 'active'),
    ]) {
      expect(() => TeenConsentStatus.fromRpc(result), throwsFormatException);
    }
  });
}
