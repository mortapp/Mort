# MORT Google Play Data Safety Workbook

> Status: closed-test publication candidate dated 2026-07-20, advertising section revised 2026-08-20 to match the real `google_mobile_ads` SDK integration. Not legal approval, not a public launch, and not a production-readiness claim.

This is a source-and-backend inventory, not a Play Console submission. The adult account owner must reconcile it against the exact uploaded AAB and current Google form. Data stored in Supabase is still collected because it leaves the device. HTTPS is enforced. Service-provider processing is not marked as third-party sharing here, subject to contract/legal confirmation.

## Proposed high-level answers for this closed-test build

- App collects user data: **Yes**.
- Data encrypted in transit: **Yes**, HTTPS-only client and network security configuration.
- Users can request deletion: **Yes**, in-app reauthenticated request and public email-link flow.
- Data shared for advertising: **Yes, on Android, as of the ads-SDK reversal below**; `google_mobile_ads` is bundled and initialized behind `ADS_ENABLED`, serving real Banner/Rewarded ads gated to eligible non-sensitive surfaces only (never auth, onboarding, safety, reporting, Guardian approval, identity/proof evidence, messages, support, payment preferences, PIN verification, job completion, or legal information -- enforced both client- and server-side). Advertising ID (`AD_ID`) permission is present on Android. Teens are always served non-personalized ads regardless of any preference. No iOS AdMob app exists yet, so iOS declares no advertising SDK.
- Payments/purchases: **No in this build**; IAP and billing permission are disabled. Payment preference records are not card/payment processing.
- Real identity documents/biometrics: **Not collected**; provider verification and document collection are disabled.
- Third-party SDKs bundled but disabled: Firebase Core/Messaging and Sentry are
  physically present but have no closed-test client configuration and are not
  initialized. RevenueCat is not bundled. **`google_mobile_ads` is now bundled
  and initialized on Android** (see the advertising bullet above) -- this is a
  deliberate, owner-authorized policy reversal from the "not bundled" state
  this document originally described; reconcile the exact uploaded AAB with
  the Play SDK Index and this document before any Data Safety submission.

Use the companion collection, SDK, and retention CSVs as the item-by-item entry worksheet. Do not submit until a real public privacy URL, adult publisher identity, support contact, and exact AAB SDK scan are complete.

Official form guidance: https://support.google.com/googleplay/android-developer/answer/10787469
