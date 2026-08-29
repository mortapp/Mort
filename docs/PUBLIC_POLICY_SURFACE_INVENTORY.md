# MORT Public Policy Surface Inventory

Audit date: 2026-08-29. This inventories every place legal/policy copy (privacy, deletion, child safety, terms, community guidelines, safety) exists in the repo, which one is canonical, and what's stale.

## Surfaces found

### 1. Public web legal/support site (canonical source for public-facing policy copy)
```
PATH=scripts/build-public-legal-site.mjs (generator) -> web/public/ (build output)
PUBLIC_OR_INTERNAL=PUBLIC (once deployed)
URL=NONE currently -- the build script generates netlify.toml and vercel.json so it CAN be deployed to either platform, but there is no evidence in the repo of an actual live deployment (no configured custom domain, no Netlify/Vercel project reference found). The CI job (public-site in .github/workflows/mort-ci.yml) only builds and validates the package as an artifact-free check step -- it does not deploy anywhere.
SHIPPING=NO (built and validated in CI, not deployed)
STALE=PARTIALLY -- the copy explicitly and consistently self-identifies as "MORT is a controlled 13+ pilot" / "restricted MORT closed-pilot service" / "Closed pilot" badge in the header (line ~152) / "Users must be at least 13... Downloading MORT does not grant marketplace eligibility." This is exactly the closed-pilot identity language the parallel Codex work is purging from user-facing app copy -- this public site is a second, separate surface with the same problem and is NOT in Codex's stated scope (Codex's assignment is "shipping Flutter/UI/web/copy surfaces" which likely DOES include this file -- flag for Codex or a follow-up pass since it wasn't in Codex's inventory as of this audit).
SOURCE_OF_TRUTH=YES -- this is the only complete, real, specific policy content found anywhere in the repo (see comparison to docs/legal-research/ below). Privacy, Terms, Terms of Use, Community Guidelines, Safety Center, Child Safety Standards, Prohibited Jobs, Payment Disputes, Support, Contact, and Accessibility pages all have real, specific, non-placeholder body content already written.
ACTION=Update the closed-pilot framing throughout (10 routes: /, /privacy/, /terms/, /terms-of-use/, /community-guidelines/, /safety/, /child-safety-standards/, /prohibited-jobs/, /payment-disputes/, /support/, /contact/, /accessibility/, /account-deletion/) to public-production framing once Codex's purge or a follow-up pass reaches this file. Requires OWNER_ACTION to actually deploy it somewhere with a real domain and set the required env vars (see below) before it can serve as the real public Privacy/Deletion/Child-Safety URL Play Console needs.
```

Required env vars for a real deployment (from the generator): `MORT_PUBLIC_PUBLISHER_NAME`, `MORT_PUBLIC_SUPPORT_EMAIL`, `MORT_PUBLIC_PRIVACY_EMAIL`, `MORT_PUBLIC_CHILD_SAFETY_EMAIL`, `MORT_PUBLIC_WEBSITE_URL`, `MORT_PUBLIC_EFFECTIVE_DATE`. None of these are set in `.github/workflows/mort-ci.yml`, so the CI-built artifact currently renders "pending - deployment blocked" placeholders in the footer/publisher fields (body content is unaffected). The generator also writes a `release-status.json` with `legalApprovalClaimed: false, publicDeploymentClaimed: false` hardcoded -- the package is self-aware that it is not yet an authorized public release.

