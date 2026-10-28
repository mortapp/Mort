import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'required guardian consent is rechecked when an application is accepted',
    () {
      final migration = File(
        '../supabase/migrations/20261028044508_guard_job_acceptance_guardian_consent.sql',
      ).readAsStringSync();

      expect(migration, contains('v_job.requires_guardian_approval'));
      expect(migration, contains('v_app.applicant_id'));
      expect(migration, contains("gl.status = 'active'"));
      expect(migration, contains('gl.teen_consent_at is not null'));
      expect(migration, contains('gl.guardian_consent_at is not null'));
      expect(
        migration,
        contains("raise exception 'guardian_approval_required'"),
      );
    },
  );
}
