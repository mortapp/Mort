# Known Issues and Release Blockers

## Existing completed-user compatibility is unresolved

After deployment, the v2 evaluator classified all 24 profiles with `onboarding_completed=true` as incomplete. Seven are non-test profiles. Their earliest v2 steps are based on actual persisted gaps: historical usernames, teen work preferences, or unavailable current legal acceptances.

This exposes a product/security contradiction: grandfathering historical server completion preserves existing access, while canonical revalidation sends historically completed users back to missing prerequisites. No compatibility override or user data mutation was improvised. A separately approved forward migration is required after choosing the intended rule.

## Migration parity is resolved

Seven local/hosted timestamp pairs were proven semantically equivalent and reconciled append-only using SQL no-op compatibility aliases. No hosted history row was reverted, deleted, renamed, or rewritten. After deploying the two genuine pending migrations, all 193 local timestamps match hosted history and the final dry run reports the database is up to date. See `MIGRATION_RECONCILIATION_2026-08-28.md`.

## Required public legal versions are unavailable

The hosted legal catalog currently has no effective published version for 10 required teen documents. The rollback-only completion test therefore returns `published_legal_acceptance_required`, as designed. No draft was marked published and no legal gate was bypassed.

Affected required document keys observed on August 28, 2026:

- `mort_teen_plain_language_terms`
- `mort_terms_of_service`
- `mort_terms_of_use`
- `mort_privacy_policy`
- `mort_community_guidelines`
- `mort_safety_rules`
- `mort_community_and_safety_rules`
- `mort_prohibited_work_policy`
- `mort_marketplace_risk_disclosure`
- `mort_closed_pilot_rules`

Publication requires the existing legal approval workflow. This implementation does not invent copy, approval, counsel references, or publication status.

## Verification still required

- Resolve completed-user compatibility with an approved forward migration.
- Rerun the hosted PostgREST hostile-client and concurrency suite. Its first deployed run stopped at the unavailable-legal-version Finish gate.
- Complete physical Android QA on the supported Samsung target and record evidence.
- Do not publish a production build while either release blocker remains.
