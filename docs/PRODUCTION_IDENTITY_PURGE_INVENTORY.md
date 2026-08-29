# Production Identity Purge Inventory

Captured from `codex/production-identity-purge` at base commit
`cebcc426d1d100cabbe099c656e7254af5db2b87` on 2026-08-28.

## Baseline

- Raw repository scan: 1,075 matched lines in 347 files after excluding Git,
  dependency, build, cache, generated, Pods, ephemeral, and worktree paths.
- Raw shipping-scope scan: 148 matched lines in 48 files under Flutter source,
  production assets, public web, app, Android, and iOS roots.
- The raw shipping count intentionally over-counts internal release values,
  historical RPC identifiers, and Dart's unrelated `alpha` color argument.
  Those are classified below rather than deleted to manufacture a grep result.
- The production-copy contract will scan only source capable of rendering copy
  to ordinary users. It will not treat security flags, RPC names, tests, or
  historical evidence as user-facing copy.

## Shipping Flutter occurrences

| File | Line | Term | Class | User visible | Action | Owner |
| --- | ---: | --- | --- | --- | --- | --- |
| `flutter_mort/lib/core/config/app_config.dart` | 165 | `Closed Pilot` release label | SHIPPING_FLUTTER | Yes | Map to neutral `MORT`; preserve the internal `closed_test` security value | Codex |
| `flutter_mort/lib/core/routing/app_router.dart` | 245 | `closed pilot` portfolio notice | SHIPPING_FLUTTER | Yes | Explain feature unavailability without test identity | Codex |
| `flutter_mort/lib/core/routing/app_router.dart` | 329 | `closed pilot` business-profile notice | SHIPPING_FLUTTER | Yes | Explain feature unavailability without test identity | Codex |
| `flutter_mort/lib/data/repositories/profile_repository.dart` | 473 | `closed-pilot safety notices` | SHIPPING_FLUTTER | Yes, mapped error | Replace with `MORT safety rules` | Codex |
| `flutter_mort/lib/features/jobs/job_screens.dart` | 693 | `closed-pilot review` | SHIPPING_FLUTTER | Yes | Use truthful moderation/review wording | Codex |
| `flutter_mort/lib/features/legal/legal_screens.dart` | 164 | `closed-pilot eligibility rule` | SHIPPING_FLUTTER | Yes | Refer to account eligibility, not a testing program | Codex |
| `flutter_mort/lib/features/mission/mission_pilot_screens.dart` | 61 | `Closed pilot` badge | SHIPPING_FLUTTER | Yes | Replace with neutral MORT/account status presentation | Codex |
| `flutter_mort/lib/features/mission/mission_pilot_screens.dart` | 1013 | `Pilot job safety` | SHIPPING_FLUTTER | Yes | Replace with `Job safety` | Codex |
| `flutter_mort/lib/features/mission/mission_pilot_screens.dart` | 1025 | `during the pilot` | SHIPPING_FLUTTER | Yes | Explain account/feature restriction directly | Codex |
| `flutter_mort/lib/features/monetization/data/revenuecat_service.dart` | 53 | `closed-pilot release` | SHIPPING_FLUTTER | Yes, provider facade error | Say purchases are unavailable now; keep provider disabled | Codex |
| `flutter_mort/lib/features/monetization/screens/google_play_billing_screens.dart` | 47 | `Free pilot` | SHIPPING_FLUTTER | Yes | Replace with `Free` | Codex |
| `flutter_mort/lib/features/monetization/screens/manage_subscription_screen.dart` | 18 | `closed-pilot release` | SHIPPING_FLUTTER | Yes | Neutral unavailable copy | Codex |
| `flutter_mort/lib/features/monetization/screens/paywall_screen.dart` | 20 | `closed-pilot release` | SHIPPING_FLUTTER | Yes | Neutral unavailable copy | Codex |
| `flutter_mort/lib/features/monetization/screens/restore_purchases_screen.dart` | 18 | `closed-pilot release` | SHIPPING_FLUTTER | Yes | Neutral unavailable copy | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 535 | `Real ID collection disabled` | SHIPPING_FLUTTER | Yes | Humanize verification availability without an engineering-state badge | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 716 | `approved closed-pilot participants` | SHIPPING_FLUTTER | Yes | Explain eligibility/actions from server truth | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 1584 | `closed-pilot review` | SHIPPING_FLUTTER | Yes | Use verification/review wording | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 1620 | `Pilot job safety` | SHIPPING_FLUTTER | Yes | Replace with `Job safety` | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 1767 | `Free pilot` | SHIPPING_FLUTTER | Yes | Replace with `Free` | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 1915–1917 | `closed-pilot rules/notices` | SHIPPING_FLUTTER | Yes | Present MORT Safety Rules without inventing legal approval | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 2737 | `closed-pilot organization participants` | SHIPPING_FLUTTER | Yes | Use authorized organization members | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 6563 | `closed-test configuration` | SHIPPING_FLUTTER | Yes, diagnostics route | Move wording to neutral release diagnostics; preserve authorization | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 6609 | `Closed-pilot access` | SHIPPING_FLUTTER | Yes | Refer to account access | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 6898 | `not enabled for the closed pilot` | SHIPPING_FLUTTER | Yes | Neutral feature-unavailable copy | Codex |
| `flutter_mort/lib/features/mort_screens.dart` | 6971 | `approved closed-pilot participants` | SHIPPING_FLUTTER | Yes | Neutral connected/account-eligibility copy | Codex |
| `flutter_mort/lib/features/onboarding/onboarding_preferences_screens.dart` | 268 | `public marketplace ... closed` / `public-release approved` | SHIPPING_FLUTTER | Yes, legacy route | State that setup does not grant verification/payment protection or eligibility | Codex |
| `flutter_mort/lib/features/settings/experience_settings_screen.dart` | 272, 295, 350 | `closed-test build` | SHIPPING_FLUTTER | Yes | Neutral export availability and `MORT. All rights reserved.` | Codex |
| `flutter_mort/lib/features/settings/release_diagnostics_screen.dart` | 82 | `Payments disabled` | SHIPPING_FLUTTER | Yes | Distinguish job payments from digital purchases | Codex |
| `flutter_mort/lib/features/trust/account_trust_screens.dart` | 1103 | `Public marketplace closed` | SHIPPING_FLUTTER | Yes | Use account eligibility language | Codex |
| `flutter_mort/lib/features/trust/teen_verification_screens.dart` | 25 | `Closed-test routes` | SHIPPING_FLUTTER | Yes | Describe synthetic demo material without making MORT a test product | Codex |

