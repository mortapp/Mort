import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('avatar replacement is canonical, compensating, and expiring', () {
    final repository = _read('lib/data/repositories/avatar_repository.dart');
    final model = _read('lib/data/models/profile.dart');
    final edge = _read('../supabase/functions/avatar-url/index.ts');
    final authorization = _read(
      '../supabase/migrations/20260722222534_mort_0_9_3_ai_and_signed_media_rate_limits.sql',
    );

    expect(repository, contains('_profiles.setAvatarPath(path)'));
    expect(repository, contains('client.storage.from(bucket).remove([path])'));
    expect(repository, contains('record_avatar_orphan_cleanup'));
    expect(repository, contains('_maximumSignedUrlEntries = 64'));
    expect(repository, contains('_signedUrlLifetime = Duration(minutes: 55)'));
    expect(model, contains('avatarUpdatedAt'));
    expect(edge, contains('auth.getUser(token)'));
    expect(edge, contains('authorize_profile_avatar_url'));
    expect(authorization, contains('avatar_moderation_status'));
    expect(authorization, contains('account_status'));
    expect(authorization, contains('public.blocks'));
    expect(authorization, contains('avatar_signed_url'));
  });

  test('support and evidence remain private and authorized', () {
    final migration = _read(
      '../supabase/migrations/20260722202139_mort_0_9_3_support_execution_evidence_payments.sql',
    );
    final evidenceEdge = _read(
      '../supabase/functions/support-evidence-url/index.ts',
    );

    expect(migration, contains("'support-evidence', false"));
    expect(migration, contains('force row level security'));
    expect(migration, contains('evidence_attachment_limit_reached'));
    expect(migration, contains('authorize_support_evidence_url'));
    expect(evidenceEdge, contains('createSignedUrl'));
    expect(evidenceEdge, contains('"Cache-Control": "private, no-store"'));
    expect(evidenceEdge, isNot(contains('getPublicUrl')));
  });

  test('start and finish PINs are hashed, expiring, locked, and single use', () {
    final migration = _read(
      '../supabase/migrations/20260722202206_mort_0_9_3_job_execution_pins.sql',
    );

    expect(migration, contains(r"p_pin !~ '^[0-9]{6}$'"));
    expect(
      migration,
      contains("extensions.crypt(v_pin, extensions.gen_salt('bf', 10))"),
    );
    expect(migration, contains('pin_ttl_seconds integer not null default 600'));
    expect(
      migration,
      contains('maximum_pin_attempts integer not null default 5'),
    );
    expect(migration, contains('start_pin_used_at is not null'));
    expect(migration, contains('finish_pin_used_at is not null'));
    expect(migration, contains("'money_moved', false"));
  });

  test('abandonment report cannot itself apply a cooldown', () {
    final correction = _read(
      '../supabase/migrations/20260722212441_mort_0_9_3_abandonment_decision_safety.sql',
    );

    expect(correction, contains('report_possible_teen_abandonment'));
    expect(correction, contains('respond_to_teen_abandonment'));
    expect(correction, contains('staff_finalize_teen_abandonment'));
    expect(correction, contains("'allegation_only', true"));
    expect(correction, contains("'cooldown_applied', false"));
    expect(correction, contains('confirmed_non_safety_abandonment'));
    expect(correction, contains('safety_cancellation_cannot_be_penalized'));
  });

  test('saved method and resolution operations stay server authorized', () {
    final repository = _read(
      'lib/data/repositories/stripe_marketplace_repository.dart',
    );
    final paymentEdge = _read(
      '../supabase/functions/stripe-resolve-job-payment/index.ts',
    );
    final resolution = _read(
      '../supabase/migrations/20260722202208_mort_0_9_3_payment_resolution.sql',
    );

    expect(repository, contains('record_my_saved_payment_consent'));
    expect(repository, contains('saved-payment-consent-v1'));
    expect(
      paymentEdge,
      contains('stripe_server_load_resolution_for_execution'),
    );
    expect(paymentEdge, isNot(contains('payload.transfer_amount')));
    expect(paymentEdge, isNot(contains('payload.refund_amount')));
    expect(paymentEdge, isNot(contains('payload.destination')));
    expect(
      resolution,
      contains('reviewer_financial_operator_separation_required'),
    );
    expect(resolution, contains('provider_dispute_blocks_resolution'));
    expect(
      resolution,
      contains(
        "if p_environment = 'live' then raise exception 'stripe_live_disabled'",
      ),
    );
  });

  test('AI support cannot authorize financial or evidence decisions', () {
    final ai = _read('../supabase/functions/ai-support/index.ts');
    final client = _read('lib/data/repositories/mort_guide_repository.dart');

    expect(ai, contains('faq_only'));
    expect(ai, contains('store: false'));
    expect(ai, isNot(contains('stripe-resolve-job-payment')));
    expect(ai, isNot(contains('staff_finalize_teen_abandonment')));
    expect(client, isNot(contains('stripe_server_')));
  });
}