**Correction (2026-08-29, verified live):** the git history of `web/public/` shows this package *was* previously built locally with real values (`MORT_PUBLIC_WEBSITE_URL=https://mort-web.vercel.app`, publisher "MORT", contact `mortapp@googlegroups.com`, effective 2026-08-19, `deploymentReady: true`) and that build was committed. `https://mort-web.vercel.app` **is live** -- but it serves a different, separate marketing/landing page (not this generator's output), and its own footer "Privacy policy" link 404s. So this generator's Privacy/Terms/Child-Safety/Deletion pages are still not actually reachable at any real URL today, live domain or not. The committed `deploymentReady: true` state was stale/inaccurate; this session rebuilt the package with honest "pending" placeholders rather than restoring that stale claim. `OWNER_ACTION_REQUIRED`: either deploy this package's routes under `mort-web.vercel.app` (e.g. as a subpath the marketing site links to) or a dedicated legal subdomain, and fix the marketing site's dead Privacy Policy link once a real target exists.

### 2. In-app account deletion entry point
```
PATH=flutter_mort/lib/features/settings/account_management_screens.dart, flutter_mort/lib/data/repositories/account_deletion_repository.dart
PUBLIC_OR_INTERNAL=INTERNAL (in-app UI, not a public URL)
URL=N/A (app screen, reached via Settings -> Account -> Delete account per the public site's own copy: "Open Settings, Account, then Delete account.")
SHIPPING=YES -- this screen exists in the current codebase and calls the real `request_account_deletion` RPC (same one the public web page's account-deletion.js calls)
STALE=NOT CHECKED (out of scope for this audit pass -- did not read full screen copy for closed-pilot language; flag for Codex's copy pass)
SOURCE_OF_TRUTH=this is the primary path; the public web page (`/account-deletion/`) is an explicitly secondary path for users who can't/won't reinstall the app, using a magic-link sign-in flow
ACTION=none required for this inventory; cross-reference ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md for backend correctness (see the RESTRICT-constraint finding noted in PRODUCTION_DATA_FLOW_MAP.md)
```

### 3. Web account-deletion self-service flow
```
PATH=scripts/build-public-legal-site.mjs (embedded, lines ~235-306: deletionBody HTML + assets/account-deletion.js)
PUBLIC_OR_INTERNAL=PUBLIC (once deployed)
URL=NONE currently (see surface 1)
SHIPPING=NO (not deployed)
STALE=NO -- this specific flow's copy is already framed generically ("Delete your MORT account") without closed-pilot language
SOURCE_OF_TRUTH=YES for the web-based deletion UX specifically. Uses Supabase magic-link (OTP) sign-in against the SAME project (rakjydmgwwgtdislanbt) and calls the same `request_account_deletion` / `get_my_account_deletion_request` RPCs as the in-app flow -- there is one deletion backend, two front doors. Good design; no duplication of logic to reconcile.
ACTION=deploy alongside surface 1
```

### 4. Legal versioning tables (database, not copy) -- draft documents already loaded
```
PATH=supabase/migrations (legal_contract_payment_foundation.sql, legal_draft_catalog.sql, and related mort_0_9_3_legal_draft_catalog.sql)
PUBLIC_OR_INTERNAL=INTERNAL (database, backs the in-app legal acceptance flow)
URL=N/A
SHIPPING=YES (the tables and acceptance-gating logic are live -- this is what makes complete_my_onboarding_v2() fail closed with published_legal_acceptance_required today, per the Stage 1 continuation doc)
STALE=N/A
SOURCE_OF_TRUTH=YES for which documents exist and their approval state
ACTION=see "Legal versioning architecture summary" below
```

Verified via a live query against the local replica (`public.legal_documents`, `public.legal_document_versions`): every current document (`mort_acceptable_use_policy`, `mort_adult_poster_agreement`, `mort_business_account_agreement`, etc.) has `publication_status = 'draft_attorney_review'`. Content is referenced via `content_path`, pointing at files like `docs/legal/MORT_ACCEPTABLE_USE_POLICY.md` -- a **third** location for legal copy, distinct from both the public web site (surface 1) and any docs/ drafts (surface 5 below).

### 5. `docs/legal/` markdown drafts
```
PATH=docs/legal/*.md (referenced by legal_document_versions.content_path, e.g. docs/legal/MORT_ACCEPTABLE_USE_POLICY.md)
PUBLIC_OR_INTERNAL=INTERNAL (drafts, feeding the legal-acceptance system, not directly public)
URL=N/A
SHIPPING=NO (draft_attorney_review status)
STALE=NOT VERIFIED IN THIS PASS -- did not open every file; flag for the actual policy-writing work
SOURCE_OF_TRUTH=this is the canonical content source for the IN-APP legal-acceptance clickwrap flow (role agreements, acceptable use policy, etc.) -- a DIFFERENT set of documents than the public web site's Privacy/Terms/Child-Safety pages in surface 1. These two content sets serve different purposes (role-specific contractual agreements vs. general public policy pages) and should NOT be merged into one file; they should stay cross-linked instead.
ACTION=when the three canonical public policies (Privacy, Account/Data Deletion, Child Safety) are finalized, decide explicitly whether they live as new `docs/legal/*.md` entries feeding the versioned acceptance system (if re-acceptance/versioning matters for them) or purely as the public web site's static content (if they're informational, not something the user "accepts" per se). The current public site already has real Privacy/Child-Safety copy (surface 1) that is NOT wired into the legal_documents versioning system at all -- worth deciding if it should be.
```

### 6. `docs/legal-research/` corpus
```
PATH=docs/legal-research/MORT_LEGAL_CORPUS_INDEX.csv, .json
PUBLIC_OR_INTERNAL=INTERNAL
URL=N/A
SHIPPING=NO
STALE=UNVERIFIED (appears to be research/reference material, not drafted product copy -- contains what looks like a legal-research indexing exercise based on the filename; did not open in this pass)
SOURCE_OF_TRUTH=NO -- reference material only
ACTION=none needed for the policy-writing task; do not confuse with surfaces 1, 4, or 5
```

### 7. Historical/audit docs mentioning legal or pilot terms
```
PATH=docs/MORT_SUPREME_BASELINE_AUDIT.md, docs/MORT_SUPREME_PROGRESS_LEDGER.md, docs/MORT_SUPPORT_CHATBOT_*.md, and others
PUBLIC_OR_INTERNAL=INTERNAL
URL=N/A
SHIPPING=NO
STALE=YES, but INTENTIONALLY -- these are point-in-time historical/audit records. Per the continuation directive: "Historical migrations/audit docs may retain factual old references. Do not rewrite history just to make repository grep zero."
SOURCE_OF_TRUTH=NO
ACTION=none -- explicitly out of scope
```

## Legal versioning architecture summary

From `supabase/migrations/20260719050000_legal_contract_payment_foundation.sql` and related migrations (table names cited from the live schema, verified via `information_schema` on the local replica):

- **`public.legal_documents`**: one row per distinct policy/agreement (`document_key`, `title`, `document_category`, `publication_status`, `guardian_mode_independent`). `document_category` values seen: `conduct`, `role_agreement` -- i.e., documents are role/purpose-scoped, not just a flat list.
- **`public.legal_document_versions`**: one row per version of a document (`document_id` FK, `version_label`, `content_hash`, `content_path`, `effective_at`, `published_at`, `retired_at`, `material_revision` boolean, `requires_electronic_signature`, `publication_status`, `attorney_reviewed_at`, `approved_by_counsel_reference`). A version only becomes live once `publication_status` moves past `draft_attorney_review` and `published_at` is set -- both are currently null/draft for every document, which is the root cause of the Stage 1 `HOSTED_V2_FINISH_BLOCKER=LEGAL_POLICY_PUBLICATION` state.
- **`public.legal_role_requirements`**: maps which document a given `role` must accept (referenced by the compatibility-migration test's `legal_role_requirements` / `legal_acceptances` join pattern seen in `scripts/qa-onboarding-v2-legacy-compatibility-transaction.mjs`).
- **`public.legal_acceptances`**: the actual acceptance record (`user_id`, `role`, `age_band`, `document_id`, `document_version_id`, `content_hash`, `accepted_at`, `platform`, `app_version`, `affirmative_checkbox`, `active`, `withdrawn_at`/`withdrawal_reason`). The `content_hash` on the acceptance is compared against the version's hash -- so a version's content cannot silently change out from under an existing acceptance without the hash mismatch being detectable.
- **`public.legal_reacceptance_requirements`**: exists as its own table, implying re-acceptance after a material policy change is tracked explicitly, not inferred. A version's `material_revision` boolean is the likely trigger for populating this table (mechanism not traced line-by-line in this pass -- follow up when implementing the re-acceptance UX per the continuation directive's "Existing user reconsent" section).
- **`public.legal_declines`**: tracks explicit declines separately from silent non-acceptance.
- **`public.legal_acceptance_audit_events`**: an audit trail, `RESTRICT`-linked to profiles (part of the deletion-blocking finding cross-referenced in the data flow map -- being fixed to `SET NULL` in a separate migration).

**What determines re-acceptance**: a user must accept the specific `document_version_id` current at the time; if a new version is published with `material_revision = true` for a document the user already accepted an older version of, the `legal_reacceptance_requirements` mechanism is what should surface that gap (exact trigger/RPC not traced in this pass -- needs a dedicated read before implementing the "policy-update consent experience" the continuation directive calls for).

## Summary of the most important contradictions/gaps found

1. **No real public policy URL exists today.** The public web site (surface 1) is fully built and CI-validated but never deployed to a reachable path. A separate marketing site is genuinely live at `https://mort-web.vercel.app`, but its own Privacy Policy footer link 404s -- it does not serve this generator's content. Play Console needs a real, reachable HTTPS Privacy/Deletion/Child-Safety URL -- this is an `OWNER_ACTION_REQUIRED` (deploy target + the six `MORT_PUBLIC_*` env vars, most plausibly under the existing `mort-web.vercel.app` domain), not something fixable purely by writing better copy.
2. **The public web site's existing copy is already unusually good and specific** (ads restrictions, no-payment-processing framing, teen privacy carve-outs, CSAM handling instructions) -- the policy-writing task should extend/adapt this content rather than starting from scratch, and should NOT duplicate a second, different Privacy Policy elsewhere.
3. **The public web site still uses closed-pilot framing** ("Closed pilot" badge, "restricted 13+ pilot," "Downloading MORT does not grant marketplace eligibility") that needs the same treatment Codex is applying to the Flutter app -- but this file is not confirmed to be in Codex's actual working scope (it lives in `scripts/`, not `flutter_mort/lib`), so it may fall through the gap between "Claude's backend lane" and "Codex's UI lane." Flagged here per the continuation directive's instruction to record stale strings rather than fix them unilaterally.
4. **Google Sign-In is active in production today but not disclosed by name** in the drafted Privacy Policy -- a concrete, fixable gap once the policy is finalized.
5. **Three separate legal-content locations exist** (public web site copy, `docs/legal/*.md` versioned-acceptance drafts, and the `legal_documents`/`legal_document_versions` DB rows pointing at those files) serving two genuinely different purposes (public informational policy vs. role-specific accepted agreements) -- worth an explicit decision on whether the three canonical public policies get their own versioned-acceptance rows or stay purely static.
