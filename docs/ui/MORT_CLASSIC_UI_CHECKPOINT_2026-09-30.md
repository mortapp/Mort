# Classic UI and teen school gate checkpoint — 2026-09-30

Branch: `feature/mort-classic-ui-redesign`, isolated from the primary MORT checkout. The frozen Google Play Closed Testing build `0.9.16+114` is unchanged. No version 115 build, hosted migration, merge, Play upload, or production rollout occurred.

## Implemented on this branch

- Classic white/black theme and shared surfaces; classic landing, role tab/navigation foundation, and direct profile/settings destinations. The route inventory records remaining screen work.
- Searchable Indianapolis school directory, with public names separated from private student-domain approval.
- DOB and school selection on signup; manual teen email signup checks the server's school/domain decision before Auth signup. Google and Apple signup controls wait for DOB and a teen school selection.
- Teen onboarding saves DOB and verifies the selected school's current confirmed primary Auth email before assigning the teen role. The Trust screen can retry verification.
- Database teen-role and marketplace gates, including direct profile-role writes, remain fail-closed without current school eligibility. No production student domain was approved.
- Missing-school suggestions enter a private review queue. Submission does not list a school, approve a domain, or create an Auth account.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter compact`: 770 passed, 2 skipped. Full output is in the ignored local `.superpowers/sdd/2026-09-30-mort-classic-ui-foundation/flutter-test-final-exact.log`.
- MORT Docker PostgreSQL rollback suite: directory, school email, teen role, marketplace, and anonymous school-request tests passed inside `BEGIN`/`ROLLBACK`. The unrelated Loop app/database was not used.
- Staged secret scan: 2,454 text files, zero findings. `git diff --cached --check`: clean.
- No physical device or emulator verification for this branch. The owner previously asked not to open an emulator; build 114 device evidence pertains only to the frozen Play build.

## Sequential audit

1. **Believer:** Shared classic components and role navigation are present; school decisions are server checked. The positive synthetic teen sandbox path and negative school/role cases pass locally.
2. **Skeptic:** A modified client can still create a role-less Auth identity before DOB/school confirmation, including through OAuth sign-in. The server blocks teen role and marketplace access, but strict pre-Auth account creation is not certified. Anonymous school requests need abuse controls before hosted activation. No production student-domain evidence exists.
3. **Investor/operations:** Staff review UI, evidence/audit workflow, and verified production domain approvals are still required. Most route-specific classic UI screens remain unaudited. Hosted schema and physical-device behavior must be checked before a future closed-track build.
4. **Judge:** This is a tested development checkpoint, not completion of the full product-wide directive or approval to deploy. Keep release/payment/safety gates as they are and continue the route-by-route UI and school-review work on this branch.

## Continuation — 2026-10-03

- Fixed the school selector retaining an invisible prior school after the search changed. Continue now requires a selection from the current search; the new widget regression passed.
- Rebuilt the separate public legal and safety site with a simple black and white reading layout. All 13 generated routes remain present; the text inside all 12 document article bodies matches the prior generated site exactly. The account-deletion form and its JavaScript authorization flow are unchanged. The obsolete rain animation, browser runner, and site-only animation dependencies were removed. The site has a self-hosted SVG favicon.
- Updated the root README, which had incorrectly described Play build 114 as `0.9.7+97` with billing disabled. The frozen Play artifact remains `0.9.16+114`; this branch has no new Android build.
- Flutter full suite: 771 passed, 2 skipped. Focused school-picker widget tests: 3 passed. Flutter analysis: no issues. Main Flutter website release preview build: passed with billing and ads disabled for web. Legal site unit/route checks: 3 passed; syntax check and account-deletion contract check passed. Legal site production dependency audit: zero vulnerabilities. Source and compiled web JavaScript secret scans: zero privileged findings.
- Desktop browser review confirmed the legal home, Privacy navigation, and deletion controls. A separate local browser smoke of the compiled main Flutter website confirmed the black and white MORT landing, Enter MORT, and the Create Account / I already have an account choice without submitting credentials. The browser automation could not switch the legal site to a mobile viewport in two attempts, so that responsive layout remains unverified by a browser. No deletion form was submitted.
- Docker became available later in this continuation. The exact current school migrations and three SQL tests passed inside a single `BEGIN`/`ROLLBACK` against `supabase_db_mort-mobile` with `ON_ERROR_STOP=1`; no Loop container was used and no local schema changes were retained. The school-request abuse-control gate and hosted school/domain approvals from the prior checkpoint remain open. The majority of route-specific Flutter redesign work, real devices, and all provider/production gates also remain open.
- No version 115 build, hosted migration, merge, Play upload, or public production rollout occurred.

## Continuation — school request queue bound

- Added a new migration that serializes anonymous suggestion inserts and caps the shared private queue at 30 new rows per hour and 200 per day. Duplicate suggestions still return the same opaque receipt and consume no new slot. The form now explains when the queue is busy.
- A rollback-only MORT Docker PostgreSQL replay passed the original school suite plus hourly cap, daily cap, duplicate-at-cap, and cap-expiry checks. The added index was absent afterward, confirming rollback. No Loop database or hosted database was changed.
- This is a bounded growth control, not complete bot protection. A malicious caller can exhaust a global quota; trusted gateway challenge/rate limiting and staff review remain gates before hosted activation.
- Flutter analysis: no issues. Full Flutter suite: 772 passed, 2 skipped. The focused school picker/request suite: 4 passed. Dart format check: clean. Source secret scan: 2,494 files, zero findings. Staged diff check: clean.

### Sequential review of the queue bound

1. **Believer:** The additive RPC change preserves the existing pre-account request behavior and duplicate privacy while preventing unbounded accepted rows in an hour or day. The client has a clear retry state.
2. **Skeptic:** The shared quota can be exhausted by an attacker and does not throttle requests that never insert a row. It needs a trusted gateway challenge or provider rate control before hosted activation.
3. **Investor/operations:** The queue bound limits storage and review workload without an external service or caller-controlled IP. Operators still need a staff review workflow and an escalation path for legitimate users when the shared quota is exhausted.
4. **Judge:** Accept this as a locally tested source checkpoint only. It does not authorize hosted migration, production student-domain approval, or a new Play build.

## Continuation — private school request triage

- Added an admin-guarded classic screen with pagination for pending, reviewing, rejected, and accepted school suggestions. Staff may start review or reject with a required note. The server checks a current active admin account, records each transition in a private append-only audit table, and rejects any client attempt to mark a request accepted. No action creates a school, domain assignment, or teen eligibility.
- The MORT local database passed non-admin and suspended-admin denial, private table grants, review/rejection transitions, closed-request denial, audit count, and no-approval checks inside the same outer rollback. The prior queue cap tests passed in that run too. No hosted database was changed.
- Widget tests found and fixed a dialog-controller disposal bug in the new staff screen. The same vulnerable pattern in the existing operational-alert and moderation-reason dialogs was replaced with route-owned text state and scrollable content. Focused staff and operational dialog tests pass.
- School/domain acceptance with independently verified source evidence, trusted anonymous abuse controls, hosted migrations, and physical review remain open.
- A full Flutter regression attempt exposed an intermittent 200 ms wall-clock profile timeout in the existing startup test under full-suite load. The isolated test passed. The test now controls profile completion explicitly and asserts that startup remains in the restoring state until the profile resolves; focused auth and admin tests pass. Production timeout behavior was not changed.
- After that repair, Flutter analysis found no issues and the full suite passed **775 tests, 2 skipped**. The separate moderation dialog regression passed. The public legal site still passes 3/3 Node tests. The source secret scan found zero matches across 2,501 text files. The latest school SQL suite passed with `ON_ERROR_STOP=1` in a MORT-only rollback transaction, including paged reads and null-input denials.

### Sequential review of private triage

1. **Believer:** The active-admin RPCs limit reads to private, paged school suggestions and make reviewing/rejected transitions auditable. The UI has no approval action, and the server rejects a forged accepted decision. The repaired dialogs close without accessing disposed controllers.
2. **Skeptic:** This is local rollback evidence. A shared request quota can still be exhausted, and staff have no source-verified acceptance/domain approval flow. A suspended admin is denied, but hosted grants and physical navigation are not certified.
3. **Investor/operations:** Pagination keeps older suggestions reachable. A real review team needs evidence standards, escalation for quota exhaustion, and a controlled approval process before students can use new schools.
4. **Judge:** Accept the local triage source and regression fixes only after the final exact-head checks pass. Keep hosted deployment, new Play builds, and production eligibility unchanged.

### Sequential review of this continuation

1. **Believer:** The picker can no longer continue with a school hidden by a new query. The legal site renders 13 routes without the old animation, and the 12 document article bodies match the previous generated output. Flutter tests, legal tests, web build, and secret scans pass.
2. **Skeptic:** The browser tool verified desktop navigation but failed to enter a mobile viewport, so responsive browser behavior is not certified. The pre-account school-request RPC still has no robust abuse control. The local SQL replay passed in a rollback transaction, but hosted proof did not run.
3. **Investor/operations:** The simpler site removes animation dependencies and reduces its production dependency audit to zero findings. Legal approval, publisher review, mobile device review, school-domain evidence, and the broader screen inventory remain deployment gates.
4. **Judge:** Accept this as a tested source checkpoint on the isolated branch only. Keep the existing Play 114 artifact, public rollout, billing, marketplace, hosted database, and release merge unchanged.
