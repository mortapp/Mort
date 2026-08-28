# Known Issues and Release Blockers

## Database migration history is divergent

The linked hosted project and repository disagree on migration history beginning August 17, 2026. There are both local-only migrations and remote-only versions, including remote-only `20260818233800`, `20260819003851`, `20260819004344`, `20260819004628`, `20260819025837`, `20260820113638`, and `20260820122024`.

`20260828023033_four_step_onboarding_v2.sql` has therefore not been pushed. No history repair, reset, or destructive reconciliation was attempted. Resolve parity from authoritative migration artifacts before a normal forward-only deployment.

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

- Run the hosted PostgREST hostile-client and concurrency suite after a safe migration deployment.
- Complete physical Android QA on the supported Samsung target and record evidence.
- Do not publish a production build while either release blocker above remains.
