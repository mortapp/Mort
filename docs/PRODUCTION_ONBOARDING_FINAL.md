# Production Onboarding Contract

Status: Stage 1 implementation candidate. The client and forward-only migration are implemented; production activation is blocked by the conditions in `KNOWN_ISSUES.md`.

The production Flutter client has exactly four primary onboarding screens:

1. `account` — DOB, role, display name, username, privacy-safe general area, and supported adult account metadata.
2. `work_preferences` — teen categories, availability, and transportation; adults and guardians receive no invented required fields.
3. `safety_support` — safety essentials, optional teen Guardian Mode choice, and notification intent. Native notification permission remains device truth.
4. `review` — one Review & finish screen with current versioned legal requirements and one Finish action.

`complete` is a terminal server state, never a fifth user-facing step. Flutter renders `get_my_onboarding_progress_v2()` and reconciles after every save. Local fields are drafts only.

The v2 migration is additive. It does not mutate the legacy 12-step enum or remove legacy RPCs. Existing supported clients retain their contract during Release N; the Flutter production candidate uses v2 exclusively. Legacy retirement requires a later, separately approved forward migration after usage evidence proves the minimum supported legacy-client window has elapsed.

Completion is derived from canonical server data. `complete_my_onboarding_v2()` locks the caller's profile, reruns account, role-specific work, safety-support, and current legal-version checks, then uses the existing transaction-local completion guard. Direct authenticated `UPDATE`/`UPSERT` remains denied.

Request identity is scoped by authenticated user, operation, step, request UUID, payload version, and canonical payload hash. Same-payload replay returns the stored result; a changed payload with the same request identity is rejected; cross-user IDs are independent; advisory transaction locks serialize concurrent retries and Finish calls.

The Expo project is reference-only. Its onboarding route no longer writes completion, and the Expo production build profile fails closed. Flutter is the sole supported production client.

Job payment and digital MORT purchases remain distinct: MORT does not process or escrow local job payment; optional subscriptions and digital upgrades may be billed through Google Play. Onboarding contains no paywall.
