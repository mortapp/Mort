# Future AdMob Setup

Android ads are not compiled into the active UI, all ad identifiers are stripped, and `ADS_ENABLED=false`. This is deliberate until child-directed-treatment, consent, Play declarations, and placement review are complete.

Before enabling Android AdMob:

1. Create a distinct Android AdMob app for `com.mortapp.mobile`; do not reuse iOS unit IDs.
2. Register test devices and use Google's test ad units until closed-test review passes.
3. Integrate a consent platform appropriate to every launch jurisdiction and resolve age/teen treatment before requesting an ad.
4. Configure non-personalized, age-restricted treatment for teens and unknown-age users. Do not use sensitive profile, job, location, message, safety, verification, or payment data for targeting.
5. Keep ads out of auth, messaging, proof, verification, payments, reports, blocking, Safety Ping, admin, and paywall screens.
6. Update Play Ads and Data safety declarations, privacy policy, SDK inventory, app-ads.txt, and reviewer instructions.
7. Re-enable SDK components and AD_ID only in a reviewed release, then rerun manifest, placement, consent, test-mode, and physical-device QA.

No ad may block core work or safety actions. Rewarded ads must be optional and cannot unlock safety, job applying, or basic Guardian Mode.
