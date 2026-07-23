import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('emergency controls are server-owned and fail closed', () {
    final migration = _read(
      '../supabase/migrations/20260722234500_mort_0_9_4_operational_controls.sql',
    );
    final stripe = _read('../supabase/functions/_shared/stripe.ts');

    expect(migration, contains('private.runtime_feature_controls'));
    expect(migration, contains('force row level security'));
    expect(migration, contains('public_marketplace_activation_not_authorized'));
    expect(migration, contains('jobs_runtime_publish_control'));
    expect(migration, contains('private.operational_alerts'));
    expect(migration, contains('operational_review_role_required'));
    expect(stripe, contains('get_runtime_feature_status'));
    expect(stripe, contains('payments_disabled'));
    expect(stripe, contains('maintenance_mode_active'));
  });

  test('alert payloads use safe codes and do not copy raw content', () {
    final migration = _read(
      '../supabase/migrations/20260722234500_mort_0_9_4_operational_controls.sql',
    );

    expect(migration, contains('safe_code'));
    expect(migration, contains('correlation_id'));
    expect(migration, isNot(contains('message_body')));
    expect(migration, isNot(contains('evidence_path')));
    expect(migration, isNot(contains('provider_payload')));
  });
}
