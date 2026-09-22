# MORT progression architecture and release gate

## Current implementation

Flutter remains the production mobile client. The existing black and silver visual system, teen navigation, onboarding, safety flows, and monetization surfaces remain in place. The new Progression Hub is linked from Teen Profile. The existing dashboard leaderboard remains available with its own score and tier labels; those labels are reputation history, not XP rank.

Migration `20260920235334_mort_progression_v1.sql` adds private progression accounts, an event ledger, badge ledger, cosmetic catalog, unlocks, and equipped cosmetics. It hooks only the existing completed-application transition and eligible post-job review insert. No client RPC accepts an XP amount, rank, level, or token delta. The Flutter repository can read the signed-in teen's snapshot, read allowlisted leaderboards, and request an allowlisted cosmetic unlock or equip action.

XP rules: completed job +100, first completed job +100 once, first completed job in each existing job category +25 once, completed teen check-in sequence +10 once per qualifying completed job, eligible post-job review +15 once per job. No payment amount, subscription, ad, verification, report, block, or login event awards XP. Levels 1–50 use `100 + 25 × (L−1)` XP from level L to L+1. Bronze is 1–10, Silver 11–20, Gold 21–30, Platinum 31–40, Diamond 41–50. Rank is activity, never identity or a safety guarantee.

Every crossed level awards one Motion Token. Levels 11, 21, 31, and 41 add 5, 10, 15, and 25 tokens respectively. Motion Tokens are noncash, nontransferable, and usable only on the private allowlisted cosmetic catalog. The account row is locked before awarding or spending. Deterministic event keys and request IDs make replay and concurrent spending safe.

The migration resets existing teens to hidden on leaderboards and makes hidden the default for future profiles. This is necessary because the previous `leaderboard_opt_out=false` default did not record affirmative consent. Public leaderboard RPCs return only chosen username, safe avatar path, rank, level, board score, and completed count. They exclude test and restricted accounts. The older dashboard RPC is rewritten to return the chosen username in its `display_name` compatibility field. Earnings, precise location, age, school, guardians, reports, and verification records are not selected.

| Surface | Anonymous | Authenticated teen | Other authenticated user | Server role |
| --- | --- | --- | --- | --- |
| Private progression tables | No grant | No direct grant | No direct grant | Read/write |
| Own progression RPC | Denied | Own snapshot | Denied | Operational access |
| Cosmetic unlock/equip RPCs | Denied | Own allowlisted cosmetic | Denied | Operational access |
| Leaderboard RPC | Denied | Opted-in public rows | Opted-in public rows | Operational access |
| Internal award functions | Denied | Denied | Denied | Trigger/owner only |

All private tables have RLS enabled and no client policies. Public `security definer` RPCs use an empty search path, schema-qualified tables, explicit `auth.uid()` checks, narrow grants, and no dynamic SQL. The internal award functions are revoked from client roles. The currently configured Supabase Data API exposes `public`, `storage`, and `graphql_public`, not `private`.

## Testing and activation

PostgreSQL 17 disposable execution passed from the clean certification baseline. The complete SQL assertion suite covers the XP matrix, thresholds, rank cap, rewards, badges, replay, permissions, RLS, privacy, cosmetics, correction authority, and trigger separation. A separate two-session attack proved concurrent token spending cannot create a negative balance or duplicate fulfillment. Reapplying the one-shot progression migration is rejected at the first existing table, as expected.

Local client verification on September 21, 2026 passed formatting for 309 Dart files, `flutter analyze --no-pub`, 566 ordinary Flutter tests with 2 intentional Google activation skips, and both Android integration tests. Upload-signed closed-test APK and AAB artifacts passed release verification, all 18 native libraries passed 16 KB alignment, and the signed APK installed and launched on the Pixel 6 emulator.

The database migration has not been applied to the hosted MORT project. The current UI checkout is missing 53 already-applied hosted migration versions, so linked migration planning is performed from the isolated complete-history checkout. Its dry run reports exactly the progression migration and the account-deletion financial FK repair as pending. Production must be backed up and reviewed before deployment. After deployment to an approved non-production project, run `scripts/qa-gamification-exploit.mjs` and `scripts/qa-leaderboard-exploit.mjs` with real QA JWTs before production activation.

## Privacy and platform notes

Progression adds app-interaction and achievement data. Review the App Store privacy answers and Google Play Data Safety answers for this data before release. The migration adds no tracking SDK, advertising identifier use, public document storage, school data, or payment-linked XP. iOS parity needs an actual macOS/Xcode build; Windows source inspection cannot certify it.

## Remaining blueprint work

The Progression Hub shows rank, level, XP, tokens, badges, goals, streak, recent events, boards, cosmetic ownership, equip actions, server-backed milestone treatment, and privacy-safe PNG sharing. Silver Edge, Night Signal, and Ice Trace render through the existing MORT visual system. External gates remain for hosted QA migration/JWT attacks, migration-history reconciliation, exact-head CI from a clean commit, RevenueCat live webhook replay, and macOS/Xcode/iPhone certification. The Business Help board remains defined but empty until the canonical job taxonomy includes a reviewed business-help category.