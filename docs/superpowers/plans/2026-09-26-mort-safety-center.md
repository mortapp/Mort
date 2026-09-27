# MORT Safety Center Implementation Plan

Execution: one agent, sequentially, as explicitly required by the user. The
supplied execution spec is the design; no additional approval gate is needed.

**Goal:** Finish free, private, server-controlled Safety flows in the current UI,
then return to the preserved paywall release work.

**Architecture:** Extend canonical safety pings, job check-ins, location shares,
incidents, evidence and notifications. Keep device/session telemetry private and
job state separate. Expose recipient-specific RPC projections and accept only
authenticated, role-checked, payload-bound mutations.

**Spec:** `docs/safety/MORT_SAFETY_EXECUTION_SPEC.md` and
`docs/skills/mort-safety-system/SKILL.md`.

## Global constraints

- Current black/white/silver/cool-blue UI; no unrelated redesign.
- Opening Emergency sends nothing; local call/leave actions remain reachable.
- Never label a queued push as recipient delivery; no emergency dispatch claim.
- No precise poster GPS, guardian covert tracking, or device-loss penalties.
- No ads, Pro gates, companion overlays, or decorative emergency motion.
- Additive migrations only; Docker `mort-mobile` only; production stays gated.

## Review focus

1. Network loss after a mutation commits: stable request IDs prevent duplicates.
2. Recipient revocation/age-out during sharing: access stops immediately.
3. Offline versus online missed checks: family escalation uses separate states.
4. Text scale, small screens and pending calls: emergency controls remain usable.
5. Safety exit with a failing provider: locally leave now, preserve a queued
   event, never claim server completion or change money/progression locally.

## Deliverables in order

- [x] Emergency panel and calm Safety Center: focused widget tests must first
  fail for missing explicit Emergency/zero-send behavior, then pass through the
  real widget callbacks. Split safety presentation out of mort_screens.dart;
  preserve routes and canonical repositories.
- [x] Private runtime and six-minute worker: extend canonical pings/check-ins,
  add authenticated device snapshot RPC and service-only 2/5/15 worker. Test
  first miss, second miss, offline boundaries, replay, banned users, outsider
  access, no routine trusted alerts, and no money/progression mutation in Docker.
- [x] Explicit 60-minute sharing and manual travel: canonical location sessions,
  recipient-only authorized projections, expiry/stop/extend/reconnect consent,
  privacy-safe poster ETA and reschedule paths; deny recipient start/extend.
- [x] Battery/location/outbox: real native readings, qualitative budget, saver
  integration, adaptive updates, encrypted account-scoped queued events; test
  critical thresholds and account-switch isolation. Document OS execution limits.
- [x] Safety Exit/finish check/review hold: reuse canonical cancellation/cases,
  protect ratings/messages/no-show/completion while retaining disputes and
  payments. Test no Finish PIN required and no poster teen-side override.
- [x] Guardian/trusted/poster/admin/report UX: use scoped RPCs and canonical
  evidence/roles, add event-only Safety Contact, multi-select optional-text
  reports, audit access and retain reports after upload failures.
- [ ] Verify format/analyze/full regression, Docker RLS/storage/adversarial,
  Android/iOS parity, rendered screens, secrets and diff; sequential
  Believer/Skeptic/Investor/Judge review. Keep device/provider/operations/legal
  gates distinct and production disabled.
- [ ] Finish preserved paywall refinement, exact-head CI and QA artifact; Play
  release remains dependent on highest uploaded version and licensed-device
  purchase evidence. Artifacts belong under `C:\Users\micha\Mort`.

## Verification boundary on 2026-09-27

Checked implementation items mean code and the documented local contracts are
verified. They do not mean hosted deployment, recipient device delivery, a
terminated-app location service, Google Routes configuration, physical-device
battery/calling checks, Play purchases or operational/legal approval succeeded.

The combined Flutter suite passed 733 tests with two existing skips. Analysis of
lib, test, integration_test and tool reported no issues. Actual authenticated
local Docker Safety, PIN concurrency, cancellation, evidence, messaging,
reporting, cross-user RLS, parity contracts and migration encoding checks passed.
Exact committed-head CI and native builds remain a separate completion gate.

Paywall appearance refinement is implemented and its focused contracts passed.
The visual preview uses labelled sample prices, not RevenueCat purchase proof.
