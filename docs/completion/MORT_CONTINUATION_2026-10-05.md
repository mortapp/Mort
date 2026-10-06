# MORT continuation evidence — 2026-10-05

Status: backend fixes verified locally; full product/provider certification remains blocked.
Worktree: `release/mort-post-114-integration`. No hosted deployment, public merge,
Play upload, emulator, or production rollout occurred.

## Build 115 remains preserved

Signed `0.9.16+115` artifacts were previously built from
`9c1721c713b472f884ab78133bfe3e7605b0b956` and are present under
`C:\Users\micha\Mort\build\play`. Their hashes were checked again in this pass:

| Artifact | SHA-256 |
| --- | --- |
| `mort-closed-test-0.9.16-115.aab` | `036EC149B4299219B26EDE4AF31F332F3C82CAF7883FB8644856D16C3D2207D2` |
| `mort-closed-test-0.9.16-115.apk` | `7B5FBA4A82BE67959006B62CEEAA3014434580547C217C8448E00619184B45C1` |

Both artifacts remain the existing signed, Play-billing-enabled closed-test
candidate. Their signing, 16 KB alignment, analyzer and 795-pass Flutter
evidence belongs to that build's source commit. This pass changes backend SQL,
QA and documentation; the Flutter tree has no diff from that commit. No new
APK/AAB was generated, and build 114 remains unchanged. New backend migrations
are **local only**, so these fixes are not claimed to be deployed to either
build's hosted backend.

## Reproduced and repaired

1. **Entitlement expiry without a webhook.** `get_my_entitlements()` returned
   cached `mort_pro` after its product expired. Cached ad flags and monthly
   username allowances also ignored expiration. New additive migration
   `20261005120000` resolves each active product independently at read time and
   reuses that caller-scoped reader in entitlement, ad and username RPCs. It
   preserves lifetime and active Plus, and grants Pro its inherited Plus
   username allowance. Cache-only historical accounts retain their existing
   grant until its recorded expiry; known revoked product history cannot fall
   back to a stale cache. Raw cache tables remain provider audit snapshots.
2. **MORT Verify decision-source mismatch.** A synthetic sandbox session failed
   with SQLSTATE `23514`: the old identity constraint rejected the first-party
   writer's `mort_verify_pending`. Migration `20261005123000` accepts the two
   existing first-party writer labels only for provider `mort_verify` and
   prevents a pending label from becoming verified. The independent production
   identity-source constraint is retained. It still rejects first-party
   production verification; production approval/policy alignment is an external
   gate, not silently relaxed here.
3. **MORT Verify hash resolution.** After the constraint repair, the same test
   failed with SQLSTATE `42883` because an empty search path could not resolve
   `digest`. Migration `20261005124500` qualifies `extensions.digest` in the
   session function and retired raw-code verifier. Existing empty search paths
   and execution grants are preserved. The retired verifier remains inaccessible
   to authenticated clients; the service-only HMAC path remains authoritative.
4. **QA job fixture rejection.** The username/boost test used “isolated” in its
   work description, correctly triggering pilot safety rejection. Two QA
   descriptions now specify staffed public-library work and assert the job is
   eligible before testing boost credits. No safety filter was weakened.
5. **QA username generation and error cleanup.** The committed-head rerun
   exposed a failing generated username request; its cleanup hid the underlying
   error with an aborted-transaction error. UUID-based usernames could contain
   phone-like digit runs prohibited by the actual safety validator. The fixture
   now uses a safe alphabet and its authenticated RPC wrapper rolls back a
   savepoint before resetting role, retaining the original failure diagnostic.

## Verification

Nine local suites passed: entitlement expiry, RevenueCat tier lifecycle,
RevenueCat atomic fulfillment, entitlement forgery, Pro/ad SSV, username
credits, monetization RLS, MORT Verify hashing, and provider-neutral identity.
The new expiry and hashing regressions are included in the local CI regression
runner. Both create synthetic accounts and roll back the sensitive transaction
before removing only their own fixtures.

Additional checks: public-schema database lint **zero errors**, teen verification
security contracts **PASS**, 269 SQL migration encoding checks **PASS**, migration
reconciliation **PASS**, JavaScript/PowerShell syntax **PASS**, and diff whitespace
checks **PASS**. Source secret-scan result and committed-head rerun are recorded
in the companion report under `C:\Users\micha\Mort\reports\completion-2026-10-05`.
Flutter tests were not repeated in this backend-only pass; unchanged client
evidence is linked to the build commit above.

## Sequential review

- Believer: read-time expiry, Plus/Pro inheritance, lifetime preservation and
  sandbox session startup are proven by actual local RPC calls.
- Skeptic: tests deliberately retain stale cache flags, expire Pro while Plus
  or a lifetime add-on remains, attempt cross-account reads and invalid identity
  transitions, and verify client grant denial. Cache-only legacy provenance and
  hosted/provider state still require external review.
- Investor/operations: no prices, SKUs, store catalog or paid visibility were
  activated. Real purchases, identity evidence and settlement remain separate
  provider/operations gates.
- Judge: these local backend defects are repaired. The complete Free/Plus/Pro
  launch is not certified, and no deployment/production approval is implied.

## Remaining gates

- Approve distinct Plus store products/offering/prices and audit historical
  `mort_plus_*` customers. Plus configuration stays empty; no fake products.
- Finish the dependent Plus checkout/comparison/upgrade UX and real adult
  convenience tools before marketing those benefits.
- Review/apply hosted migrations in an approved deployment window, including
  first-party identity policy alignment before any production verification.
- Obtain licensed physical Play purchase, restore, renewal, expiration,
  refund/revocation and tier-change evidence; build 114's sheet launch/cancel,
  store pricing and Continue with Free evidence remains the verified scope.
- Physical build 115 navigation/layout, iOS signing/device gates, legal and
  operational approvals. Stripe live marketplace remains disabled.
