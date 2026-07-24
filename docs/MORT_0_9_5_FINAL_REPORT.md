# MORT 0.9.5 Final Report

Date: 2026-07-24  
Version: `0.9.5+95`  
Branch: `mort-0.9.5-google-auth-full-completion`  
Starting commit: `ab874540b627578307c34d6b33f7e49839a18066`  
Supabase project: `rakjydmgwwgtdislanbt`

## Implemented

- Supabase browser PKCE Google architecture, exact native/web callbacks,
  purpose-aware sign-in/linking, recent-auth unlink protection, cancellation,
  recovery/confirmation separation, and audit events.
- Password policy raised to 12 characters with client complexity and secure
  recovery authorization tied to the Supabase recovery event.
- Atomic server action quotas shared by Stripe and AI functions.
- AI safety request caps, deterministic scanner, idempotency, safe logging, and
  authenticated quota enforcement. Fake undeployed AI scaffolds were removed.
- Atomic RevenueCat replay/concurrency/stale-event handling and protected product
  state. Webhook payload logging was minimized.
- Signed avatar/support evidence URL request limits and safe observability.
- Flutter home backend health check with honest offline and retry behavior.
- Expo dependency alignment, PostCSS security patch, and RevenueCat V2 secret
  scanner coverage.

## Remote changes

Deployed migrations:

- `20260723051250_mort_0_9_5_google_identity_controls.sql`
- `20260723055721_mort_0_9_5_atomic_edge_rate_limits.sql`
- `20260723060321_mort_0_9_5_ai_safety_grants.sql`
- `20260723061421_mort_0_9_5_atomic_revenuecat_fulfillment.sql`

Redeployed active functions include `ai-safety` v2, `revenuecat-webhook` v11,
`avatar-url` v5, `support-evidence-url` v3, Stripe payment intent v3, Stripe
resolution v3, connected account v2, account status v2, and onboarding link v2.
`send-push` remains active at v10. No new public function slug was added.

All eight Storage buckets are private. Migration history is aligned through
`20260723061421`. Public marketplace access is disabled, production identity
collection is disabled, Guardian Mode remains optional, and document readiness
is 0/18 by design.

## Provider status

- Google: provider disabled; credentials and real login/linking not configured.
- Stripe: functions deployed but provider transaction E2E not run; no live mode.
- RevenueCat: atomic backend deployed; webhook auth boundary responds securely.
  Local webhook secret was unavailable for signed webhook QA.
- AI: deterministic safe fallback works; external model key/provider disabled.
- Identity verification: provider not connected and real ID collection disabled.

## Verification summary

- Flutter: analyzer clean, 139/139 tests, web release build passed.
- Expo reference: TypeScript/lint passed, 48-route exports passed, Doctor 20/20,
  Metro started on port 8085 and stopped.
- Supabase: full 26-script regression and focused seven-script 0.9.5 tail passed;
  complete multi-user isolation was 30/30.
- Android: release lint, signed APK/AAB, package/SDK/permission/signature checks,
  emulator cold launch, process death, offline state, and retry recovery passed.
- Scans: production dependency audit, source, Git history, APK/AAB extraction,
  signing, and clean-package scanners passed.

## Not completed

- Real Google installed-app login, linking, onboarding, session persistence, and
  deletion.
- Stripe PaymentSheet/Connect/webhook/capture/refund/transfer/dispute E2E.
- Complete seven-role emulator journey and every route/action device matrix.
- Physical Android testing.
- macOS/Xcode, iPhone, TestFlight, and App Store testing.
- Qualified legal, tax, privacy, child-labor, accessibility, and teen-safety
  review.
- Staffed incident exercise, production restore drill, monitoring destinations,
  public-store review, and real-user support staffing.
- Owner classification and cleanup of 11 retained synthetic QA users.
- Supabase leaked-password protection, deferred until a future Pro upgrade.

MORT 0.9.5 is a code-controlled closed-pilot candidate, not production ready.
Do not admit real marketplace users or enable payment/identity/provider flags
until the blocked gates are completed and reviewed.
