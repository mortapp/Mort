# Production onboarding: confirmed pending accounts and legal acceptance

Status: the narrow migration is now applied to the production Supabase project `jxbnrkasktbhtiujkhay` and recorded in migration history as `20261031220518_allow_confirmed_pending_legal_acceptance`. The migration source is `supabase/migrations/20261031220518_allow_confirmed_pending_legal_acceptance.sql`.

## Production issue verified against Supabase project `jxbnrkasktbhtiujkhay`

New Auth users receive a `profiles` row with `account_status = 'pending'`. The production onboarding v2 account RPC records the age-derived role and `date_of_birth`, but it intentionally does not activate the account.

Two legal RPCs currently require `account_status = 'active'`:

- `public.get_my_legal_requirements()`
- `public.submit_legal_acceptance(...)`

That creates a deadlock for a new email-confirmed account: it can save the account, work, and safety steps, but cannot retrieve or accept the published legal versions required by `public.complete_my_onboarding_v2(...)`.

The website must not solve this by setting `account_status = 'active'` or by writing `onboarding_completed_at` directly.

## Narrow permanent backend change

Update only the actor eligibility predicate in both legal RPCs.

Allow an actor when either:

1. `profiles.account_status = 'active'`; or
2. `profiles.account_status = 'pending'` **and** the matching `auth.users.email_confirmed_at` is not null.

In both cases, continue to require:

- `profiles.id = auth.uid()`
- a non-null, non-`pending` role
- an eligible server-derived age band
- current published document versions and role/age requirements
- explicit affirmative acceptance, teen-summary acknowledgement when applicable, and an electronic signature when the published version requires one

The pending-account exception must be based on `auth.users.email_confirmed_at`, never `user_metadata`, client form values, or a client-supplied confirmation flag. The functions are already `SECURITY DEFINER` with an empty search path; any replacement must preserve that posture and fully qualify referenced objects.

### Predicate shape

Use the equivalent of this condition in the `get_my_legal_requirements` actor CTE:

```sql
and (
  profile.account_status = 'active'
  or (
    profile.account_status = 'pending'
    and exists (
      select 1
      from auth.users auth_user
      where auth_user.id = profile.id
        and auth_user.email_confirmed_at is not null
    )
  )
)
```

Use the same condition in the `submit_legal_acceptance` actor lookup, with `v_actor` remaining the row returned from `public.profiles`.

Do not broaden the exception to suspended, deleted, banned, or otherwise restricted accounts.

## Preserve the existing completion boundary

Do not change `public.complete_my_onboarding_v2` to activate accounts. It should continue to:

1. Require the four server-defined onboarding steps.
2. Require current legal acceptance rows through `private.mort_user_has_current_legal_acceptances`.
3. Set only the onboarding completion field (`onboarding_completed_at`) through its existing server-side transaction.
4. Leave `profiles.account_status` unchanged.

The website must call `public.submit_legal_acceptance` separately for each required current version before calling `complete_my_onboarding_v2`; the live completion RPC checks those records but does not create them itself.

A completed account can therefore remain pending. Marketplace, publishing, verification, and payment access must continue to be controlled by their separate production gates.

## Website integration contract

The production website must:

- bootstrap profiles only with `public.ensure_my_profile()`
- read progress with `public.get_my_onboarding_progress_v2()`
- save steps with `save_my_onboarding_account_v2`, `save_my_onboarding_work_v2`, and `save_my_onboarding_safety_v2`
- finish through `complete_my_onboarding_v2`
- load legal versions only when `publication_status = 'published'`
- display the exact `content_markdown` and server-provided content hash for each required version
- require an affirmative checkbox per outstanding required version
- supply teen-summary acknowledgement and signature text when required
- never write profile role, DOB, account status, or onboarding completion directly

Role-protected website dashboards must also reject non-admin accounts unless `account_status = 'active'`. Completing onboarding is not an account activation event.

## Validation after production application

Before relying on this change for live onboarding, complete these checks against a confirmed pending account with an eligible role and DOB. The production project currently has two confirmed pending profiles whose role is still `pending`, so neither can yet be used to test legal acceptance. A rollback-only SQL test that temporarily set a profile role/DOB was blocked by safety controls; no user profile was modified. The live function-definition checks passed, confirming both RPCs require a confirmed Auth email and permit `pending` status. The migration's transactional syntax check also passed before application.

| Account state | Legal requirements | Acceptance RPC |
| --- | --- | --- |
| Pending, email unconfirmed | Denied | Denied |
| Pending, email confirmed, eligible role/age | Allowed by the new gate (full user-flow test still required) | Allowed by the new gate (full user-flow test still required) |
| Active, eligible role/age | Allowed | Allowed |
| Suspended, even if email confirmed | Denied | Denied |
| Pending with role `pending` | Denied | Denied |
| Pending with ineligible/unknown age band | Denied | Denied |

Also verify that successful legal acceptance leaves `account_status = 'pending'`, and that `complete_my_onboarding_v2` leaves marketplace and publishing controls unchanged.

## Explicit non-goals

- No legacy `dob`, `state`, or `onboarding_completed` profile columns.
- No role-specific profile tables.
- No direct client writes to `profiles`.
- No client-side account activation.
- No automatic Guardian connection or default Guardian access.
- No marketplace, job publishing, payments, Stripe, identity, or release-control activation.
- No activation of marketplace, publishing, payments, or verification as part of this migration.
