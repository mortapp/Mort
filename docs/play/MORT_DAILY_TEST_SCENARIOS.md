# MORT Daily Closed-Test Scenarios

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

Run the scenario matching the 14-day plan, then a five-minute daily smoke: cold launch, sign in, open synthetic feed, open one job, navigate to Safety Center, verify report/block entry points, background/foreground, and sign out. Each day record device/OS/app version, network, permission state, pass/fail, defect ID, severity, and whether the tester remained opted in. Never manufacture a pass or reuse evidence from another device.

Permission variants must include deny, permanent deny, approximate, and manual fallback. Auth variants include expired session, wrong password, reset, revoked session, and offline recovery. UGC variants include clean, spam, unsafe, blocked-user, and no-job-context messaging. Account deletion uses disposable synthetic accounts only.
