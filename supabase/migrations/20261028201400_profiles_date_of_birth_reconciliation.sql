-- Reconcile the live profile schema with the migration chain.
-- Date of birth is required for the legal-consent age-band helper. On the
-- existing production database this is a no-op; clean resets must create the
-- nullable column before the legal clickwrap readiness functions are defined.
alter table public.profiles
  add column if not exists date_of_birth date;
