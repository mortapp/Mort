# Codex Production Identity Purge Handoff

START_TIME=2026-08-28 21:19:50 -0400

BASE_BRANCH=origin/feature/compact-onboarding-and-screen-polish

BASE_COMMIT=cebcc426d1d100cabbe099c656e7254af5db2b87

CODEX_BRANCH=codex/production-identity-purge

CODEX_WORKTREE=C:\Users\micha\Mort\.worktrees\codex-production-identity-purge

CLAUDE_ACTIVE_BRANCH=feature/compact-onboarding-and-screen-polish

CLAUDE_WORKSPACE_TOUCHED=NO

## Scope completed

FLUTTER_COPY_PURGED=YES — 20 Flutter production-source files plus three
affected tests. The product label, onboarding/legacy onboarding presentation,
account status, Discover/jobs, safety, Guardian/partner, settings, verification,
feature-unavailable, and monetization-disabled presentation are production
neutral and still fail closed.

WEB_COPY_PURGED=YES — the public legal/support generator and all 13 generated
routes use MORT product identity. Existing public publisher/contact values were
preserved. The pages explicitly remain draft and pending qualified legal
review.

PUBLIC_METADATA_PURGED=YES — Play short description, full description, release
notes, generator source blocks, reviewer identity check, testing plan identity
check, tester onboarding check, and store-asset positioning were corrected.

ASSET_COPY_PURGED=NOT_APPLICABLE — no shipping binary/text asset contained the
forbidden identity; the store feature-graphic brief was corrected.

LOCALIZATION_PURGED=NOT_APPLICABLE — no shipping ARB/localization occurrence
required a change.

TEMPLATES_PURGED=NOT_APPLICABLE — no shipping transactional email/push template
occurrence was found.

OBSOLETE_PILOT_COMPONENTS_REMOVED=0 — useful components were retained and given
neutral product presentation; internal routes and server contracts were not
renamed.

PRODUCTION_COPY_TEST=`pnpm qa:production-identity-copy` / `node
scripts/qa-production-identity-copy.mjs`; PASS across 190 files with a zero-entry
allowlist. It scans shipping Flutter presentation, public web/policy source and
generated routes, production assets/localization roots, Expo presentation roots,
and the public Play metadata outputs/source blocks.

## Security and product invariants

MARKETPLACE_ACTIVATION_CHANGED=NO

PAYMENTS_ACTIVATED=NO

REVENUECAT_CONFIGURATION_CHANGED=NO

RLS_CHANGED=NO

HOSTED_SUPABASE_CHANGED=NO

LEGAL_VERSION_CHANGED=NO

PLAY_CONSOLE_CHANGED=NO

PRODUCTION_PUBLISHED=NO

Internal values including `closed_test`, `closed_pilot`, the immutable
acknowledgement version, Google Play track documentation, and deployed RPC/route
names remain where required for compatibility, security, and audit evidence.
They are not rendered as normal-user product identity.

## Verification evidence

- Initial copy-contract RED: 87 forbidden shipping occurrences.
- Final copy contract: PASS, 190 files, zero forbidden occurrences.
- `flutter analyze`: PASS, no issues.
- Focused Flutter tests: PASS, 25 tests.
- Full `flutter test`: PASS, 424 tests; 2 pre-existing intentional skips.
- Public site build: PASS, 13 routes, using the exact already-committed public
  metadata values; no deployment was performed.
- Public site validator: PASS, 13 routes.
- Visual QA: PASS on the public home and Terms pages at desktop and 390×844;
  no horizontal overflow and no forbidden identity in rendered text.
- `git diff --check`: PASS (Git reports only line-ending conversion notices on
  regenerated web support files).

## Files intentionally not touched due to Claude / audit ownership

- `supabase/**`, hosted flags, RLS, migrations, legal acceptance/version rows,
  and backend verification work.
- `.github/workflows/**`; Claude owns CI repair. Integration should add the one
  command `pnpm qa:production-identity-copy` to the canonical required CI job.
- Applied migration history, archived evidence, and historical operational
  records describing Google Play closed testing.
- Claude's continuation/progress documents and active checkout.

POLICY_HANDOFF_ITEMS=NONE — presentation changes were limited to the public-site
generator/shell and did not change legal versions or claim approval. Preserve
both Claude's policy substance and this production presentation during merge.

CI_HANDOFF_ITEMS=Add `pnpm qa:production-identity-copy` to the canonical CI job
after Claude's workflow repair lands; do not duplicate workflow rewrites.

## Potential conflicts and integration

POTENTIAL_CONFLICTS=Flutter onboarding/account-status files and
`scripts/build-public-legal-site.mjs` may overlap if Claude changed them after
base commit `cebcc42`. Resolve semantically: keep Claude's server/security/legal
work and retain the production-neutral strings plus the copy contract.

INTEGRATION_INSTRUCTIONS=Fetch `codex/production-identity-purge`, compare it to
the latest pushed integration tip, then cherry-pick the coherent commits or
merge the branch in a clean integration worktree. Do not choose ours/theirs for
overlapping backend-aware UI files wholesale. Run the copy contract, public
site validator, `flutter analyze`, and full Flutter tests after resolution.
