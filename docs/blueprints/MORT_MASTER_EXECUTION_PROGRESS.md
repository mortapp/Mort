# MORT Master Blueprint Execution Progress

Blueprint: `docs/blueprints/MORT_MASTER_EXECUTION_BLUEPRINT.md`
Execution branch: `feature/mort-master-blueprint-gamification`
Execution mode: single Codex agent, no sub-agents.

## Baseline

- [x] Recovered original MORT gamification/product direction from historical project material.
- [x] Confirmed existing leaderboard v1 is present and server-authoritative.
- [x] Confirmed current MORT monetization, Stripe, RLS, Verify, Android, and iOS work must be preserved.
- [x] Added root `AGENTS.md` enforcing single-agent execution and final bug-fix/self-audit.
- [x] Added master execution blueprint.
- [ ] Codex implementation inventory against exact branch head.
- [ ] Progression schema/migration.
- [ ] XP/rank/Motion Token backend.
- [ ] Badge/streak/goal backend.
- [ ] Gamification adversarial QA.
- [ ] Flutter progression data layer.
- [ ] Original rank/token/badge assets.
- [ ] Progression Hub + level/rank UX.
- [ ] Leaderboards v2.
- [ ] Motion Token cosmetics.
- [ ] Privacy-safe milestone share cards.
- [ ] RevenueCat/progression boundary regression.
- [ ] Ads/progression boundary regression.
- [ ] Stripe/progression boundary regression.
- [ ] MORT Verify/progression boundary regression.
- [ ] Android parity/build.
- [ ] iOS parity/build.
- [ ] RLS/security full audit.
- [ ] Full CI on exact head.
- [ ] Sequential Believer pass.
- [ ] Sequential Skeptic pass.
- [ ] Sequential Investor/operations pass.
- [ ] Sequential Judge pass.
- [ ] Fix every reproducible audit defect and rerun affected tests.
- [ ] Final exact-head evidence report.

## Current rank design

- Bronze: levels 1–10
- Silver: levels 11–20
- Gold: levels 21–30
- Platinum: levels 31–40
- Diamond: levels 41–50, highest rank

## Current reward design

- +1 Motion Token per crossed level
- +5 on entering Silver
- +10 on entering Gold
- +15 on entering Platinum
- +25 on entering Diamond

Motion Tokens are cosmetic-only, non-cash, non-transferable, and cannot buy XP, rank, job priority, verification, safety, or payment advantages.

## Hard execution notes

- Codex may use VS Code for edits, refactors, terminal commands, debugging, Flutter, Git, and available device tooling.
- Do not use sub-agents.
- Do not activate live Stripe, real minor-ID collection, public marketplace, or other external gates merely to complete this blueprint.
- Any external blocker must be written here with concrete evidence.
