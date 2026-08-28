# Profile, MORT Guide, and Play Billing Release Results

Release: `0.9.2+92`, package `com.mortapp.mobile`, closed-pilot candidate.

## Implemented and verified

- Profile updates use `update_my_profile`, derive identity from `auth.uid()`, whitelist mutable fields, return the persisted row, preserve drafts on recoverable errors, refresh providers, and protect avatar paths. Seven remote profile suites and Flutter contract tests pass.
- Auth/session, server DOB bands, under-13 rejection, role forgery, school-ID/alternative teen routes, contextual camera flow, and real-document-disabled controls pass remote QA.
- MORT Guide defaults to deterministic `faq_only`. Private conversation/consent/history/export/deletion/expiry/feedback/safety tables and RPCs are deployed. `ai-support` and `ai-safety` are active and reject unauthenticated calls with 401.
- Optional OpenAI sandbox architecture uses the server SDK, Responses API with `store: false`, input/output moderation, token/budget/rate limits, teen consent, timeouts, retry, and FAQ fallback. Provider secrets are absent, so no external-model call was made.
- Google Play Billing client/server architecture compiles with `in_app_purchase 3.3.0`. Product IDs are `mort_plus`, `mort_theme_neon_pack`, `mort_theme_midnight_pack`, `mort_profile_frames_pack_01`, and `mort_portfolio_layouts_pack_01`. Localized Play price strings are authoritative. Server entitlements, token hashes, replay/idempotency, review grants, and reconciliation contracts pass QA.
- Billing mode is `license_test`, but `IAP_ENABLED=false` and all product/provider gates remain false until Play Console products, Developer API credentials, RTDN, deployment, and license testing exist.
- Android ads remain excluded. Ad IDs and AdMob auto-start components are stripped; teen/unknown-age and sensitive-placement server policy tests pass.

## Release evidence

- Flutter format: 134 files, 0 changed.
- Flutter analyze: no issues.
- Flutter tests: 105 passed.
- Focused hosted QA: 50/50 scripts passed.
- Established Supabase regression: 23/23 scripts passed, including 30 multi-user checks.
- Web preview: release build passed; IAP and ads disabled.
- Emulator: API 36 install/launch passed, process remained alive, no fatal Android error, `Closed Pilot` and secure hosted-backend connection rendered, sign-in form rendered.
- AAB: 63,210,391 bytes, SHA-256 `785699EC970C6E504BFD858110676C341AC7B0ED867989A5CA4E29EF80BDF42B`.
- APK: 74,578,652 bytes, SHA-256 `5100EF7A86A442DCE609CE2EC8FDB67BEC6C1840C519537F21D94B263785D927`.
- Signer: RSA-4096 MORT upload certificate; SHA-256 `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`.

## Bugs found and fixed

1. Profile UI could report success without canonical persistence. Replaced direct writes with a caller-bound, server-returning RPC and state refresh.
2. Ad eligibility lost profile access after RLS hardening. Added a caller-bound security-definer RPC with fixed search path and explicit grants; both ad-safety suites pass.
3. The first signed build concatenated nine PowerShell Dart defines into one argument, causing `Development` mode and no Supabase configuration. Corrected argument construction, rebuilt, reinstalled, and visually verified `Closed Pilot` plus backend connectivity.
4. Android permission QA still expected Billing to be removed. Updated the contract to require Billing while continuing to reject ad IDs, background/media permissions, wake lock, and AdMob startup.

## Not completed

No physical Android device, Google Play-delivered install, license purchase, RTDN, OpenAI provider call, real identity document, live ad, Stripe provider call, iPhone, TestFlight, or public-production test was performed. Public marketplace and real identity collection remain closed.
