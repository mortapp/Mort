# MORT 14-Day Closed-Test Plan

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

Recruit 24 adults/eligible participants to preserve coverage and attrition margin. Maintain at least 12 continuously opted-in testers for 14 consecutive days if Play Console applies the new-personal-account rule. The Console's displayed requirement controls. Testers receive no Console access and no private safety evidence.

Target coverage: Android 10-16 where available; Samsung, Pixel, Motorola, low-memory/budget, small and large screens; Wi-Fi, cellular, slow network, and offline recovery. No tester needs every device.

| Day | Focus | Evidence |
|---|---|---|
| 1 | Play install, launch, sign-in, production identity, consent | Device/version/install notes |
| 2 | Registration, under-13 denial, password reset, role onboarding | Age and auth outcomes |
| 3 | Job feed, manual area, denied/approximate/precise location | Permission screenshots without addresses |
| 4 | Synthetic posting/application and Guardian Mode paths | Workflow IDs only |
| 5 | Job-context messages, scanner, report, block | Sanitized results |
| 6 | Start/completion handshake and proof picker/camera | Synthetic media only |
| 7 | Payment-preference and nonpayment workflow; no processing | Copy and state checks |
| 8 | Safety Ping, notification permission and private previews | No incident/location detail on lock screen |
| 9 | Biometrics, app lock, background/foreground, process death | Recovery behavior |
| 10 | Deep links, expired session, logout/revocation, offline retry | Auth/navigation evidence |
| 11 | Accessibility, screen reader, large text, dark mode, rotation | Accessibility defects |
| 12 | Low battery/memory, slow cellular, image upload recovery | Performance notes |
| 13 | Account deletion in-app and external web flow | Request/status only, synthetic accounts |
| 14 | Update from prior test build, regression, final survey | Version transition and feedback summary |

Release blockers include startup/login failure, unavailable report/block/deletion, under-13 onboarding, marketplace/ID enablement, cross-user exposure, live teen location exposure, debug signing, policy URL mismatch, secret detection, and fatal plugin errors.
