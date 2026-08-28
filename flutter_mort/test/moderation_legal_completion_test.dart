import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('moderation uses narrow reasoned server actions', () {
    final repository = _read('lib/data/repositories/admin_repository.dart');
    final screens = _read('lib/features/mort_screens.dart');
    final router = _read('lib/core/routing/app_router.dart');

    expect(repository, isNot(contains('updateById(')));
    expect(repository, contains("'admin_moderate_job'"));
    expect(repository, contains("'admin_moderate_review'"));
    expect(repository, contains("'admin_set_account_status_v2'"));
    expect(repository, contains("'admin_claim_account_ban_appeal'"));
    expect(repository, contains("'admin_review_account_ban_appeal'"));
    expect(screens, contains('Internal decision note'));
    expect(screens, contains('Appeal this ban'));
    expect(screens, contains('AdminBanAppealsScreen'));
    expect(router, contains("'/admin/ban-appeals'"));
    expect(router, contains('AdminModerationQueueAction.rejectJob'));
    expect(router, contains('AdminModerationQueueAction.approveReview'));
  });

  test(
    'migration locks least privilege, independent appeals, and launch gate',
    () {
      final migration = _read(
        '../supabase/migrations/20260801233508_moderation_legal_activation_completion.sql',
      );

      for (final policy in [
        'jobs_insert_admin_only',
        'jobs_update_admin_only',
        'jobs_delete_admin_only',
        'admin_action_logs_insert_admin',
      ]) {
        expect(migration, contains('drop policy if exists $policy'));
      }
      expect(migration, contains('job_moderation_reason_code_invalid'));
      expect(migration, contains('ban_reversal_independent_review_required'));
      expect(migration, contains('independent_reviewer_required'));
      expect(migration, contains('assignment_expires_at'));
      expect(migration, contains('expiring_assignment_required'));
      expect(migration, contains('moderation_staffing_approved'));
      expect(migration, contains('approved_document_set_hash'));
      expect(migration, contains('private.public_release_legal_ready()'));
      expect(
        migration,
        contains('public_marketplace_activation_gate_incomplete'),
      );
    },
  );

  test('separate legal drafts match the cataloged immutable hashes', () {
    const files = {
      '../docs/legal/MORT_COMMUNITY_GUIDELINES_DRAFT.md':
          'ce5a733e00a6eeea3371ac469fdf9c6741812a75937977454a59565b2d006912',
      '../docs/legal/MORT_SAFETY_RULES_DRAFT.md':
          'd6b2e10f36155a11bd2b8af19ff368d782c3d41aa441ddbffd732883624b9d26',
      '../docs/legal/MORT_GUARDIAN_TERMS_DRAFT.md':
          '4c258d4be011c0e2af017999b93850229570a18e44f8d14ae6b19ca6c3ea1106',
    };

    for (final entry in files.entries) {
      final bytes = File(entry.key).readAsBytesSync();
      final source = String.fromCharCodes(bytes);
      expect(source, contains('DRAFT - NOT ATTORNEY REVIEWED'));
      expect(source, contains('Effective date: pending'));
      expect(sha256.convert(bytes).toString(), entry.value);
    }
  });
}
