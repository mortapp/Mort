# MORT 0.9.4 Final Status

Version: `0.9.4+94`

## Clear status

- **Code-controlled 0.9.4 sprint:** completed and locally verified within the
  documented scope.
- **Hosted backend:** migrations aligned and primary remote authorization,
  isolation, Storage, rate-limit, moderation, deletion, support, PIN, and payment
  boundaries verified on `rakjydmgwwgtdislanbt`.
- **Android closed-test artifacts:** signed APK and AAB built and verified.
- **Public marketplace:** closed.
- **Production ready:** no.
- **Physical Android testing:** not done.
- **iPhone/Xcode/TestFlight:** not done.
- **Stripe provider E2E/live money:** not done and disabled.
- **App Store/Play publication:** not done.
- **Legal/privacy/labor/teen-safety approval:** not done.
- **Staffed incident exercise/restore drill:** not done.

## Repository

- Root: `C:\Users\micha\Mort`
- Branch: `mort-0.9.4-completion-security`
- Remote: `https://github.com/mortapp/Mort.git`
- Recovered baseline: `3301356`
- Implementation: `b3be6c3`
- Verification/runbooks: `dd51c31`
- Push: not attempted; GitHub owner authentication and author identity are not verified.

## Backend result

Migrations `20260722233000`, `20260722234500`, and `20260723030622` are applied
remotely. Local and remote histories align. Schema error lint is clean.
`send-push` and nine Stripe functions were deployed. Send-push is authorized by
a server secret and live smoke-tested only for safe auth rejection/queue behavior.
Stripe functions fail closed because server provider secrets are absent and
payments are disabled.

The remote suite passed 26/26 scripts and 30/30 isolation checks. Stripe boundary
QA passed 25/25, focused support/PIN/evidence passed 8/8, and 0.9.4 operational
controls/moderation passed. No service-role credential is present in mobile code.

## Client result

Flutter is the authoritative Android client. It passed formatting, analyzer,
128/128 tests, web release, debug APK, signed release APK/AAB, release lint,
manifest/signature checks, and API 36.1 cold/offline/recovery smoke. Expo remains
a reference client and passed TypeScript, lint, two 48-route exports, and Doctor
20/20. Route inventory found 175 Flutter routes and 46 Expo source routes; four
builders remain mechanically unresolved and 142 routes lack direct static tests.

## Security result

Current source, six recovered Git commits, selected secret values, 1,470 source
files, six ZIP packages, and 2,594 extracted APK/AAB entries were scanned without
a secret finding. The post-cleanup strict feature-QA count is zero. Eleven older
synthetic reviewer fixtures remain pending owner classification; one has a
safety-admin assignment and one has partner-staff assignment. Do not admit real
users until that retention/session/evidence decision is complete.

Supabase leaked-password protection is **DEFERRED — PLAN-LIMITED SECURITY
ENHANCEMENT**, not an unresolved code bug. When Supabase is upgraded to Pro,
enable it immediately and rerun Auth security advisors.

## Artifacts

The final packager produces:

- `mort-android-0.9.4-final-source-clean.zip`
- `mort-android-0.9.4-final-qa.apk`
- `mort-android-0.9.4-closed-test.aab`
- `mort-0.9.4-test-evidence.zip`
- `mort-stripe-testmode-evidence-0.9.4.zip`
- `mort-play-review-package-0.9.4.zip`
- `mort-documentation-0.9.4.zip`
- `mort-support-pin-evidence-0.9.4.zip`

Exact final sizes, file counts, and SHA-256 values are generated in
`artifacts/MORT_0_9_4_ARTIFACT_INVENTORY.json`,
`artifacts/MORT_0_9_4_ARTIFACT_INVENTORY.md`, and
`artifacts/SHA256SUMS.txt` after the final commit.

## Next human actions

1. Owner-review the 11 retained synthetic QA fixtures, sessions, assignments,
   proof rows, and one Storage object; remove or formally retain each.
2. Verify GitHub owner authentication and author identity, review the local
   commits, then push this branch without force.
3. Run the full signed-in matrix on a physical Android device, including camera,
   picker, push, accessibility, process death, and every role lifecycle.
4. Configure Stripe test secrets server-side only and execute every blocked
   provider scenario in an isolated test window; keep live mode off.
5. Complete qualified legal, privacy, labor/tax, teen-safety, and store policy reviews.
6. Configure approved crash/alert destinations, staff escalation roles, and
   perform documented incident and restore exercises.
7. Use macOS/Xcode and a real iPhone for iOS signing, notification, camera,
   TestFlight, privacy-manifest, and App Store validation.

Warnings before real users: keep the public marketplace closed, do not enable
real identity collection, do not enable live payments/ads/IAP/external AI, do
not rely on verification as a safety guarantee, and do not treat emulator or
backend QA as physical-device, legal, or operational approval.
