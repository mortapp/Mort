# MORT living archive

This is the source for the procedural rain/glass environment and semantic reading shell at `legal.mortapp.org`. The existing Vercel project is `mort-legal`; the repository is `mortapp/Mort`, branch `main`. The main application lives separately in `mortapp/mort-web`.

## Build and check

Run `npm ci` in this directory, then `npm test`, `npm run check`, and `npm audit`. Run `npm run build` with the existing publisher metadata and public Supabase anon configuration documented in `scripts/build-public-legal-site.mjs`. The pinned root Supabase browser bundle must also be installed. The generator validates the project and public key role. Never use a service-role credential.

Output is `web/public`: thirteen HTML routes, self-hosted Three.js bundle, styles, unchanged account-deletion logic, public configuration, and equivalent Netlify/Vercel security headers. The generator retains the output directory handle for Windows preview servers while replacing its generated contents.

Serve that directory with `python -m http.server 4175 --bind 127.0.0.1 --directory web/public` from the repository root, or use an absolute output path. Then run `npm run test:browser` here. Install Chromium with `npx playwright install chromium` if unavailable. `LEGAL_QA_URL` overrides the default local URL. Browser evidence is written to ignored `qa-artifacts/`.

The browser runner checks all thirteen routes, eight widths from 390 to 2560 pixels, idle image change, frozen pause, persistence, primary drag, hover/right exclusion, touch intent and native scroll, WebGL loss and keyboard skip navigation. It never submits deletion or authentication forms.

## Visual and interaction design

Receding original glass leaves, reflected architectural frames, falling line-segment rain, water shaders, mist, light breathing and scroll framing replace the documentation-card overview. Contents remain HTML with native links, focus, text selection, anchors and forms. Document wording and all account-deletion behavior are retained.

Only held primary input drives bounded velocity. Touch requires horizontal intent in the hero; vertical gestures remain native scrolling. Release decays, cancellation clears, fields and links are excluded. Reduced motion renders one static composition; manual pause persists across routes. Hidden pages stop the animation loop. Resize reframes mobile architecture, and context loss exposes the composed CSS fallback.

## Verification scope

Clean install, three unit tests, syntax checks and dependency audit passed. All thirteen public routes and the reading/form layouts were browser reviewed. The account-deletion script has SHA-256 `FBB5828562B24969BF8246B5576F1715B3F9813CBD2E10049484CDDEA571D5CF`, identical to the existing deployed source. The restored public configuration matches that source and returned HTTP 200 from the read-only Supabase auth settings endpoint.

No production users were created, no messages were sent and no account was deleted. Completing an authenticated deletion request is deliberately outside this visual QA run.