## Shipping identifiers and internal controls retained

| File | Line | Term | Class | User visible | Action | Owner |
| --- | ---: | --- | --- | --- | --- | --- |
| `flutter_mort/lib/core/config/app_config.dart` | 131–149, 432–433 | `closed_test` | QA_INTERNAL / security configuration | No, except label at line 165 | Retain server/release compatibility; purge only presentation mapping | Integration owner |
| `flutter_mort/lib/core/config/release_profile.dart` | 5–216 | `closedTest` / `closed_test` | QA_INTERNAL / build validation | No | Retain distribution and fail-closed gates | Integration owner |
| `flutter_mort/lib/data/models/mission_pilot.dart` | 1–58 | `ClosedPilotEligibility` | Backend compatibility | No | Retain until RPC deprecation; do not rename server contract in copy pass | Backend owner |
| `flutter_mort/lib/data/repositories/mission_pilot_repository.dart` | 19–28 | `get_closed_pilot_eligibility` | Backend compatibility | No | Retain deployed RPC name | Backend owner |
| `flutter_mort/lib/data/models/onboarding_progress.dart` | 3 | `mort-closed-pilot-safety-v1` | Historical acknowledgement version | No | Retain immutable version identifier | Backend/legal owner |
| `flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart` | 207 | isolated test-account sandbox error | QA_INTERNAL | No in production path | Retain truthful sandbox-only guard | Backend owner |
| `flutter_mort/lib/features/monetization/data/revenuecat_service.dart` | 45 | closed-pilot comment | DOC_INTERNAL | No | Rewrite comment only if file changes; do not activate billing | Codex |

## Public web and policy presentation

| File | Line | Term | Class | User visible | Action | Owner |
| --- | ---: | --- | --- | --- | --- | --- |
| `scripts/build-public-legal-site.mjs` | 152, 154, 175, 185 | `Closed pilot` branding/status/descriptions | PUBLIC_POLICY source | Yes after generation | Remove only presentation identity; preserve policy substance and approval truth | Codex unless active Claude overlap |
| `web/public/index.html` | 7, 13, 15, 17 | `closed pilot` | SHIPPING_WEB | Yes | Regenerate from production-neutral source | Codex unless active Claude overlap |
| `web/public/terms/index.html` | 7, 13, 15, 17 | `closed pilot` | PUBLIC_POLICY | Yes | Regenerate; do not claim legal approval | Codex unless active Claude overlap |
| `web/public/{privacy,terms-of-use,community-guidelines,safety,child-safety-standards,prohibited-jobs,payment-disputes,account-deletion,support,contact,accessibility}/index.html` | 13, 15 | `Closed pilot` header/status | PUBLIC_POLICY | Yes | Regenerate presentation shell | Codex unless active Claude overlap |

