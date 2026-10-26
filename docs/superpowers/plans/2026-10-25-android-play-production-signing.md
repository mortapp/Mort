# Android Play Production Signing Readiness Plan

> **For agentic workers:** Execute inline in the current Mort worktree. Preserve the existing upload key and all release gates.

**Goal:** Make the canonical Android signing guide accurately describe MORT's granted Google Play production access and the distinct server/build prerequisites for an actual public-production AAB.

**Architecture:** Continue using the existing Flutter Android Gradle signing configuration and shared PowerShell release-profile builder. Documentation will distinguish Play Console eligibility from a production artifact and published rollout; the existing server-side activation gates remain authoritative.

**Tech Stack:** Flutter, Android Gradle, PowerShell release scripts, GitHub Actions, Supabase release-mode RPC.

**Spec:** User-provided Google Play production-access email and dashboard screenshots, plus current repository release scripts and profile validation.

## Global Constraints

- Work only in `C:\Users\micha\Mort\.worktrees\mort-production-readiness`; do not use `mort-web-main`.
- Never display or commit signing passwords, private keys, or DPAPI credential contents.
- Do not change or bypass the profile/server gates for public production.
- Keep the Play production-access state distinct from public marketplace/backend activation and release publication.

## Review Focus

- Google Play production access may be granted before a public-production artifact or rollout exists.
- Closed-test and pilot artifact profiles must not be described as the current Play track state.
- Public-production artifact building must continue to require server-approved production stage, marketplace, identity, and activation state.
- The currently recoverable upload key must remain the configured signer; never generate a replacement.
- CI availability of signing credentials is distinct from local DPAPI recovery.

---

### Task 1: Correct the canonical Android signing and release guide

**Files:**
- Modify: `docs/mobile/MORT_PLAY_SIGNING_SETUP.md`

**Interfaces:**
- Consumes: `scripts/build-standard-closed-test-aab.ps1`, `scripts/build-production-pilot-aab.ps1`, `scripts/build-production-public-aab.ps1`, and `scripts/validate-release-profile-server.mjs`.
- Produces: a truthful guide that states Play production access is granted, identifies each available build profile, and lists the live/server conditions required by the public-production builder.

- [x] Replace the stale closed-test-only status with the granted Play production-access status while stating that access alone does not prove a new public-production AAB or rollout exists.
- [x] Document the closed-test, production-pilot, and public-production build entry points and their separate server-gated purposes.
- [x] Preserve all current signing instructions and credential-safety rules.
- [x] Verify every documented script and gate against the checked-in source; run whitespace/diff validation and confirm the worktree contains no signing material.
- [x] Commit the verified documentation and plan update.
