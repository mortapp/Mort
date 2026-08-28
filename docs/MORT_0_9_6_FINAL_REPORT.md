# MORT 0.9.6 Final QA Report

MORT 0.9.6 implements an isolated Google Play reviewer experience. This is a closed-test candidate, not a production-readiness claim.

## Reviewer architecture

The exact reserved identifier `play-review@mortapp.test` activates an in-memory `ReviewerSession` only when no Supabase production user is present. Reviewer routes use a dedicated route guard and local synthetic state. They do not import Supabase repositories, Storage, Stripe, service-role credentials, or production role/entitlement code.

The reviewer selector exposes Teen, Adult, Guardian, Support, and read-only Admin demonstrations. Payment states, proof, support actions, moderation actions, and PINs mutate only local reviewer state. Exit and process restart clear that state.

The remote database separately reserves the identifier with a trigger on `auth.users`. This prevents password, OAuth, invitation, admin-created, and email-change paths from turning the reviewer identifier into a production account.

## Security results

- Supabase project verified: `rakjydmgwwgtdislanbt`.
- Migration `20260726024327_reserve_play_reviewer_identifier.sql` is present locally and remotely.
- Exact reserved Auth Admin creation: denied.
- Ordinary nonreserved email/password Auth creation: allowed and QA user removed.
- Anonymous reads of profiles, messages, and proof: denied.
- Demo PINs against production job-verification RPCs: denied.
- Destructive production administration without a real authorized session: denied.
- Final Supabase regression: 31 scripts passed, including 30/30 multi-user isolation checks.
- AAB scan: 2,596 entries scanned against five available secret values; no finding.
- Source scan: passed.
- Git-history scan: 10 commits, five candidate blobs, no finding.
- Sensitive-file scan: 1,533 files, 30 known app media files, ten available secret values; passed.
- Dependency audit after the override fix: no known vulnerabilities.

Supabase advisors still report warning/info recommendations, including security-definer exposure review and index opportunities. There are no error-level advisor findings. Leaked-password protection remains `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`; when the project is upgraded to Pro, enable it immediately and rerun Auth security advisors.

## Verification results

- Flutter format: 159 files checked, no changes required.
- Flutter analyze: no issues.
- Flutter tests: 156/156 passed, including 17 reviewer-mode tests.
- Flutter web release build: passed.
- Expo TypeScript check, lint, and 48-route web export: passed.
- Expo Doctor: 20/20 checks passed.
- Android release lint: passed with a dependency deprecation note only.
- Signed APK verification: passed, version `0.9.6+96`.
- Signed AAB verification: passed against the MORT upload certificate.
- Signed APK reviewer emulator flow: passed with the limitations in `MORT_ANDROID_EMULATOR_EVIDENCE_0_9_6.md`.

## Signed build inputs

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `build/play/mort-play-closed-test-qa.apk` | 77116060 | `9F4A638039D7272BF12E39AE98A36419CF94C77FC28BAEC3C413E0C5A5DD94FA` |
| `build/play/mort-closed-test.aab` | 61555295 | `0F80332D3C49A04A19EC85A1DB40724ED005BD49128CB21FCACC8762BEABA472` |

The final named copies, reviewer evidence, Play review package, clean source archive, inventory, and `SHA256SUMS.txt` are generated in `artifacts` by `scripts/package-mort-0.9.6.ps1`.

## Remaining blockers

- Upload and validate the AAB in a Google Play closed-test track.
- Complete Google Play review using the exact App Access text.
- Run reviewer, normal Auth, network-loss, process-death, accessibility, photo, notification, and performance flows on physical Android devices.
- Complete provider-backed adult/business verification before opening the public marketplace.
- Complete Play Data safety, privacy policy, child/teen safety, legal, support, moderation staffing, and incident-response review.
- iPhone manual testing, TestFlight, and App Store review are separate and not complete.
