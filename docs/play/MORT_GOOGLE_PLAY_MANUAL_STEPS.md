# MORT Google Play Console Manual Steps

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

1. Adult father creates/verifies the personal developer account and enables two-step verification without sharing credentials.
2. Create app **MORT - Teen Jobs & Local Help**, default language English (US), app, free, with package `com.mortapp.mobile`.
3. Invite founder/release manager with least privilege.
4. Complete app setup, target audience (13-15, 16-17, 18+ only), content rating, Data Safety, child-safety contact, ads=no, and app-access credentials.
5. Deploy public pages over HTTPS; replace adult publisher/contact placeholders; enter exact privacy, child-safety, support, website, and deletion URLs.
6. Enroll in Play App Signing and compare upload certificate SHA-1/SHA-256.
7. Confirm no existing Play artifact has versionCode 90 or higher.
8. Upload `mort-play-closed-test.aab` to internal test first, review automated checks/SDK warnings/pre-launch report, then promote the same verified candidate to closed test if clean.
9. Create a closed-testing email/Google Group list, publish opt-in link, and maintain at least 12 continuously opted-in testers for 14 days if required by the Console.
10. Record actual feedback, fixes, versions, crashes, ANRs, accessibility and policy issues. Apply for production access only after the Console requirement and evidence are complete.

Google's current new-personal-account guidance: https://support.google.com/googleplay/android-developer/answer/14151465
