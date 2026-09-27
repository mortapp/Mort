# Safety Center and paywall code review — 2026-09-27

One agent performed the required four perspectives sequentially against the
combined implementation based on commit 4dbdd9289d621931946a6b1859cc52559543005c.
No merge or production activation is authorized by this review. Exact-head CI
and artifact results belong in the final report under C:\Users\micha\Mort.

## Believer

The diff preserves the current landing and adds free Emergency/Safety access,
explicit sharing/travel, recipient-specific views, private reports/evidence,
separate Safety Contact threads, native power readings and the refined paywall.
Opening Emergency calls no mutation. The real canonical Start/Finish PIN,
cancellation, messaging, review and payment workflows remain server controlled.

Evidence: 733 combined Flutter tests passed, with two existing skips; the final
Flutter analysis reported no issues. Ten affected local checks passed, including
actual authenticated Safety and Edge requests. Screenshots are synthetic visual
QA, never evidence of delivery or a purchase.

## Skeptic

Inspected actor binding, service-only functions, RLS, recipient snapshots,
revocation, age-out, account suspension, expiry, request hash replay, nullable
job context, queued actions, storage failures and private image limits. Local
adversarial checks found no unauthorized Safety access. The null native battery
case was reproduced as a failing check, fixed to preserve the last confirmed
reading in the server snapshot, and rechecked successfully.

Other reproduced defects corrected before this review include current-job
priority, finish/departure false escalation, guardian exact ETA exposure,
poster cancellation stopping teen Emergency sharing and stale runtime refresh.

Explicit limits: native sensor/dialer execution and OS secure storage have not
been exercised on a physical device. Foreground GPS does not continue after OS
suspension or termination. Cached recipient data is reauthorized by periodic
foreground polling; no claim of instantaneous device cache revocation is made.
Some default-font button labels in the widget-test renderer remain Ahem blocks;
that renderer limitation is not a native landing-page visual certification.

## Investor / operations

Google Routes is disabled without both a server flag and private credential.
Only a duration is requested, requests are bounded and budgeted, and posters see
coarse ETA ranges instead of precise coordinates. No current local test called
the live provider. The backend worker distinguishes first/second online misses
and 2/5/15-minute connectivity states without applying job fault or financial
penalties. Queued notifications explicitly do not claim recipient delivery.

Hosted migration/function deployment, push transport/device receipts, consent,
retention, staff coverage and operational/legal approval remain external gates.
The new migration was applied and validated transactionally only in mort-mobile.
Docker Loop was not used for these operations. Temporary local QA fixtures and
synthetic provider acknowledgments do not certify a real refund or payment.

The paywall uses the existing RevenueCat offering/client workflow. UI contracts
and a labelled price preview do not certify current client purchases/restores or
licensed Play billing. The highest uploaded Play version must be established
before generating a new upload release; older version 113 outputs are not new
certified artifacts.

## Judge

The local implementation is reviewable and ready for a draft PR and exact-head
CI. No known reproducible local code defect remains in the exercised contracts.
Native builds and full clean migration regression must pass on that exact head.
External Safety and Play gates remain unresolved and may not be overruled by
passing mocks, contracts or screenshots. Overall production verdict remains
SAFETY_NOT_READY until the required real-device/provider/operations evidence is
obtained. Production activation and merge remain NO.

## Local evidence locations

All evidence is under C:\Users\micha\Mort\build\qa:

- SAFETY_PAYWALL_FINAL_FLUTTER_REGRESSION_2026-09-27.log
- SAFETY_PAYWALL_FINAL_ANALYZE_2026-09-27.log
- SAFETY_qa-safety-center-runtime_2026-09-27.log
- SAFETY_qa-safety-travel-edge_2026-09-27.log
- SAFETY_qa-job-pin-concurrency_2026-09-27.log
- SAFETY_qa-evidence-preservation_2026-09-27.log
- SAFETY_qa-rls-cross-user-exploit_2026-09-27.log
- SAFETY_MIGRATION_TRANSACTION_VALIDATION_2026-09-27.log

The local working tree contains a flutter_mort/node_modules dependency junction.
It is ignored as a dependency, excluded from staging and artifacts, and retained
on disk. Automatic approval review previously
rejected its removal; this review does not bypass that rejection or claim a
completely clean worktree.

## CI follow-up review

The first exact-head clean migration CI reset succeeded, but the older Guardian
Mode QA expected a notification for a routine successful ping. That assertion
was reproduced locally. The supplied Safety skill explicitly restricts routine
successful check-in notifications. The QA now proves quiet routine status and
also requires an explicit Safety Alert to queue exactly one enabled guardian
notification, with unrelated guardian access denied. Hosted legacy behavior
remains tested until the new runtime is deployed.

Additional authenticated local checks verify travel reconnect requires explicit
Continue/Cancel, request replay, poster arrival denial and teen I'm Here without
work start. The canonical contract-change test now also exercises both-party
consent for the exact Safety reschedule date/time and unchanged agreed amount.
This follow-up changes verification and dependency exclusion, not production
Safety or paywall behavior. The four review perspectives retain the same
production and external-gate verdict, subject to the corrected head's CI.

## Requested free continuation

The user requested Continue with Free directly below the paid-plan action. The
preserved paywall now provides an outlined free action using the existing close
navigation callback; it never calls the purchase callback or changes entitlement
state. It is also available when offerings are loading/unavailable. Accounts
already showing active Pro retain the existing close action; this button does
not cancel a subscription or revoke Pro.

Sequential review: Believer checked placement and preserved styling; Skeptic
checked the close/purchase callbacks and account state boundaries; Investor
checked that free continuation does not mutate billing; Judge requires the
current focused widget, render/callback and exact-head CI results. The six
focused paywall contracts passed after this change. Native artifacts from
0f7b383 predate the free button and must not be presented as the newest UI.
