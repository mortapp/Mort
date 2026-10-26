# Android Play Production Signing Readiness Ledger

- Base: `5d85dcfb63d32800b76c7488fc066855585b9bdf` (`codex/mort-production-readiness`).
- Task 1: Updated the canonical signing guide to distinguish granted Play production access from the backend release policy and a public rollout. Documented the three AAB profiles, server release gates, verified local signer, and unavailable signed CI secrets.
- Verification: `validate-release-profile.mjs production` reported all six safe profiles valid; targeted documentation contract passed; `git diff --check` passed.
- Live backend evidence: connected Supabase read-only query reported `closed_test` / `closed_pilot`, `public_marketplace_enabled=false`, `remote_push=false`, and `real_document_collection=false`. No live configuration was changed.
- Note: The repository's embedded public client key received HTTP 401 from the release-mode REST RPC, so the connected Supabase read-only query was used as authoritative evidence instead.
- CI evidence at task execution: PR run `40240845620` was still in progress; `flutter-authoritative`, `stripe-local-regression`, and `android-device-test-apk` had not completed. `public-site` and `expo-reference` failed; they are outside the Flutter-only release change.
- Final review: independent read-only review found no Critical or Important issues. The GitHub secret claim was checked against repository secrets and the `Production`, `closed-test-release`, and `backend-operations` environments; no signing secret names were present.
- Final: minor (deferred): make the guide explicitly call out that the checked-in production profile currently has `productionActivationApproved=false`, so the public AAB builder cannot pass until approval is recorded through the authorized release process.
