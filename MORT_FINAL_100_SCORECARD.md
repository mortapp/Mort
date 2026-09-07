# MORT Final-100 Readiness — Scorecard

Evidence-based only. No area is marked 100 without a cited command, file, or finding.
Updated incrementally as tracks complete — see `MORT_BACKEND_SAFETY_AUDIT_SESSION1.md`,
`MORT_BACKEND_SAFETY_AUDIT_SESSION2.md`, and `MORT_FINAL_100_BASELINE.md` for the
underlying evidence.

| AREA | INTERNAL % | EXTERNAL STATUS | EVIDENCE | REMAINING INTERNAL WORK |
|---|---|---|---|---|
| CI/repository health | 100 | N/A | PR #7 merged after verifying head SHA/CI/scope; fresh `dart format`/`flutter analyze`/`flutter test` (448 passed/2 skipped/0 failed) on updated main | None found |
| Auth/account/session architecture | Not yet directly audited this session | N/A | Sampled indirectly via `is_admin()`/role-immutability trigger review | Dedicated auth/session/OAuth-callback audit still open |
| Supabase/backend/RLS | ~90 (of sampled scope) | N/A | Session 1 (RLS bulk-enable pattern, webhooks, evidence vault, blocking) + Session 2 (identity, guardian, moderation, 663-function search_path sweep) | Full RLS policy-predicate re-derivation across all 195 migrations; storage bucket policies beyond vault/evidence; remaining un-sampled RPCs |
| Safety systems | 1 real P1 found and fixed (guardian-invite brute-force) | N/A | `MORT_BACKEND_SAFETY_AUDIT_SESSION2.md` Track 4; fix in commit `f9f5861`/`a1be570` | Fix not yet executed against a live/staging Postgres (no local DB tooling available) — recommend staging verification before deploy |
| Moderation architecture | 100 (of sampled scope) | Staffing = BLOCKED_EXTERNAL | Staff role provisioning requires admin + bounded 90-day expiry + training/confidentiality/conflict/device-compliance gates before access grants | Deeper review of report/escalation/appeal UX flows not yet done |
| Financial Safety (teen earnings feature) | NOT ON MAIN | N/A | Feature exists only as uncommitted WIP on the branch tied to PR #4 (not touched per instruction) | Cannot be scored until/unless that branch is reconciled into this one |
| Financial Safety (backend Stripe operations controls) | 100 (of sampled scope) | Live money movement = BLOCKED_EXTERNAL (no provider credentials) | DB-level fail-closed live-gate constraint (`stripe_runtime_phase12_live_gate`), idempotent incident recording, receipt truth-in-labeling, deletion-retention hold | None found in sampled scope |
| Payment/dispute architecture | 100 (of sampled scope) | Live payments = BLOCKED_EXTERNAL | Idempotency keys on all Stripe calls, DB-enforced reviewer/operator separation of duties | Full dispute-decision → payout-adjustment path not traced end-to-end |
| Identity verification architecture | 100 (of sampled scope) | Live identity provider = BLOCKED_EXTERNAL | Fail-closed without provider config; SSRF-safe handoff-host allowlisting; bounded 30-min handoff TTL | None found in sampled scope |
| Android implementation | Baseline verified | Release signing = BLOCKED_EXTERNAL (owner keystore) | `flutter build apk --debug` succeeds; `--release` correctly fails closed with no keystore (`android/app/build.gradle.kts:60-64`) | Manifest/permissions/deep-link/ProGuard deep audit not yet done (Track 8, next) |
| iOS source implementation/parity | Not yet audited this session | Xcode build = BLOCKED_EXTERNAL (Windows host) | — | Needs macOS CI workflow (Track 9, next) before any build/QA evidence is possible |
| iOS/Android real-device QA | 0 | BrowserStack account = BLOCKED_EXTERNAL | No credentials configured (checked env + `gh secret list`) | Full BrowserStack setup + device matrix (Tracks 10-11) |
| UI/design system/V6 polish | Not yet audited this session | N/A | — | Not started |
| Automated tests | Baseline green | N/A | 448 passed/2 skipped/0 failed on every regression run so far | No new automated backend test harness exists (pgTAP/SQL) — flagged as a gap, not fixed (would be new infrastructure, out of scope for a targeted audit) |
| Legal/compliance implementation | Partially verified | Final legal approval = BLOCKED_EXTERNAL | Public legal site build+validate scripts pass (13 routes) | Full legal-acceptance/re-consent flow audit not yet done |
| Technical public-launch readiness | In progress | Multiple external gates (see `MORT_EXTERNAL_RELEASE_GATES.md`) | — | Android/iOS/BrowserStack tracks remaining |

## What "100 (of sampled scope)" means

This program samples the highest-risk paths in each area first (per the task's own
priority ordering) rather than re-deriving every line of every migration. A "100 (of
sampled scope)" entry means: everything actually inspected in that area was verified
correct, with no shortcuts taken to make it look done. It is not a claim that literally
every function/policy/screen in that category has been individually re-reviewed — the
"remaining internal work" column says exactly what has not yet been looked at.
