# MORT Public Legal/Support Site Deployment (Vercel)

**Canonical hosting is Vercel, not Netlify.** This file was originally written
for a planned Netlify deployment; that never happened and Netlify is not the
target. The Netlify config files (`web/netlify.toml`, `web/public/_headers`,
`web/public/_redirects`) are kept only because they're harmless and some
tooling still references them -- they are not the deployment path.

## Live deployment (2026-08-19)

Deployed via browser control (Vercel Drop) to a new, dedicated Vercel project
under the `mortapphelp-7067s-projects` team:

- **Live URL: https://mort-legal.vercel.app/**
- Project name: `mort-legal`
- Deployed from a zip of `web/public/` (the exact output of
  `scripts/build-public-legal-site.mjs`), not connected to any Git repo --
  this repository has no CI/CD wired to auto-deploy it, so future content
  changes require rebuilding and re-uploading through this same flow (or
  connecting a Git repo in the Vercel project's Settings > Git, and pushing
  `web/public/` as its own tracked repo, if that's ever preferred).

All 13 routes verified live and rendering (no login required, mobile-usable,
correct MORT branding): `/`, `/privacy/`, `/terms/`, `/terms-of-use/`,
`/community-guidelines/`, `/safety/`, `/child-safety-standards/`,
`/prohibited-jobs/`, `/payment-disputes/`, `/account-deletion/`, `/support/`,
`/contact/`, `/accessibility/`. `/app-ads.txt` also verified live, serving
the real, confirmed AdMob publisher line.

A separate, deliberately-kept-empty `mort-legal-site` project and an
abandoned, never-deployed `mort-legal-site-1` flow also exist in the same
Vercel team from earlier attempts this session -- neither is referenced
anywhere and both are safe to delete later; deleting a Vercel project
requires typing its name to confirm, which this session's safety classifier
correctly blocks as a destructive action, so that cleanup is left for the
owner.

## Real bug found and fixed by actually testing the deployed site

`assets/account-deletion.js`'s trailing `await showSession();` was a
top-level `await` inside a plain (non-`module`) `<script>` tag, which throws
`SyntaxError: await is only valid in async functions and the top level
bodies of modules` -- the entire script failed to execute, so the
account-deletion page's real Supabase-backed deletion flow was completely
non-functional. Never caught before because the site had never actually been
deployed and opened in a browser with the console checked. Fixed in
`scripts/build-public-legal-site.mjs` (`void showSession();` instead of
`await showSession();`, matching the existing fire-and-forget pattern used
one line above). Verified fixed on the redeployed live site: page renders,
the account-email form is present and enabled, no console exceptions.

## Real, non-fabricated values used for this deployment

The build script gates on `MORT_PUBLIC_PUBLISHER_NAME` /
`MORT_PUBLIC_SUPPORT_EMAIL` / `MORT_PUBLIC_PRIVACY_EMAIL` /
`MORT_PUBLIC_CHILD_SAFETY_EMAIL` / `MORT_PUBLIC_WEBSITE_URL` /
`MORT_PUBLIC_EFFECTIVE_DATE` and refuses to produce a "deployment ready"
build (shows a visible blocker banner instead) until all six are set. Used:

- `MORT_PUBLIC_PUBLISHER_NAME=MORT` -- matches the actual registered Google
  Play Console developer/publisher name ("Mort", Account ID
  `7973453050111247195`), confirmed live in Play Console, not invented.
- `MORT_PUBLIC_SUPPORT_EMAIL` / `MORT_PUBLIC_PRIVACY_EMAIL` /
  `MORT_PUBLIC_CHILD_SAFETY_EMAIL=mortapp@googlegroups.com` -- the real,
  existing canonical MORT Google Group (same one already used as the
  Play closed-testing tester group and as the Google OAuth consent screen's
  support email). Reused across all three contact purposes since no
  separate dedicated addresses exist yet -- **the owner may want to split
  these into distinct mailboxes later**, especially a dedicated child-safety
  contact, but reusing the one real group is honest, not fabricated.
- `MORT_PUBLIC_WEBSITE_URL=https://mort-web.vercel.app` -- the real, live
  MORT product/marketing site (confirmed as the Site URL already configured
  in Supabase Auth).
- `MORT_PUBLIC_EFFECTIVE_DATE=2026-08-19` -- today's date, a reasonable
  default, not a confirmed legal-review effective date. The owner/counsel
  should set a deliberate effective date once the legal drafts are actually
  reviewed and approved; this is not a legal-compliance claim.

None of the 13 pages claim legal approval or public-production readiness --
`release-status.json`'s `legalApprovalClaimed`/`publicDeploymentClaimed`
both remain `false`, and every page still carries a closed-pilot disclosure.

## Stale-wording fix and repo/live drift found (2026-08-20)

Auditing the 13 live pages found the status badge and two body strings still
read "Production-pilot publication candidate" -- accurate language for a
package awaiting a publish decision, but stale now that the package has
actually been deployed and is serving real traffic (including the real
Supabase-backed account-deletion flow). Fixed in
`scripts/build-public-legal-site.mjs`: the badge now reads "Published -
closed-pilot draft, pending qualified legal review" (accurate on both
fronts -- it is genuinely live, and the legal content is genuinely still
unreviewed by counsel, matching the LEGAL row's status). The privacy page's
"This publication candidate covers..." and the terms page's meta
description ("...production-pilot candidate") were also updated to drop the
stale "candidate" framing without changing scope or claims.

Rebuilding also surfaced that the git-committed `web/public/` output had
drifted from the actual live site: it was last committed in the
`deploymentReady: false` state (built without the six `MORT_PUBLIC_*` env
vars, showing the release-blocker banner and "pending - deployment blocked"
placeholders), while the real live deployment was zip-uploaded directly to
Vercel with real config and never committed back. Rebuilt with the same six
real values documented above (unchanged) and committed, so the repo now
matches what is actually live. **Not yet redeployed to Vercel** -- pushing
new content to the live `mort-legal.vercel.app` project is a public-content
change and needs the owner's go-ahead before uploading the new build.

## Also added this session

- `vercel.json` generation (replacing reliance on Netlify's `_headers`
  format): same CSP/security headers, translated to Vercel's format.
- `app-ads.txt` generation using the real, confirmed AdMob publisher ID:
  `google.com, pub-9883419411387958, DIRECT, f08c47fec0942fa0`.

## Still needed (owner-only)

1. Enter `https://mort-legal.vercel.app/privacy/` and
   `https://mort-legal.vercel.app/terms/` (or equivalent) into Play
   Console's Privacy Policy / relevant declaration fields, and
   `https://mort-legal.vercel.app/account-deletion/` wherever Play asks for
   an account-deletion URL. Not done this session -- Play Console
   declarations are exactly the kind of "irreversible Play declaration"
   this session treats as owner-controlled, not something to submit
   unilaterally.
2. Decide whether to add a custom domain (e.g. `legal.mortapp.com`) instead
   of the `.vercel.app` default -- optional, not required for functionality.
3. Consider splitting the three reused contact emails into dedicated
   mailboxes if desired.
4. Clean up the two unused/abandoned Vercel projects
   (`mort-legal-site`, `mort-legal-site-1`) when convenient.
