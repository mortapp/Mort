import 'package:flutter_mort/data/repositories/guardian_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes the live UUID result from accept_guardian_invite', () {
    final result = GuardianRepository.normalizeAcceptInviteResult(
      'a91e2f77-9e82-4d4a-91d4-cb37bb72d3a1',
    );

    expect(result['ok'], isTrue);
    expect(result['status'], 'linked');
    expect(result['link_id'], 'a91e2f77-9e82-4d4a-91d4-cb37bb72d3a1');
  });

  test('preserves JSON success payloads from compatible invite RPCs', () {
    final result = GuardianRepository.normalizeAcceptInviteResult({
      'ok': true,
      'status': 'linked',
      'link_id': 'link-123',
    });

    expect(result['ok'], isTrue);
    expect(result['status'], 'linked');
    expect(result['link_id'], 'link-123');
  });
}
