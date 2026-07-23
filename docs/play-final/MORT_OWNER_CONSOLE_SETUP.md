# MORT Owner Console Setup

Only the Google Play account owner should perform these steps.

1. Create or select package `com.mortapp.mobile`; enable Play App Signing and protect owner recovery methods.
2. Add founder/manager accounts using least privilege from `MORT_FOUNDER_MANAGER_PERMISSIONS.md`; never share the owner login.
3. Complete App content, target audience, child-safety, data-safety, ads, financial-features, content-rating, privacy-policy, and account-deletion declarations using the reviewed workbooks in this folder.
4. Upload the new AAB to **Internal testing** first. Confirm its version code is greater than every prior upload and that the upload certificate matches the repository report.
5. Create license testers and Play test tracks before activating any product. Test accounts must use Google accounts listed in Play Console.
6. Keep public production closed. Promote to closed testing only after automated QA, emulator smoke, manual real-device testing, and reviewer access checks pass.
7. Review pre-launch reports, Android vitals, policy status, and Data safety after each upload. A clean local build is not Play approval.

Do not paste Supabase, Stripe, OpenAI, Google service-account, signing, or webhook secrets into Play Console listing fields.