## Test assertions that must change or remain internal

| File | Line | Term | Class | User visible | Action | Owner |
| --- | ---: | --- | --- | --- | --- | --- |
| `flutter_mort/test/account_status_onboarding_route_test.dart` | 96–114 | internal fixtures plus banned rendered copy | TEST_ASSERTION | No | Keep fixture values; assert banned copy absent | Codex |
| `flutter_mort/test/compact_onboarding_test.dart` | 290–294 | banned-copy list | TEST_ASSERTION | No | Retain negative assertions | Codex |
| `flutter_mort/test/mort_back_navigation_test.dart` | 271 | old safety title | TEST_ASSERTION | No | Assert production replacement | Codex |
| `flutter_mort/test/video_profile_job_hardening_test.dart` | 76 | old moderation copy | TEST_ASSERTION | No | Assert production replacement | Codex |
| `flutter_mort/test/google_auth_activation_test.dart`, `google_auth_contract_test.dart`, `release_profile_test.dart`, `release_candidate_policy_test.dart` | multiple | closed-test build profile | QA_INTERNAL | No | Retain distribution/security contract terminology | CI/integration owner |
| `flutter_mort/test/google_play_billing_contract_test.dart`, `production_readiness_contract_test.dart` | multiple | free-pilot test names | TEST_ASSERTION | No | Rename prose where safe; preserve billing-disabled behavior | Codex |
| `flutter_mort/test/mission_pilot_test.dart`, `role_dashboard_test.dart` | multiple | deployed RPC/status fixture names | QA_INTERNAL | No | Retain backend values; do not render them | Backend owner |

## Internal and historical occurrences

The remaining raw scan is dominated by 511 documentation lines, 239 script
lines, 81 applied-migration lines, 23 Swift-source lines, and CI/release
packaging records. They are classified as follows:

- `supabase/migrations/**`: MIGRATION_HISTORY — retain applied filenames,
  version identifiers, RPC names, predicates, and comments. Rewriting would
  damage migration integrity and auditability.
- `docs/archive/**`, migration reconciliation ledgers, closed-test evidence,
  Play 14-day operational plans, and signed-artifact records: AUDIT_HISTORY —
  retain as evidence of the distribution program.
- `scripts/build-closed-test-*`, verification scripts, release-profile JSON,
  and the signed closed-test workflow: CI_INTERNAL — retain operational names
  while Google Play's testing track remains in use; none may render product UI.
- `scripts/build-play-policy-package.mjs` and generated Play testing plans:
  DOC_INTERNAL / PUBLIC_METADATA source. The tester-program records remain
  operational history; public store-description sources require a separate
  production metadata pass and must not be regenerated from stale copy.
- `README.md`: DOC_INTERNAL — describes current build mechanics, not shipping
  UI. Update only if integration ownership is clear.
- `swift_mort/**`: non-primary platform source. Its user-facing matches require
  a separate scoped pass or integration handoff; Android Flutter remains the
  approved production candidate in this directive.

## Conflict ownership

- Claude's shared checkout was clean at the isolation boundary, but the user
  stated Claude owns ongoing Stage 1/backend/policy/CI work. Codex will not edit
  migrations, RLS, hosted flags, legal versions, or the shared checkout.
- Before editing the public policy generator or CI workflow, Codex will recheck
  the latest pushed integration diff. If those files are under active Claude
  ownership, stale presentation strings will be recorded in
  `docs/CODEX_POLICY_COPY_HANDOFF.md` / the final handoff instead of being
  resolved by choosing one side blindly.

## Resolution status

- The production copy contract first failed with 87 forbidden occurrences and
  now passes across 201 shipping source/public-metadata files with no allowlist.
- All listed shipping Flutter presentation occurrences were replaced with
  neutral, actionable product language. Internal release values, route names,
  acknowledgement versions, model names, and deployed RPC identifiers remain.
- Public legal/support presentation was regenerated with existing committed
  publisher/contact metadata. It now says `Draft — pending qualified legal
  review`; no legal approval or public publication is claimed.
- Play Store short description, full description, release notes, their source
  generator blocks, and the feature-graphic brief now use production MORT
  identity. Google Play closed-testing operational documents retain the track
  name because it describes distribution and audit evidence, not the product.
- No asset or localization match required a file change. No hosted service,
  release flag, RLS rule, payment provider, legal version, or security gate was
  changed.
- Final review expanded the contract to cover user-visible model labels,
  presentation errors, and diagnostics access. Release diagnostics are now
  debug-only, raw server modes are never rendered as friendly status, and the
  public account-deletion form requires validated project-scoped anon
  configuration.
