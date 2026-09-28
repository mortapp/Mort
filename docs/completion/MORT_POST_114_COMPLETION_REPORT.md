# MORT post-114 engineering report

Evidence date: 2026-09-28. Read with `MORT_POST_114_COMPLETION_LEDGER.md`. This is a code and evidence handoff, not a production approval or Play Console submission.

| Release fact | Result |
| --- | --- |
| Base tester version | `0.9.16+114`, Google Play Closed Testing |
| Frozen tester source | `ae43047d3dd0c9805340fa70d794651f32dcae87` |
| Completion worktree | `C:\Users\micha\Mort.worktrees\feature-mort-post-114-completion` |
| Completion branch | `feature/mort-post-114-completion` |
| Final head | Resolve with `git rev-parse HEAD` in the worktree; the final chat handoff records the immutable SHA after this report is committed. |
| Tester artifact modified | **NO**. SHA-256 remains `F8BA6E1CDE5CDD6BF51706B0E45A71B6A224EF6640C7870E274EC58EBCC57E3D`. |
| New Play build created / uploaded | **NO / NO** |
| Production activated / PRs merged | **NO / NO** |

## PR and client state

GitHub on 2026-09-28: #17 Android BrowserStack QA, #20 iOS parity, #24 RevenueCat certification and #25 Safety Center are **OPEN DRAFT** in that order, each reported mergeable. #19 Verify, #21 progression and #23 monetization convergence are **MERGED**. Do not rebuild their features from old checklists. Frozen-head CI run 36333397345 was successful, including `ios-authoritative`, `flutter-authoritative` and Android device-test APK jobs. The completion branch changes still require their own CI after publication.

The authoritative app is `flutter_mort`. Its checked-in `pubspec.yaml` says `0.9.16+113`; the uploaded 114 bundle was built with an explicit build-number override, verified by the signed artifact report. No version file was bumped in this sweep. `com.mortapp.mobile` remains the package/bundle ID.

## Changes made in the completion branch

1. **Server-secret detection:** source, Git history and AAB/APK scanners now recognize generic RevenueCat V2 `sk_` server keys. The artifact scanner checks more configured secret names and permits only one SHA-256-identified upstream Flutter engine symbol marker at its exact native-library path. Synthetic self-tests pass; the real 114 AAB plus the older 113 APK had no configured secret hits across 2,918 extracted entries.
2. **Android QA accessibility:** added a stable semantics identifier to onboarding Display name and removed the Appium second-EditText selector. Focused Flutter and Node tests pass; a real BrowserStack session is still required to prove the Android accessibility bridge on hardware.
3. **Paywall regression:** added tests that tap Continue with Free with plans present and while offerings load. Neither case calls purchase or restore; each calls the existing close callback once. Paywall UI and production callback code were not changed.
4. **Migration parity checker:** fixed its Git blob hash preamble from a literal backslash-zero to the required NUL byte. The seven compatibility aliases and three restored hosted guardian migrations now pass; no SQL migration was edited or deployed.
5. **Companion Studio:** inspected the owner-supplied `Create_Unique_Pet_Animations.zip` as a design reference and built the separate Flutter Studio. It includes 14 original vector companions, cosmetic customization, account-scoped saved looks, short interactions, and 15/25/45/60 minute Focus timers with no reward path. Wix is free; the other pets rely on the existing RevenueCat Pro entitlement and never unlock from local storage alone. Studio is entered through Settings; no global floating companion is mounted over Safety, evidence, verification or urgent Guardian routes. The existing Guide and MORT visual language remain intact. Focused tests cover catalog, isolation, locked selection, reduced motion, interactions, saved looks, Focus options, and compact layout. Actual device appearance and motion still need review.
6. **Documentation:** marked old blueprint and Data Safety workbooks as historical where they contradict the 114 billing-enabled client. The ledger above records current technical data classes and outstanding gates.

## Test and security evidence

| Check | Result |
| --- | --- |
| Dart formatting | Changed Dart files formatted, zero changes after format. |
| Flutter analyze | PASS, no issues, after the last test-only additions. |
| Full Flutter test | PASS, **749 passed / 2 existing skips / 0 failed** after paywall, Display name and Companion Studio tests. Baseline was 733 / 2. |
| Android BrowserStack harness | PASS, 10 deterministic Node tests. Provider session remains blocked by issue #18 quota. |
| Deno Edge tests | PASS, 29 / 0, using CI-equivalent frozen test invocation. |
| MORT Verify source contract | PASS; production document collection remains disabled. |
| iOS/Android capability matrix | PASS, 35 records; physical iOS distribution not inferred. |
| Stripe pre-provider freeze | PASS, 18 cases; no provider mutation. Source-only activation gate, billing separation and evidence-manifest checks pass. |
| Data Safety/source release checks | PASS: data inventory, child-safety standards, network security, deep links, RevenueCat config, migration encoding and reconciliation. |
| Source secret scan | PASS, zero classified credential findings. |
| Git object history | PASS, 9,622 objects / 4,747 blobs, seven configured exact values and generic server-key/service-role JWT detection; zero hits. No values printed. |
| Frozen AAB/APK scan | PASS, 2,918 extracted entries, zero configured secret hits. AAB signature/package/hash and 16 KB ELF/ZIP alignment independently verified from the release evidence. |
| Local Supabase replay/RLS/races | **DEVICE_GATE**: MORT Docker Linux engine unavailable; no Loop database substituted. Prior PR #25 local authenticated checks remain historical evidence, not a rerun. |
| Physical Android | **DEVICE_GATE**: `adb devices` returned no attached device. |
| Exact completion-head CI | Pending branch publication and workflow dispatch. Frozen-head CI is green; it is not completion-head CI. |

