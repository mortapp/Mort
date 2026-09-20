import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mort/data/models/account_trust.dart';

void main() {
  test('teen verification keeps age, school, and identity checks separate', () {
    final status = TeenVerificationStatus.fromMap({
      'mode': 'sandbox',
      'environment': 'sandbox',
      'submissions_enabled': true,
      'school_id_required': true,
      'school_email_required': true,
      'session_id': '2a91f02b-ecfa-4d84-af7f-a128d651fa73',
      'status': 'manual_review',
      'age_band': '16_17',
      'school_email_verified': true,
      'school_id_status': 'under_review',
      'age_status': 'unresolved',
      'identity_status': 'unresolved',
      'production_collection_enabled': false,
      'raw_document_public': false,
      'school_name_public': false,
    });

    expect(status.hasSession, isTrue);
    expect(status.schoolEmailVerified, isTrue);
    expect(status.ageStatus, 'unresolved');
    expect(status.identityStatus, 'unresolved');
    expect(status.verified, isFalse);
    expect(status.rawDocumentPublic, isFalse);
    expect(status.schoolNamePublic, isFalse);
  });

  test(
    'teen verification becomes verified only when every required result passes',
    () {
      final status = TeenVerificationStatus.fromMap({
        'mode': 'production',
        'environment': 'production',
        'submissions_enabled': true,
        'school_id_required': true,
        'school_email_required': true,
        'session_id': '2a91f02b-ecfa-4d84-af7f-a128d651fa73',
        'status': 'verified',
        'age_band': '13_15',
        'school_email_verified': true,
        'school_id_status': 'reviewed',
        'age_status': 'verified',
        'identity_status': 'verified',
        'production_collection_enabled': true,
        'raw_document_public': false,
        'school_name_public': false,
      });

      expect(status.verified, isTrue);
      expect(status.isSandbox, isFalse);
    },
  );
}
