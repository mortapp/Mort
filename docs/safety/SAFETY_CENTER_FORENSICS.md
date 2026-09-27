# Safety Center forensics — 2026-09-26

Baseline: `4dbdd9289d621931946a6b1859cc52559543005c`. Dedicated checkout:
`C:\Users\micha\Mort.worktrees\feature-mort-safety-center`, branch
`feature/mort-safety-center`. The former clean tip `fe9c311` is retained as
`safety/pre-center-baseline-20260926` and in the original main checkout. No merge,
production deployment, or public activation is authorized by this work.

Authority: `../skills/mort-safety-system/SKILL.md` and
`MORT_SAFETY_EXECUTION_SPEC.md`. Flutter remains the only production client.
The paywall refinement remains in its separate checkout and resumes after Safety.

| Subsystem | Initial classification | Canonical implementation / gap |
|---|---|---|
| Roles, age, account restrictions | EXISTS_BUT_INCOMPLETE | profiles, MORT Verify, server eligibility; emergency access must survive missing remote state |
| Safety Center | EXISTS_BUT_INCOMPLETE | mort_screens.dart; ping form and check-ins, no immediate Emergency panel |
| Start/Finish PIN | EXISTS_BUT_INCOMPLETE | job_execution_repository, handshake RPCs, payload-bound replay/locks; missing final safety confirmation |
| Job safety exit | EXISTS_BUT_INCOMPLETE | submit_safety_cancellation creates private case/disputed job; new fast flow must bypass Finish PIN |
| Six-minute monitoring | EXISTS_BUT_INCOMPLETE | canonical job_checkins uses 60-minute default and first-miss family alerts |
| Offline 2/5/15 detection | MISSING | connectivity exists; no safety heartbeat/runtime escalation |
| Battery policy | MISSING | no battery sensor or job-aware battery budget |
| Manual travel / ETA | MISSING | on-demand geolocation exists, no explicit safety trip |
| Live sharing | EXISTS_BUT_INCOMPLETE | canonical job_location_share_sessions supports restricted recipient sharing; no 60-minute update lifecycle |
| Guardian | EXISTS_BUT_INCOMPLETE | links/preferences/age revocation; ping UI lacks current-job safety projection |
| Trusted contact | EXISTS_BUT_INCOMPLETE | safety_circle_members; routine successful pings currently notify contacts |
| Urgent poster contact | MISSING | ordinary job chat exists; no event-scoped temporary contact channel |
| Reports | EXISTS_BUT_INCOMPLETE | submit_safety_report_v2, private incidents; single category and required text |
| Evidence | EXISTS_BUT_INCOMPLETE | private incident-evidence bucket, ownership/hash/register/audited grants; image-only Flutter picker |
| Blocking | EXISTS_BUT_INCOMPLETE | block_user_v2, no_contact trigger, safe messaging; future matching and review-hold paths need negative verification |
| Moderation / appeals / audit | EXISTS_BUT_INCOMPLETE | specialized admin_role_assignments, incident evidence grants/access events, outcomes/appeals; new runtime events need audit |
| Retaliation / payments | EXISTS_BUT_INCOMPLETE | disputed safety cancellation, no_contact, abandonment cooldown; new hold must preserve legitimate Stripe disputes |
| Ads / Pro / companions | EXISTS_BUT_INCOMPLETE | AdMob eligibility forbids safety; no purchases in safety repository; verify all new surfaces and disable motion |
| Device background parity | OS_LIMITATION | foreground geolocation only; iOS remote-notification mode is not continuous execution |
| Push delivery | EXTERNAL_GATE | canonical enqueue_notification/FCM/APNs; queue acknowledgment cannot mean device delivery |
| Physical devices | EXTERNAL_GATE | no adb device attached; iOS cannot run on this Windows host |
| Operations / legal / retention | EXTERNAL_GATE | existing runbooks/release gates; staffed response and location retention need real owner review |

No initial subsystem is declared verified solely from reading code or historical
reports. Fresh behavior, negative authorization tests, render evidence, and exact
head build/CI are required. No RevenueCat authority is introduced into Safety.
