# MORT 0.9.16+116 release verification plan

> Execute sequentially in this integration worktree. AGENTS.md prohibits delegation. The owner authorized packaging build 116; uploading, merging and production rollout remain unauthorized.

**Goal:** Produce new signed closed-testing APK/AAB artifacts from one clean committed HEAD while preserving build 115 and its evidence.
**Architecture:** Use the existing ordinary closed-test release/signing scripts with real Google Play billing, existing MORT Pro public SDK configuration, and fail-closed marketplace/public production flags. No product or UI changes.
**Tech stack:** Flutter/Dart, Android Gradle, protected production upload keystore, bundletool and Android SDK/NDK verification tools.
**Spec:** Owner's build-116 packaging directive and `docs/blueprints/MORT_MASTER_EXECUTION_BLUEPRINT.md`.

## Constraints and review focus

- Version name remains 0.9.16; versionCode becomes 116; package remains com.mortapp.mobile.
- Source includes entitlement expiry, MORT Verify startup/qualified hashing, and Flutter RPC response fixes from 3a45e021bafd6a044044aadac7b13b082be535ba.
- Preserve all named build-115 artifacts, manifests, reports and symbols; record hashes before/after. Intermediate Android build outputs may be regenerated.
- Store-authoritative Pro prices, paywall UI and Continue with Free remain unchanged. Plus catalog approval and actual store transaction certification remain external gates.
- Billing must be enabled in the ordinary closed-test profile. No reviewer bypass, fake entitlement, privileged client credential, public activation or live Stripe marketplace.
- Verify both delivered files, including the AAB's generated APK alignment; provenance must match the clean packaged commit.

## Execution checklist

- [ ] Capture build-115 preservation baseline and archive existing generic worktree verification reports.
- [ ] Update only `flutter_mort/pubspec.yaml` release version and this release documentation; review diff and commit before verification/build.
- [ ] Run Flutter formatting, analysis and full tests against that clean commit; run the nine relevant local backend QA suites and website tests.
- [ ] Run source secret scan and diff checks; use read-only hosted release-profile validation.
- [ ] Build a new signed ordinary closed-test AAB and APK with real Play billing using protected signing configuration.
- [ ] Verify exact source commit, manifest version/package/profile, signatures, integrity, sizes and SHA-256 for both artifacts.
- [ ] Verify native ELF LOAD alignment, APK 16 KB ZIP alignment, AAB PAGE_ALIGNMENT_16K and an APK derived from the AAB.
- [ ] Run artifact secret scan and confirm every preserved build-115 file remains identical.
- [ ] Deliver only new 116 files/manifests and a separate completion report under `C:\Users\micha\Mort\build\play`, with exact evidence and outstanding device/provider gates.

## Evidence location

Fresh results and the completed checklist belong in the external artifact report directory `C:\Users\micha\Mort\build\play\reports\0.9.16-116`. This checked-in plan records authorization and acceptance criteria, not successful packaging. Keeping final results outside source preserves the exact packaged HEAD.

## Final status requirements

Report separately: code verified, artifact verified, store testing pending, production rollout not performed. The build does not complete or activate the distinct MORT Plus launch. New backend migrations have local evidence only unless separately deployed and verified.
