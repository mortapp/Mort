# MORT monetization RPC response repair — 2026-10-05

Status: client fix verified; updated packaging awaits unused version-code confirmation.

## Defect and fix

`get_my_entitlements()` and `get_ad_eligibility()` return SQL tables. PostgREST
normally serializes these as arrays, while `MonetizationRepository` cast the
result directly to a map. A synthetic loopback HTTP regression reproduced
`List<dynamic> is not a subtype of Map<dynamic, dynamic>` in both methods.

Both calls now use the installed Supabase SDK's `.single()` transform to
request one authoritative object. Missing rows produce a `PostgrestException`;
they do not generate local entitlements or an allowed ad decision. Existing
ad eligibility error handling continues to fail closed.

The test fixture honors PostgREST's object Accept header and its zero-row 406
response, exercises the real SDK and repository, and never contacts hosted
Supabase. Three regression tests cover valid entitlement rows, valid ad
decisions, and missing authoritative rows. No new dependencies were added.

## Scope and release

The paywall layout, Continue with Free, store prices, SKU mapping, auth
architecture, role hierarchy and purchase authority are unchanged. Ads remain
disabled in the closed-test profile; Stripe live marketplace and production
rollout remain disabled. No emulator or provider purchase was performed.

Signed build 115 from `9c1721c` is preserved, including an archive and symbols,
and does not include this subsequent client fix. The owner must confirm that
115 is still unused after delivery, or identify the next unused Play code,
before updated packaging. Build 114 remains unchanged.

## Verification and sequential review

- Full Flutter analysis: **zero issues**. Its first run found one test-fixture
  style hint; after the correction the complete analyzer passed.
- Full Flutter regression: **798 passed, zero failed, two skipped**. The suite
  includes Android/iOS parity and monetization/free-dismissal contracts. The
  final three RPC tests also passed after the fixture formatting correction.
- Dart formatting and diff whitespace checks: PASS.
- Changed-source secret snapshot: **16 files, zero findings**; the earlier
  repository/generated scan checked 16,186 files with zero findings. No
  privileged names or keys were introduced into the client.
- Believer: both real SDK calls decode server rows and reject missing rows.
- Skeptic: zero-row responses raise provider errors; no response fallback
  fabricates a premium tier or an allowed ad decision.
- Investor/operations: no subscription catalog, prices, ad activation, paid
  visibility or live marketplace changes are part of this repair.
- Judge: source repair verified; updated binary/device/provider certification
  is not implied. Native packaging waits for the owner's unused code confirmation.

Backend defect evidence is in
[the continuation report](MORT_CONTINUATION_2026-10-05.md). Verification logs are
under `C:\Users\micha\Mort\reports\completion-2026-10-05`.
