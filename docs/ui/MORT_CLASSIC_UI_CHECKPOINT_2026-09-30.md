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
