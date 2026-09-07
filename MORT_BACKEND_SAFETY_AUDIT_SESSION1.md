# MORT Backend/Safety Audit — Session 1 (targeted, evidence-based)

Scope note: this is a **targeted audit of the highest-risk areas** the task specification
calls out first (RLS coverage, webhook auth, evidence/vault access, blocked-user
enforcement), not an exhaustive line-by-line review of all 195 migrations, all edge
functions, and all Flutter repository code. No P0/P1 issues were found in the areas
sampled below. Areas not yet reviewed are listed explicitly at the end — they are
NOT claimed as complete.

## 1. RLS coverage (public schema)

A static grep for `CREATE TABLE` vs. explicit `ALTER TABLE ... ENABLE ROW LEVEL
SECURITY` initially flagged 63 "tables without RLS." On inspection, this was a false
positive from a naive regex: `supabase/migrations/20260719050200_legal_contract_trust_rls.sql`
enables RLS on 40 of those tables via a single `do $$ ... foreach table_name in array [...]
loop execute format('alter table public.%I enable row level security', ...) $$` block —
verified the array literally lists every flagged `public.*` table (legal_*, job_contract*,
payment_dispute*, completion_evidence_records, document_capture_*, live_presence_*,
appearance_review_*, team_*). **Verdict: no real gap in `public` schema RLS coverage
among the tables sampled.**

## 2. `private` schema tables (identity/Stripe internals)

The remaining flagged tables (`private.stripe_*`, `private.identity_verification_*`,
`private.production_identity_reviewers`, etc.) mostly lack an explicit RLS-enable
statement, but `supabase/config.toml` only exposes `schemas = ["public", "storage",
"graphql_public"]` to PostgREST — `private` is not reachable via the API at all.
`revoke all on schema private from public, anon` is applied, and `grant usage on schema
private to authenticated, service_role` is scoped to specific `SECURITY DEFINER`
functions only (verified via grep of `grant execute on function private.*`). This is a
legitimate, common defense pattern (schema-level exposure control) rather than a bug.

**Recommendation (P2, not blocking):** add `ENABLE ROW LEVEL SECURITY` +
`FORCE ROW LEVEL SECURITY` to the `private.*` tables anyway as defense-in-depth against
a future SECURITY DEFINER bug or accidental schema exposure change. Not done in this
session — flagging for a follow-up hardening pass rather than doing it blind without
the fuller context of every affected function.

## 3. Webhook signature/authorization verification

Checked all four external webhook handlers in `supabase/functions/`:

- `stripe-webhook`: requires `Stripe-Signature` header, verified via
  `stripe.webhooks.constructEventAsync(rawBody, signature, webhookSecret)`. Rejects
  with 401 if the header is missing. Correct.
- `revenuecat-webhook`: requires a shared-secret `Authorization` header compared with
  `constantTimeEqual` (timing-attack-resistant). Rejects with 401 on mismatch. Correct.
- `identity-verification-webhook`: requires `IDENTITY_VERIFICATION_WEBHOOK_SECRET`,
  returns 401 on `signature_missing`/`signature_invalid`. Correct.
- `google-play-rtdn`: does not itself verify a webhook signature, but treats the RTDN
  payload only as a trigger to re-verify the purchase directly against Google's
  Play Developer API (`verifyWithGoogle`) using a server-side lookup by token hash —
  so a spoofed RTDN call cannot forge purchase state, only trigger a redundant
  (harmless) re-check. Correct pattern, different mechanism.

**Verdict: no webhook spoofing gap found in the four checked.**

## 4. Evidence/document vault access (`document-vault-access`, `support-evidence-url`)

`document-vault-access/index.ts` implements a grant-based flow: Bearer-token auth →
fail-closed operational-readiness check → payload validation (UUIDs, action enum,
mandatory ≥12-char audit reason) → `request_document_vault_access` RPC as the
*user* (RLS-scoped authorization) → `consume_document_vault_access_grant` RPC as
service role (single-use grant, cross-checks `reviewer_id`/`case_id` match) →
signed URL capped at **60 seconds**, scoped to the exact bucket/path from the grant →
delivery outcome recorded for audit. `support-evidence-url` uses a 300-second signed
URL behind its own authorization check. **Verdict: well-architected, no IDOR found.**

## 5. Blocked-user enforcement in messaging

Initially looked like a possible gap: `public.send_safe_message_v2` (the newer,
idempotent/rate-limited RPC used by the client) delegates to `public.send_safe_message`
for the actual insert, and doesn't itself reference `public.blocks`. Traced further:
`public.send_safe_message` (redefined in `20260717161132_mutual_trust_real_world_safety.sql`,
the latest `create or replace`) checks `public.users_are_blocked(auth.uid(), <thread
counterpart>)` for teen/adult/guardian and raises before allowing the send. Blocking is
also enforced at the job/application layer in
`20260819000000_job_site_precise_location_and_distance.sql` (blocks precise-location
sharing between a blocked poster/teen pair). **Verdict: block enforcement is real and
layered, not just a table with no consumer.**

## Not yet reviewed this session (explicitly open, not claimed complete)

- Financial Safety ledger integrity (earnings/expense/export determinism)
- Payment dispute state machine end-to-end (creation → evidence → decision → payout adjustment)
- Identity verification provider abstraction states (pending/expired/rejected handling)
- Guardian↔teen linking/unlinking permission boundaries beyond the grep-level scan
- Moderation/staff role escalation and reversal flows
- Storage bucket policies for every bucket (only vault/evidence buckets sampled)
- Full RLS *policy predicate* correctness (existence of RLS was checked; the logic
  inside every policy across all 195 migrations was not individually re-derived)
- Flutter-side repository code paths that call these RPCs (only the backend was audited)
- Any of the 195 migrations not touched by the greps above

## Recommendation

Treat this as Session 1 of the backend/safety audit. No internal blockers found in the
areas covered. Continue with Financial Safety and payment-dispute lifecycle next, since
those are the other explicitly highest-priority areas (money + evidence) not yet sampled.
