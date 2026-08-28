# MORT 0.9.14+104 Final Readiness Report

Updated: 2026-08-09 (America/Indianapolis)

## Superseding 0.9.15+105 Status

**ANDROID CLOSED-TEST ENGINEERING CANDIDATE VERIFIED - OWNER LEGAL AND STORE
APPROVALS REMAIN**

This section supersedes the physical-QA status below while preserving the
immutable `0.9.14+104` record. MORT is not production-ready and the public
marketplace remains closed.

- Current runtime commit:
  `79630b195098a2c5428a30104b55cfec27ea764f` (`gitDirty=false`).
- One authorized fresh-auth QA reset cleared only MORT local app data on the
  Samsung SM-A146U. It did not uninstall MORT, clear Google/Chrome data, or
  modify hosted account data.
- The real Google/Supabase PKCE flow used the authorized Google QA account. A
  private chooser capture was retained only under ignored `artifacts/`.
- The exact final signed APK returned from Google to MORT, showed the
  authenticated onboarding status, and resumed the server-persisted Safety
  step. There was no OAuth loop, blank screen, crash, router error, or secure
  startup failure.
- Final callback and cold-start log windows contain zero `TransformLayer`,
  invalid-matrix, `E/flutter`, fatal exception, ANR, `GoException`, route-not-
  found, `RenderFlex`, or predictive-back warning entries.
- Five post-OAuth force-stop/cold-start cycles all began with no PID, reported
  `COLD`, restored the Safety step, kept MORT foreground, and did not reopen
  OAuth. Three Home/resume cycles and the 1.3 text-scale Safety pass also
  passed; font scale was restored to `1.0`.
- Screen off/on preserved the MORT process. Samsung then presented its secure
  keyguard, so no PIN bypass was attempted. Physical offline cold start was not
  attempted because wireless-only ADB would be severed.
- The legitimate account role is Teen. Completion stops at owner-controlled
  safety/legal acknowledgements. No DOB, legal acceptance, identity,
  guardian, address, or payment data was invented. Teen dashboard, Messages,
  and Settings hardware journeys therefore remain unavailable until the owner
  completes that step; their automated suites pass.
- Adult Back was not applicable because the authorized account is not Adult.

Two additional physical defects were repaired in `0.9.15`:

1. Legacy profiles with validated DOB/role but no resumable progress could not
   save Profile. Migration `20260809040544` now bootstraps only validated,
   non-legal onboarding prerequisites and is applied remotely.
2. Post-OAuth Account Status routed incomplete users into the obsolete compact
   wizard while cold starts used the server resume path. Account Status and
   role guards now share `get_my_onboarding_progress` and route to its persisted
   `resume_path`; the final APK physically resumes Safety.

Current verification:

- Focused auth/onboarding/Back suite: 44 passed.
- Flutter analyzer: no issues.
- Full Flutter suite after the final runtime change: 352 passed, two intentional
  provider-gated skips, zero failed.
- Expanded hosted Supabase regression: all 46 scripts passed; migration parity
  is current through `20260809040544`; linked lint and security advisors report
  no error-level findings.
- APK: 69,287,402 bytes; SHA-256
  `A4578C163638A952B8C1B9F6BE8CC190B3F38D1C7B927A5F4AEA200C6E918E10`.
- AAB: 52,164,950 bytes; SHA-256
  `84758C39817B42129282CBD74BD9FAC2B37854CCEA04EC4CA81946793DFFA144`.
- Package `com.mortapp.mobile`, version `0.9.15+105`, min SDK 24, target SDK
  36, upload signing, 11-permission policy, artifact secret scan, and 18/18
  native-library 16 KB alignment all pass.

## Historical 0.9.14 Verdict

**NOT RELEASE READY - BLOCKING PHYSICAL VERIFICATION AND EXTERNAL GATES REMAIN**

The code-controlled closed-pilot candidate is substantially complete and its
automated, hosted-backend, API 36 emulator, signing, permission, and 16 KB checks
pass. It is not production-ready. The repaired OAuth/account-status transition
has not yet completed its required physical Samsung retest, the exact current
APK has not completed the authenticated role matrix on hardware, and legal,
provider, staffing, and Play Console decisions remain external.

## Scope And Provenance

- Authoritative app: `flutter_mort/`
- Package: `com.mortapp.mobile`
- Version: `0.9.14+104`
- Hosted Supabase project: `rakjydmgwwgtdislanbt`
- Signed APK/AAB runtime source commit:
  `909a4235268ee16b2d6884862c0236cbec632b4b`
