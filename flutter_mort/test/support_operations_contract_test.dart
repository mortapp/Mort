import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/repositories/support_repository.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'support operations use explicit roles and private operational tables',
    () {
      final migration = _read(
        '../supabase/migrations/20260730080000_support_human_operations.sql',
      );

      expect(migration, contains('private.support_staff_assignments'));
      expect(migration, contains('private.has_admin_safety_role'));
      expect(migration, isNot(contains("profile.role = 'admin'")));
      expect(migration, contains('support_internal_notes'));
      expect(migration, contains('support_backlog_alerts'));
      expect(migration, contains('appeal_my_support_ticket'));
      expect(migration, contains('aggregate_counts_only'));
      expect(migration, contains('external_gate_unstaffed'));
      expect(migration, contains('targets_are_commitments'));
    },
  );

  test('support repository and UI expose real ownership and appeal paths', () {
    final repository = _read('lib/data/repositories/support_repository.dart');
    final screen = _read('lib/features/support/support_screens.dart');

    expect(repository, contains("'support_staff_claim_ticket'"));
    expect(repository, contains("'support_staff_release_ticket'"));
    expect(repository, contains("'support_staff_add_internal_note'"));
    expect(repository, contains("'appeal_my_support_ticket'"));
    expect(repository, contains("'support_get_service_status'"));
    expect(screen, contains("label: 'Claim case'"));
    expect(screen, contains("label: 'Add private note'"));
    expect(screen, contains("label: 'Appeal outcome'"));
    expect(screen, contains("'Support staffing status'"));
    expect(repository, contains('Human staffing and response times'));
  });

  test('support models preserve non-commitment and assignment state', () {
    final ticket = SupportTicket.fromJson({
      'id': 'ticket-id',
      'case_number': 'MORT-CASE',
      'subject': 'Support subject',
      'assigned_support_user_id': 'staff-id',
      'first_response_due_at': '2026-07-30T12:00:00Z',
      'case_kind': 'appeal',
      'appeal_of_ticket_id': 'original-id',
      'created_at': '2026-07-30T10:00:00Z',
      'updated_at': '2026-07-30T10:00:00Z',
    });
    final status = SupportServiceStatus.fromJson({
      'staffing_status': 'external_gate_unstaffed',
      'timezone': 'America/Indiana/Indianapolis',
      'support_hours': {'display': 'Not staffed yet'},
      'targets_are_commitments': false,
      'response_message':
          'Human staffing and response times are not yet guaranteed.',
    });

    expect(ticket.assignedSupportUserId, 'staff-id');
    expect(ticket.isAppeal, isTrue);
    expect(ticket.firstResponseDueAt, isNotNull);
    expect(status.targetsAreCommitments, isFalse);
    expect(status.hoursDisplay, 'Not staffed yet');
  });
}
