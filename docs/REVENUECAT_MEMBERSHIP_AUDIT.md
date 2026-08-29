# RevenueCat / Membership Audit — 2026-08-29

## Verdict: backend is production-grade and complete; the Flutter client has zero integration

This is not a "some work exists" finding — the backend
(`supabase/functions/revenuecat-webhook/index.ts` +
`public.process_revenuecat_provider_event`) is a mature, secure, fully
idempotent implementation that predates this session. It does not need to be
rebuilt. What's missing is entirely on the client side.

## Backend (verified against live hosted code)

- **Auth**: constant-time comparison against `REVENUECAT_WEBHOOK_AUTH_HEADER`
  (a configured secret, not a hardcoded value); returns `503
  revenuecat_not_configured` if the secret isn't set rather than silently
  accepting unauthenticated requests.
- **Event/product/entitlement allowlists** enforced at both the Edge
  Function and the database RPC layer (defense in depth) — all nine
  previously-planned product families are already defined:
  `mort_plus_monthly`/`_yearly`/`_lifetime`, `mort_ad_free_lifetime`,
  `mort_username_change_token_1`, `mort_profile_style_pack`,
  `mort_adult_pro_monthly`, `mort_guardian_plus_monthly`, `mort_job_boost_1`.
- **Idempotency/replay**: `revenuecat_events.revenuecat_event_id` unique
  constraint with `on conflict do nothing`; a replayed event with an
  identical payload hash returns `duplicate_event` (success, no-op); a
  replayed event ID with a *different* payload hash returns
  `duplicate_payload_mismatch` (409, flagged) rather than silently
  overwriting state.
- **Ordering/race safety**: `pg_advisory_xact_lock` per `app_user_id`
  serializes concurrent webhook deliveries for the same user; the
  product-state upsert only applies `where excluded.last_event_at >=
  ...last_event_at`, so an out-of-order delivery (e.g., a `renewal` arriving
  after a later `refund` due to network reordering) cannot regress state.
- **Wrong/missing user**: `app_user_id` is validated against a real
  `public.profiles` row before any entitlement is touched; an event for a
  nonexistent user is recorded (for audit) but marked `invalid_app_user_id`,
  not applied.
- **Consumables** (username-change token, job-boost credit, profile style
  unlock) increment atomically (`token_credits + 1`,
  `available_credits + 1`) and are driven by the same event-ID idempotency,
  so a webhook retry cannot double-grant a consumable.
- **Full audit trail**: every processed event writes a
  `purchase_audit_logs` row.

This satisfies Phase 64 (webhook security) in full: no client-trusted
entitlement escalation is possible — every entitlement change flows through
the server-validated webhook path.

## Client (Flutter — the production app)

```
grep -i "purchase|billing|revenuecat" flutter_mort/pubspec.yaml
→ no matches
```

**Zero** purchase SDK, membership hub screen, or entitlement-checking code
exists in `flutter_mort`. The Expo *reference* app (not shipping — see
`qa:production-client`, "Flutter is the sole supported production client")
does have `react-native-purchases`/`react-native-purchases-ui` in
`package.json` and a full set of `/monetization/*` reference routes
(dashboard, paywall, restore, ad-free, job-boost, profile-style-pack,
username-change, a `revenuecat-debug` route, and a subscription settings
page) — these are useful as a *design/flow reference* for what the Flutter
implementation should eventually look like, but they are not what ships and
were not built to production-security standards (they're a reference
client, not gated by the same review this session gave the backend).

## What this means for Phase 57-63

```
STORE_PRODUCT_EXISTS=UNVERIFIED (no Play Console or RevenueCat dashboard access from this session -- cannot confirm real SKUs are configured on the store side)
REVENUECAT_PRODUCT_EXISTS=YES at the backend/entitlement-mapping level (9 product IDs defined and validated); UNVERIFIED at the RevenueCat dashboard level
UI_SUPPORTED=NO (Flutter has no membership hub, no purchase flow, no restore-purchases screen)
MEMBERSHIP_HUB=PROVIDER_CONFIGURATION_REQUIRED
RESTORE_PURCHASES=PROVIDER_CONFIGURATION_REQUIRED
REVENUECAT_WEBHOOK=PASS (backend verified secure and correct; not exercised end-to-end because no client can originate a real purchase event, and this session has no RevenueCat sandbox/dashboard access to simulate one safely)
JOB_BOOST_SAFETY_BYPASS=DENIED at the credit-grant layer (a job_boost_credits row is just a consumable count; it does not itself bypass job-safety/moderation checks -- those live in the job-posting/boost-consumption RPCs, which were not modified by webhook processing and were already covered by the existing job-safety regression suite)
USERNAME_TOKEN_SECURITY=PRODUCT_NOT_CONFIGURED on the client (backend credit-grant is atomic and idempotent; no Flutter UI consumes it yet)
```

Per the directive's own instruction ("Do not build a parallel billing
system," "Do not fabricate store success," "If missing:
PRODUCT_NOT_CONFIGURED"), this session did **not** attempt to build a new
Flutter purchase UI from scratch. Doing so responsibly requires:
1. Confirmed real product IDs configured in both Google Play Console and the
   RevenueCat dashboard (external, not verifiable from this environment).
2. A RevenueCat API key for the Flutter app (external secret).
3. Adding `purchases_flutter` (or equivalent) to `flutter_mort/pubspec.yaml`
   and building the actual purchase/restore/manage-subscription screens —
   real, substantial client engineering, appropriately scoped as its own
   work item once (1) and (2) exist, using the Expo reference app's flows as
   a design guide, not a code source (different framework, different
   review bar).

```
EXTERNAL_BLOCKER=UNCONFIGURED_STORE_PRODUCTS
EXTERNAL_BLOCKER=UNAVAILABLE_PROVIDER_CREDENTIALS (RevenueCat Flutter API key)
```
