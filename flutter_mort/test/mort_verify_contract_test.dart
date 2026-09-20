import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'MORT Verify remains server-gated and separates verification claims',
    () {
      final screen = File(
        'lib/features/trust/teen_verification_screens.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/data/repositories/mort_verify_repository.dart',
      ).readAsStringSync();

      expect(screen, contains('School affiliation'));
      expect(screen, contains('Student identity'));
      expect(screen, contains('Age:'));
      expect(screen, contains('A school email alone never proves your age.'));
      expect(repository, contains("'get_mort_verify_status'"));
      expect(repository, contains("'verify_mort_school_email_code'"));
      expect(repository, contains("'submit_mort_verify_session'"));
      expect(repository, contains("'mort-verify-evidence'"));
    },
  );

  test(
    'MORT Verify backend install defaults to disabled production collection',
    () {
      final migration = File(
        '../supabase/migrations/20260920201000_mort_verify_first_party_age_school_v1.sql',
      ).readAsStringSync();

      expect(migration, contains("mode='disabled'"));
      expect(
        migration,
        contains('production_document_collection_approved=false'),
      );
      expect(migration, contains("'under_13_not_eligible'"));
      expect(migration, contains("'adult_account_required'"));
      expect(migration, contains("'school_domain_not_approved'"));
      expect(migration, contains("'active_review_assignment_required'"));
      expect(
        migration,
        contains("legal_identity_claimed', false"),
        reason: 'School verification must not claim government/legal identity.',
      );
    },
  );

  test('raw MORT Verify bucket is private and owner/session constrained', () {
    final migration = File(
      '../supabase/migrations/20260920201000_mort_verify_first_party_age_school_v1.sql',
    ).readAsStringSync();

    expect(migration, contains("'mort-verify-evidence'"));
    expect(migration, contains('public = false'));
    expect(
      migration,
      contains('(storage.foldername(name))[1] = (select auth.uid())::text'),
    );
    expect(migration, contains('session.user_id = (select auth.uid())'));
  });
}
