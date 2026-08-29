# Claude ↔ Codex Integration Notes

Running log of stale production-identity copy Claude found but did not fix,
because it falls inside Codex's primary assignment (removing shipping
user-facing "closed pilot / closed test / closed beta / free pilot /
server-controlled access" identity), not Claude's lane (backend/policy
substance). See the coordination rules in the production-completion
directive for why this split exists.

## 2026-08-29: `scripts/build-public-legal-site.mjs` (public policy website generator)

This file is the source for a fully-built, CI-validated, but never-deployed
public Privacy/Terms/Child-Safety/Deletion website (see
`docs/PUBLIC_POLICY_SURFACE_INVENTORY.md` surface 1). It is a **web** surface
per Codex's stated scope ("shipping Flutter/UI/web/copy surfaces"), so its
closed-pilot wording belongs to Codex's purge, not a Claude fix — flagging
here instead of touching it.

Stale identity language found (all in `scripts/build-public-legal-site.mjs`):

- Line 152: page header badge on **every** page — `MORT <span>Closed pilot</span>`
- Line 154: status line on **every** page — `Published - closed-pilot draft, pending qualified legal review`
- Line 158: notice box on **every** page — `MORT is a restricted 13+ pilot. It does not guarantee identity, safety, jobs, or payment...`
- Line 175 (index meta description): `...for the MORT closed pilot.`
- Line 176 (index body): `MORT is a controlled 13+ pilot for local work coordination... require server-approved pilot enrollment.`
- Line 180 (privacy meta description): `How the MORT pilot collects, uses...`
- Line 185 (terms meta description): `Core service terms for the restricted MORT closed-pilot service.`
- Line 186 (terms body): `Downloading MORT does not grant marketplace eligibility.` — implies a gated/enrollment marketplace model; needs to become ordinary eligibility language (age/role/verification-based) once the marketplace isn't described as pilot-gated
- Line 211 (prohibited-jobs body): `Pilot eligibility never overrides labor, licensing, wage, safety, or supervision law.` — "Pilot eligibility" → "Marketplace eligibility" or similar
- Line 220 (support meta description): `...and pilot support routes for MORT users and reviewers.`

**Constraint that makes this non-trivial, not just find/replace**: the
current shipping build (`scripts/build-standard-closed-test-apk.ps1`) really
does run with `-PublicMarketplaceEnabled $false` today — the marketplace
genuinely is gated right now. Per Policy Truth Law, the copy can't just claim
the marketplace is open if it isn't. The fix isn't "delete every 'pilot'
word" — it's rephrasing from *permanent pilot-product identity* ("MORT is a
pilot", a badge that will still say "Closed pilot" after Play's closed-testing
window ends) to *ordinary, temporary rollout language* ("some marketplace
features activate as your account becomes eligible") that will still be true
and won't need a rewrite the day distribution moves out of Play's closed
track. Whoever does this pass should re-check `PublicMarketplaceEnabled`'s
actual value at that time rather than assuming it's still `false`.

**Claude's fix in this same file** (policy substance, not copy — see
`docs/PRODUCTION_DATA_FLOW_MAP.md` Google Sign-In entry): added a Google
Sign-In disclosure line to the privacy page, since Google Sign-In is
genuinely active in production (`GoogleAuthEnabled $true` in the current
build) and was not disclosed anywhere in the drafted copy. This is a real
missing-disclosure defect, not a wording-style purge, so it stayed in
Claude's lane.

## How to use this file

Add a new dated section per finding. When Codex's purge branch
(`codex/production-identity-purge`) is integrated, cross off entries it
resolved rather than deleting the section — the history of what was found
and when is useful for the final certification's production-identity-purge
verification pass.
