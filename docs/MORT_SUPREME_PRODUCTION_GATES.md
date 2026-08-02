# MORT Supreme Production Gates

| Gate | Status | Required evidence |
|---|---|---|
| Public marketplace activation | BLOCKED | Every gate below plus explicit owner go-live approval |
| Identity verification | CODE-COMPLETE / PROVIDER APPROVAL REQUIRED | Provider contract, credentials, production webhook, privacy/legal/device QA |
| Payments/payouts | CODE-COMPLETE / PROVIDER APPROVAL REQUIRED | Approved processor/minor model, credentials, sandbox/live reconciliation, legal approval |
| Remote push | CODE-COMPLETE / PROVIDER APPROVAL REQUIRED | APNs/FCM credentials, real-device delivery/denial/quiet-hours QA |
| Crash reporting | CODE-COMPLETE / CREDENTIAL REQUIRED | Approved Sentry project/DSN, scrub review, release-symbol upload, alert test |
| Support/moderation/safety | CODE-COMPLETE / STAFFING REQUIRED | Named trained coverage, escalation schedule, drills, independent review |
| Legal/privacy/teen safety | CODE-COMPLETE / LEGAL APPROVAL REQUIRED | Counsel/child-safety approval and effective public documents |
| Android physical QA | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Exact final APK/device matrix and performance evidence |
| Google Play | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Version 102 uniqueness, upload, declarations, closed test, review, staged rollout |
| iOS/TestFlight | BLOCKED | Apple membership, macOS/Xcode/signing, physical iPhone, TestFlight and App Review |
| Public/legal web deploy | CODE-COMPLETE / MANUAL VERIFICATION REQUIRED | Real contacts/effective dates, host deploy, callback/domain checks |
| Backup/restore | CODE-COMPLETE / CREDENTIAL REQUIRED | CI environment secrets, encrypted offsite retention, isolated restore drill |

Provider-disabled and public-closed controls must remain unchanged until the
corresponding evidence is attached and reviewed. No single credential or owner
toggle is sufficient to open the public marketplace.

