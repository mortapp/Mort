# MORT Defect Triage Process

1. Remove credentials and real personal data from evidence.
2. Assign severity: blocker, critical, high, medium, low.
3. Reproduce on the same build/device and one comparison environment when safe.
4. Link route, role, release mode, network, permission state, logs, and fixture.
5. For security/safety issues, restrict visibility and preserve narrow evidence.
6. Fix with a new version code when the AAB changes; run focused and full regression.
7. Close only with recorded retest evidence. Crashes, isolation failures, under-13 admission, report/block/deletion failures, and unsafe trust/payment claims are blockers.
