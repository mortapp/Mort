import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('admin details use redacted independently authorized RPCs', () {
    final repository = _read('lib/data/repositories/admin_repository.dart');
    final screen = _read(
      'lib/features/admin/admin_moderation_detail_screen.dart',
    );
    final migration = _read(
      '../supabase/migrations/20260722233000_mort_0_9_4_admin_moderation_controls.sql',
    );

    expect(repository, contains("'admin_get_moderation_record'"));
    expect(repository, contains("'admin_update_report_status'"));
    expect(repository, contains("'admin_set_account_status'"));
    expect(screen, contains('Required decision reason'));
    expect(screen, contains('Raw identity files'));
    expect(migration, contains('private.can_manage_incident(auth.uid())'));
    expect(migration, contains('private.is_production_identity_reviewer'));
    expect(migration, contains("'raw_evidence_included', false"));
    expect(migration, contains('admin_self_restriction_blocked'));
    expect(migration, contains('peer_admin_action_blocked'));
    expect(migration, contains('reasoned_report_status_update'));
    expect(migration, contains('reasoned_account_status_update'));
  });

  test('dead admin detail controls are removed from the router', () {
    final router = _read('lib/core/routing/app_router.dart');

    expect(router, contains('AdminModerationDetailScreen'));
    expect(router, isNot(contains("_adminDetail('Report detail'")));
    expect(router, isNot(contains('Admin resolve report')));
    expect(router, isNot(contains('Admin restrict/suspend user')));
    expect(
      router,
      isNot(contains('sensitiveAction: AdminSensitiveQueueAction.identity')),
    );
    expect(
      _read('lib/features/admin/admin_moderation_detail_screen.dart'),
      contains('Actual provider verification is not connected'),
    );
  });
}
