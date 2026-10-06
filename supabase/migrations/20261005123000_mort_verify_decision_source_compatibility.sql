-- MORT Verify's first-party writer uses these two explicit decision sources.
-- The older provider-only allowlist rejected sessions before hashing ran.
-- Keep production identity-source checks and all writer permissions intact.
alter table public.identity_verifications
  drop constraint identity_verification_decision_source_check;
alter table public.identity_verifications
  add constraint identity_verification_decision_source_check check (
    decision_source in (
      'sandbox_simulation', 'provider_webhook',
      'approved_manual_exception', 'legacy_import'
    )
    or (
      provider = 'mort_verify'
      and (
        (decision_source = 'mort_verify_pending' and status <> 'verified')
        or decision_source = 'mort_verify_manual_review'
      )
    )
  );
