# MORT Google Play Data Safety Workbook

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

This is a source-and-backend inventory, not a Play Console submission. The adult account owner must reconcile it against the exact uploaded AAB and current Google form. Data stored in Supabase is still collected because it leaves the device. HTTPS is enforced. Service-provider processing is not marked as third-party sharing here, subject to contract/legal confirmation.

## Proposed high-level answers for this closed-test build

- App collects user data: **Yes**.
- Data encrypted in transit: **Yes**, HTTPS-only client and network security configuration.
- Users can request deletion: **Yes**, in-app reauthenticated request and public email-link flow.
- Data shared for advertising: **No in this build**; AdMob is disabled and ad identifier permissions are removed.
- Payments/purchases: **No in this build**; IAP and billing permission are disabled. Payment preference records are not card/payment processing.
- Real identity documents/biometrics: **Not collected**; provider verification and document collection are disabled.
- Third-party SDKs bundled but disabled: Firebase Core/Messaging and Sentry are
  physically present but have no closed-test client configuration and are not
  initialized. RevenueCat and Google Mobile Ads are not bundled. Reconcile the
  exact AAB with Play SDK Index and revisit this statement before enabling any
  provider.

Use the companion collection, SDK, and retention CSVs as the item-by-item entry worksheet. Do not submit until a real public privacy URL, adult publisher identity, support contact, and exact AAB SDK scan are complete.

Official form guidance: https://support.google.com/googleplay/android-developer/answer/10787469