- Both artifact manifests recorded `gitDirty=false`.
- Later commits change QA scripts, integration tests, and documentation only;
  they do not change shipped Flutter runtime code.
- Release profile: `closed_test` / `closed_pilot`
- Public marketplace, real identity verification, payments, ads, IAP, remote
  push, crash reporting, and public activation are fail-closed.

## Code-Controlled Completion

- Unified public sign-in and account creation use the same Liquid Glass shell.
- Email/password, Google PKCE launch/callback, password recovery, session
  restoration, logout, and account-state routing are implemented.
- DOB is saved through the caller-bound server RPC; under-13 registrations are
  rejected with the canonical `under_13_not_eligible` result.
- Teen, Adult/Business, Guardian, Admin, Moderation, and Support routes are
  role-gated.
- Teen Discover, Applications, Safety, Messages, Profile, Saved Jobs, and
  Notifications destinations are routable and connected to repositories.
- Adult dashboard, job creation, job management, applicant review, messaging,
  settings, and profile routes are implemented.
- Guardian linking, privacy boundaries, safety state, dashboard, and settings
  are implemented. Guardian Mode remains optional.
- Messaging has participant/job context, keyset pagination, realtime lifecycle
  cleanup, unread state, report/block, visible retry, text-only attachment
  boundary, and server-enforced membership isolation.
- Safety Center, Safety Ping, PIN start/completion, reports, emergency intent,
  role scoping, and fail-closed state transitions are implemented.
- Settings persist motion, transparency, contrast, haptic, notification,
  privacy, security, blocked-user, support, legal, logout, and deletion paths.
- Payment preference only is implemented. MORT does not process payment,
  escrow funds, or claim payment completion.
- Real ID collection is disabled. Verification architecture exists, but no real
  provider is connected. Sandbox verification remains QA-only.

## Automated Verification

### Hosted Backend

- `scripts/run-final-supabase-regression.ps1`: exit 0; 45/45 scripts passed in
  511.7 seconds. One transient hosted fetch retried once; the full suite then
  passed. Isolated QA users were removed.
- Linked migrations match remote through `20260808010000`.
- Linked migration dry run reports the hosted database is up to date.
- `public,private` schema lint: exit 0; no error-level findings.
- Supabase advisors: exit 0; no error-level findings.
- Storage audit: nine buckets, all private; 18 object policies; identity bucket
  empty.
- Mission pilot: 25 tables with RLS enabled; no anonymous privileges; provider
  gates disabled.
- Leaked-password protection is classified as
  `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`. Supabase Free does not provide
  the HaveIBeenPwned control. This is not an unresolved code bug. Enable it
  immediately after a Pro upgrade and rerun Auth security advisors.

### Flutter And Android

- Dart format: exit 0; 226 source/test files required no changes in the final
  full pass. The native integration test file is also formatted.
- Flutter analyzer: exit 0; no issues.
- Full Flutter suite: exit 0; 349 passed, two intentional provider-gated skips,
  zero failed.
- Focused secure-startup/navigation suite: exit 0; 19 passed.
- Android native integration on `Medium_Phone_API_36.1`, API 36, x86_64,
  host GPU: exit 0; two test bodies passed.
- Exact signed APK API 36 cold launch: exit 0; process alive, MainActivity
  resumed, and fatal Android/Flutter scan passed.
- Android release lint: exit 0; 703 tasks, build successful.
- Native alignment: exit 0; all 18 APK libraries have at least 16 KB ELF LOAD
  alignment.
- Play release QA: exit 0; release profile, feature gates, age gate, reviewer
  isolation, UGC, deletion, data safety, permission minimization, networking,
  deep links, debug removal, marketplace lock, binary secret scan, and AAB
  signer all passed.

### Expo Reference And Dependencies

- Frozen pnpm install, Expo dependency compatibility, Expo Doctor 20/20,
  TypeScript, lint, and 48-route static web export passed.
- Flutter lockfile was refreshed within existing dependency constraints.
- `pnpm audit --prod` retains three upstream build-tool advisories: two high
  `image-size` findings in Metro with no patched release, plus one moderate
  `uuid` finding in Expo's Xcode parser whose vulnerable buffer API is not used
  on the exercised path. These are documented supply-chain residual risks, not
  observed MORT runtime failures.

## Defects Found And Repaired

- Public auth child routes could leave a stale or incorrect root stack. Fixed
  with explicit public-root navigation and regression coverage.
- `MortHeader` and `MortBackButton` assumed a Navigator existed during the
  secure-startup gate. Fixed with `Navigator.maybeOf`; no-Navigator regression
  added.
