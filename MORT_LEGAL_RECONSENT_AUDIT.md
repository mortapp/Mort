# MORT Legal / Re-consent Flow Audit

Audits the actual app implementation (client + backend RPCs), not just the public
legal site build already verified in the baseline.

## What was verified sound, no change needed

- **Legal version storage & exact-hash acceptance**: `legal_document_versions` stores
  a `content_hash`; `submit_legal_acceptance()` (`supabase/migrations/20260719050300_
  legal_contract_payment_rpcs.sql:82`) independently re-derives `v_version.content_hash`
  from the server row — the client cannot influence what hash gets recorded, so
  acceptance is cryptographically bound to server-side content, not whatever the
  client happened to render.
- **Server-authoritative version validity**: the RPC re-checks `publication_status =
  'published'` and `effective_at <= now()` itself; a client cannot force-accept a
  draft or a not-yet-effective version even if it somehow got the ID.
- **Role/age-specific requirements**: `get_my_legal_requirements()` joins
  `legal_role_requirements` on `(role, age_band)`, so a teen only sees the documents
  actually required for their role/age band, not an adult's requirement set.
- **No inferred acceptance**: `LegalCenterScreen`'s subtitle and `get_my_
  legal_requirements()`'s own `acceptance_inferred_from_browsing: false` field both
  make this explicit; the clickwrap screen requires two independent checkboxes (teen
  summary reviewed, affirmative agreement) plus an electronic signature when the
  version demands one, and the server independently re-checks the teen-summary-viewed
  requirement for teen accounts specifically.
- **Reacceptance-after-revision is tracked**: `private.queue_legal_reacceptance()` is
  a trigger that fires automatically when a document version is published with
  `material_revision = true`, creating `legal_reacceptance_requirements` rows.
  Independently, `get_my_legal_requirements()`'s own join logic re-surfaces a document
  as outstanding (`acceptance_id = null`) the moment a *newer* published version
  exists, even without the trigger — two independent mechanisms agree, not just one.
- **Decline handling distinguishes required vs. optional**: `decline_legal_document()`
  looks up whether the document is required for the caller's role/age-band and returns
  `optional_document` in its response, so the client can tell whether a decline should
  block anything or not.
- **Draft status honesty**: every legal document in the current catalog
  (`20260719050500_legal_draft_catalog.sql`) is `publication_status =
  'draft_attorney_review'`, and both `LegalCenterScreen` and `LegalClickwrapScreen`
  render an explicit, unmissable "DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED"
  banner. No legal-approval claim is made anywhere in the client.
- **Banned/deleted account interaction**: `routeAuthenticatedProfile` (Session 3 audit)
  routes suspended/deletion-pending accounts away from the app shell *before* the
  `authenticated` stage is ever reached, so the new reacceptance-prompt logic (below)
  cannot fire for them — no conflict between the two gates.
- **Public site vs. in-app consistency**: the public site covers the core consumer-
  facing categories (terms, terms-of-use, privacy, community guidelines, safety,
  child-safety standards, prohibited jobs, payment disputes, account deletion,
  accessibility, contact, support — 13 routes). The in-app draft catalog additionally
  includes narrower contextual disclosures (Face ID, liveness check, insurance,
  business-account agreement, adult-poster agreement) that are more naturally
  surfaced at the point of the relevant in-app flow than as standalone public pages.
  This is an architecturally reasonable split, not spot-checked page-by-page for
  wording parity (would require attorney-level textual comparison, out of scope for
  an engineering audit).

## Real gap found and fixed

**Nothing prompted an already-onboarded user to actually re-accept a materially
revised required document.** `legal_reacceptance_requirements` rows were created
correctly server-side, and `LegalCenterScreen` would correctly show them if opened —
but no code path ever navigated a user there. `routeAuthenticatedProfile`
(`auth_startup.dart`) only checks `account_status`/`role`/`onboarding_completed`, and
no marketplace action RPC (job creation, application, messaging, etc.) gates on
outstanding legal acceptance either — only onboarding-completion did (a one-time,
first-run check). A user who never happened to open the Legal Center on their own
could keep using every other feature indefinitely without ever seeing a revised Terms/
Privacy/Safety document.

**Fix** (commits below): added `pendingRequiredLegalReacceptanceProvider`
(`lib/data/repositories/providers.dart`) — calls the existing `get_my_legal_
requirements()` RPC and reports whether any *required* document has a null
`acceptance_id`; fails open (`false`) on any error so a network hiccup can never block
startup. Wired into `lib/app.dart` using the **exact same one-shot redirect pattern**
already used for the `suspended`/`deletionPending`/`onboarding` stages (watch, redirect
once via `router.go('/legal-center')`, dedupe by `userId` so it fires once per session
and correctly re-evaluates if a different user signs in on the same app instance) —
deliberately not touched: `AuthStartupController`'s existing retry/timeout state
machine, to avoid introducing risk into that already-delicate, heavily-relied-on code
path. This is a UX nudge consistent with how this codebase treats every other
account-state condition (client redirects once; the real enforcement boundary for
security-relevant states is backend RLS) — it is not a hard blocking gate, since no
other action in this codebase is backend-gated on legal acceptance outside of
onboarding completion either, and matching that established pattern was judged safer
than introducing a new, first-of-its-kind hard-blocking mechanism this deep into
startup.

Added `test/pending_legal_reacceptance_test.dart` (4 cases: outstanding required flags
true, already-accepted required flags false, outstanding-but-optional flags false,
thrown error fails open to false) — all pass. Full regression: see commit for count.

## Verdict

LEGAL_IMPLEMENTATION_P0=0, LEGAL_IMPLEMENTATION_P1=0 (after the fix above).