## Subsystem verdicts

| Subsystem | Code status | External status |
| --- | --- | --- |
| iOS parity | Shared Flutter and macOS CI green at frozen head | Apple distribution certificate/profile, App Store Connect, TestFlight, APNs, privacy answers and physical iPhone gate remain. iOS AdMob has a sample startup ID with ads disabled; real IDs are gated. |
| Safety | Prior Safety implementation and 29 Edge tests preserved | New Safety migration `20260927003338` is absent from hosted MORT; default Supabase branch only. Do not deploy during tester window. Real contacts, GPS, battery, background and dialer tests plus legal/operations signoff remain. |
| Android QA | Display name selector defect fixed | BrowserStack capacity issue #18, real deep/compact sessions and no fatal/overflow device logs remain. Six high advisories in QA-only WebdriverIO transitive `extract-zip` have no safe compatible fix in the current audit. |
| RevenueCat / Play | Free-dismiss callback contract verified; products and entitlements untouched | Build-114 tester must verify Settings → Optional subscription → Continue with Free → Settings and no reopen. Separate licensed Play tester must verify purchase, cancel, expiry and restore. No local Pro grants. |
| Verify / progression | Merged architecture preserved; source/Flutter checks pass | Identity provider and document-collection activation remain disabled; DB replay, multi-user RLS and concurrency require the MORT local stack. |
| Stripe | Source freeze and separation checks pass | Live marketplace remains disabled. No settlement/refund/transfer provider claim from synthetic tests. |
| Companion Studio | Separate Flutter route implements the 14-companion core, cosmetics, local saved looks, interactions and Focus. Guide remains separate. Free/Pro selection uses RevenueCat entitlements; no local entitlement grant. | The attached ZIP is a React prototype, used as reference only. Physical Android/iOS visual, animation and accessibility review is still required. Floating companion and profile-wide placement were intentionally left out because this completion branch has no global suppression contract for sensitive screens. |
| Support / moderation | Existing client/backend/runbooks retained | Human staffing, training, tabletops and actual escalation receipts remain operations gates. External AI stays disabled. |
| Notifications / crash | In-app and backend paths exist | Push and crash collection remain disabled until real Firebase/APNs/Sentry configuration and disclosure. |
| Legal / store privacy | Technical inventories and stale-source corrections prepared | Attorney and owner store-answer approval remain. No Play/App Store forms submitted. |
| Deletion / retention | Existing processor and FK QA retained | Full local synthetic deletion/FK/RLS suite could not run without Docker. No real user deletion. |

## Sequential review

**Believer.** The frozen artifact was protected, all modified code has focused tests, 749 Flutter tests and 29 Edge tests passed, public marketplace and sensitive provider features stayed closed, and secret scans found no privileged credential in source, Git objects or the scanned artifacts.

**Skeptic.** Flutter/Node tests cannot prove BrowserStack semantics, physical Safety behavior, recipient delivery, licensed Play billing, hosted Safety RLS or deletion races. The sample iOS AdMob ID prevents startup failure but does not certify live iOS ads. Older Data Safety workbooks were misleading for build 114 and are now marked historical. A privileged provider key shared earlier in chat needs provider-side rotation under a controlled maintenance window; no rotation or credential disclosure occurred in this run.

**Investor / operations.** The remaining hard gates belong to Google Play license testers, BrowserStack capacity, Apple signing/TestFlight/APNs, Safety recipients and staff, legal/privacy owners, real push/crash providers and marketplace business approval. The Docker service also blocks local certification on this host. None can be replaced by a synthetic green test.

**Judge.** `CODE_CONTROLLED_NOT_READY` for the full product sweep: completion-head CI and local database adversarial/race suites are pending, and the physical/provider gates prevent broader certification. The security-scanner, Android selector, paywall-regression, migration-checker and Companion Studio core are reviewable with their stated local tests. Global companion placement needs a separate sensitive-screen suppression design before inclusion. Public-production readiness is not claimed.

## Required next sequence

1. Wait for build-114 tester free-dismissal evidence. Do not build or upload 115 until that feedback is reviewed.
2. Restore BrowserStack quota and run deep plus compact Android profiles on the completion head; resolve QA-only dependency advisories with a compatible upstream release and a real-device regression.
3. Start the **MORT** Docker engine with sufficient host privilege; run full migration replay, Safety/Verify/progression/Stripe/RevenueCat/Guardian/support/deletion RLS and race suites, then resolve reproducible defects.
4. Review the Flutter Companion Studio visually on physical Android/iOS against the owner-supplied prototype. Add any future profile or floating placement only with a tested suppression contract for every sensitive screen; the current route is isolated by construction.
5. Run exact completion-head macOS CI, then review draft PR order #17 → #20 → #24 → #25 → completion branch. Recheck merge bases and conflicts before any later owner-approved merge.

**Next Play version if a verified fix requires a new upload:** 115. **Do not build it yet.**
