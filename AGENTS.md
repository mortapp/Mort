# AGENTS.md — MORT / Codex Execution Rules

This repository is MORT, the teen-safe local work marketplace. The authoritative production client is `flutter_mort`.

## Primary execution blueprint

Before making product changes, read:

- `docs/blueprints/MORT_MASTER_EXECUTION_BLUEPRINT.md`
- the source files and release/security documents it cites
- the exact code you intend to change

The blueprint is the execution contract. Do not replace it with a looser prompt.

## Single-agent rule

Do **not** spawn sub-agents, delegated agents, agent councils, parallel agents, or other model workers. They consume unnecessary usage and can drift from the same source of truth.

When a multi-perspective audit is requested, perform it sequentially inside this same agent:
1. Believer pass
2. Skeptic pass
3. Investor/operations pass
4. Judge pass

Each pass must inspect the same exact diff and test evidence. The Judge may not overrule a concrete failing test or unresolved security defect.

## VS Code permission

You are explicitly allowed to use VS Code and its integrated capabilities when useful, including:
- editor/search/refactor
- integrated terminal
- Flutter/Dart tooling
- test runner
- Git tooling
- Android tooling/emulators when available
- Xcode/macOS tooling only when the environment actually provides it
- Supabase/GitHub tooling already authorized in the environment

If a task cannot be completed in the current environment, use the best available VS Code/repo workflow to prepare it, record the exact external blocker, and continue all independent work. Never claim an external step succeeded without evidence.

## Engineering behavior

- Inspect before editing.
- Prefer additive migrations.
- Never rewrite applied migration history.
- Never ship service-role secrets, Stripe secret keys, webhook secrets, Apple signing secrets, RevenueCat secret keys, or other privileged credentials to Flutter/Expo.
- Never trust the client for XP, rank, tokens, payments, payouts, verification, entitlements, moderation, or safety-critical state.
- Use server-authoritative/idempotent transitions.
- Keep RLS enabled and prove cross-user isolation.
- Keep production gates fail-closed unless the corresponding real approval/provider configuration exists.
- Flutter is authoritative. Expo/Swift/reference trees may be used as design or contract references only unless the blueprint explicitly changes that boundary.
- Android and iOS must remain functionally aligned unless a platform difference is documented and tested.
- Do not weaken teen safety, verification privacy, moderation, payment, retention, or account-deletion protections to make CI pass.

## Mandatory completion loop

Before saying a blueprint phase is done:

1. Review the full diff.
2. Run formatting/lint/static analysis.
3. Run focused tests for the changed area.
4. Run the full relevant regression suite.
5. Run security/RLS/adversarial tests for any changed trust boundary.
6. Run Android/iOS parity checks when shared Flutter/native behavior changed.
7. Run secret scanning and `git diff --check`.
8. Perform the sequential Believer/Skeptic/Investor/Judge audit.
9. Fix every reproducible defect found.
10. Re-run the failed/affected checks after each fix.
11. Only then record completion evidence.

A phase is not complete because code exists. It is complete when the exact committed head has evidence.