- Hosted under-13 QA attempted a now-forbidden direct profile update. Fixed to
  exercise the production `save_my_onboarding_age` RPC and exact rejection code.
- Data Safety QA expected removed local-notification dependencies. Corrected to
  the exact binary: Firebase Messaging and Sentry are bundled but disabled;
  RevenueCat and AdMob are absent.
- Debug-removal QA inspected only the wrapper script. It now verifies the full
  reviewed-profile delegation chain and rejects a standalone debug flag.
- Android native integration hardcoded `0.9.13+103` and used a driver harness
  that hung after passing. It now receives the authoritative version through
  non-secret dart-defines and uses Flutter's supported Android `flutter test`
  integration command.
- Release SBOM generation hardcoded the `0.9.13+103` artifact directory. The
  first package run overwrote that historical SBOM. The generator and package
  script are now version-bound and fail-closed. The old dependency inventory was
  reconstructed from its verified source ZIP, but its original random UUID and
  timestamp make byte-for-byte recovery impossible. See
  `docs/MORT_IMMUTABLE_ARTIFACT_RECOVERY_2026_08_08.md`.

## Signed Artifacts

| Artifact | Size (bytes) | SHA-256 | Verification |
| --- | ---: | --- | --- |
| `build/play/mort-closed-test-0.9.14.apk` | 69,287,402 | `4550D402406117BC4B5FDB99C3DDB5C2C56392F3D5E74B7351881DCF0344BEBF` | Signed; package/version/minSdk 24/targetSdk 36; 11 permissions; 16 KB pass |
| `build/play/mort-closed-test-0.9.14.aab` | 52,162,594 | `1EA1B69B6CE6B46B552B9391A570A1A3FE4EC1B74243C01003F6ADCB21B814F3` | Upload certificate verified; debug signer rejected |

No artifact was uploaded automatically. Historical APK/AAB/source/symbol and
manifest evidence were not changed. The historical `0.9.13+103` SBOM incident
and non-byte-identical reconstruction are disclosed above.

The version-safe final release directory contains 13 manifest-tracked files,
including the signed APK/AAB, symbols, CycloneDX SBOM, reports, build manifests,
and source ZIP. The source ZIP contains 1,851 files. Manifest hash comparison,
excluded-path review, archive sensitive-file scan, source secret audit, binary
secret scan, signing verification, and APK alignment checks pass.

## Physical Android Status

Earlier Samsung SM-A146U work confirmed signed installation and launch for an
earlier `0.9.14+104` checkpoint, but did not complete authenticated Adult child
routes. The first physical rendering retest of `0.9.13+103` failed with two
invalid-matrix engine errors. MORT replaced Flutter's transform-based Android
zoom page transition with a finite opacity transition and added focused tests.

The required physical rerun of the OAuth callback to `/account-status` has not
been completed. During this final pass, the remembered wireless ADB endpoint
was advertised by mDNS but actively refused a connection. No new pairing,
unlock, credential entry, clipboard access, biometric action, or account
selection was attempted. Physical QA therefore remains **not passed**.

## Google Play Status

- Target SDK 36: verified.
- 16 KB native alignment: verified for all 18 APK libraries.
- Package, version, upload signer, permissions, and binary secret scan: verified.
- Data Safety, Target Audience, Content Rating, permissions, reviewer access,
  child-safety, listing, and deletion workbooks exist and match the closed-test
  posture at code level.
- Draft legal versions remain `draft-2026-07` and require adult/legal approval.
- Console declarations, SDK Index reconciliation against the Play-processed
  AAB, tester cohort, production-access approval, and Google review remain
  external.

## External Gates

- Enable wireless debugging or securely reconnect the Samsung, install the
  exact APK, complete human login, and rerun the full physical matrix.
- Contract and activate a real identity-verification provider before opening
  the public marketplace. Keep real ID collection disabled until then.
- Approve Terms, Privacy, Community Guidelines, Safety Rules, retention,
  child-safety, insurance, tax, payment, and jurisdiction decisions with
  qualified adults and counsel.
- Staff moderation, support, child-safety escalation, incident response, and
  on-call ownership before real users.
- Configure and approve remote push and crash reporting before any profile that
  requires them. Reaudit Data Safety after provider activation.
- Complete Play Console declarations and closed-test/review submission.
- Use macOS/Xcode for iPhone signing, real-device checks, TestFlight, privacy
  manifests, and App Store review. None of those iOS steps were performed on
  this Windows host.

## Warning Before Real Users

Do not open MORT to the public, collect real identity documents, accept real
payments, represent adults as provider-verified, or invite teen users until the
physical regression, provider, legal, privacy, moderation, support, and store
gates above are complete.
