# MORT Rose-Gold and Light-Blue Redesign Report

Date: 2026-07-28

Status: Code and linked-backend implementation verified. This report does not classify MORT as production-ready.

## Scope and repository audit

The authoritative cross-platform app remains `flutter_mort`, using Flutter, Riverpod, GoRouter, and Supabase. The repository already contained mature role-aware authentication, more than 100 routed surfaces, jobs and applications, authorized messaging, Guardian Mode, moderation, private evidence uploads, notifications, support, and a server-owned two-PIN job workflow.

The audit found these redesign-specific gaps:

- The existing green/black visual language did not match the supplied metallic rose-gold reference.
- Brand marks, launcher assets, loading states, cards, navigation, and web bootstrap media were inconsistent.
- Teen transportation preferences were not persisted or used in job matching.
- Adult job entry did not consistently distinguish gross job amount, the MORT service fee, and teen payout.
- The backend accepted fee-related wrapper inputs that needed to be derived authoritatively.
- The empty teen feed and job-progress presentation did not match the requested premium experience.
- Currency display rounded whole dollars in some surfaces.
- The redesigned splash initially overflowed a compact-height viewport.

## Implemented visual system

- Centralized black, rose-gold, peach, light-blue, status, typography, spacing, radius, blur, shadow, motion, and icon tokens.
- Reusable glass cards, sheets, buttons, fields, search/filter/status controls, top and bottom navigation, job cards, price displays, six-digit PIN pad, timelines, dialogs, notifications, loading, error, empty, and safety states.
- Supplied rose-gold arrow installed as the in-app brand mark and generated Android, iOS, and web icon source.
- Restrained light blue is reserved for safety, location, verification, selected transportation, and information states.
- Reduced-motion support for the brand entrance and haptics for PIN entry.
- Responsive scroll behavior on the redesigned splash for compact-height devices.
- Updated splash, welcome, authentication, onboarding, job feed, job detail, job creation, messaging, support, profile, job progress, and completion presentation.
- Production job feeds remain real-data only. No fake jobs were inserted.

## Functional implementation

### Transportation

Teen onboarding now asks how the teen gets around and persists multiple methods, optional maximum distance and travel time, walking-only preference, and possible guardian transportation. The teen feed automatically applies saved methods and distance without exposing an exact home address. Adult job creation persists acceptable transportation methods and non-guaranteed considerations.

Transportation is optional and does not reduce profile-completion scoring.

### Fixed MORT service fee

The named client constant is `MortServiceFee.serviceFeeCents = 274`. Currency input uses integer-string parsing with no floating-point arithmetic. The adult enters the gross job amount and sees:

- Job amount
- MORT service fee
- Teen payout

The teen card primarily shows the net payout. The detail screen shows the transparent gross/fee/net breakdown. Amounts at or below 274 cents, invalid strings, negative values, excessive decimals, and unreasonably large values are rejected.

The backend ignores forged client payout and fee values. The server derives `adult_job_amount_cents`, `mort_service_fee_cents`, and `pay_amount_cents`, with a database constraint and trigger enforcing `pay = gross - 274`.

### PIN and completion flow

The redesign keeps the stronger existing six-digit security contract instead of weakening it to the concept board's four digits. Start and finish PINs remain separate, server-generated, hashed, expiring, attempt-limited, lockable, single-use, job-bound, role-bound, rate-limited, and audited. The new glass keypad is only the client input surface.

Completion copy is conservative. It shows `Payment under review` unless the backend later confirms a real payment state and never claims `You were paid` based on local UI state.

### Messaging and safety

Messaging now uses aligned glass bubbles, timestamps, scanner-state chips, safe quick replies, retry-preserving drafts, and reporting controls. Existing server authorization remains responsible for conversation eligibility. Report, block, Safety Ping, and core Guardian Mode remain free.

## Supabase migrations

Linked project: `rakjydmgwwgtdislanbt`

Applied and matched locally/remotely:

1. `20260728183833_teen_transportation_preferences.sql`
   Adds constrained profile fields and `save_my_transportation_preferences`. The RPC is bound to `auth.uid()`, teen-only, normalized, audited, and denied to public/anonymous callers.
2. `20260728184631_mort_fixed_service_fee.sql`
   Adds gross and fee columns, backfills existing jobs, enforces the 274-cent fee and payout equation, revokes the authenticated legacy bypass, and replaces job save behavior with server-derived values. Live Stripe mode remains disabled.
3. `20260728185618_job_transportation_matching.sql`
   Adds constrained acceptable transportation methods and considerations to jobs and validates/persists them through the authorized job save wrapper.

No new broad RLS policy was added. Existing job ownership policies continue to block users from directly changing protected financial fields. No Edge Function change was required for these features.

Fresh pre-change backup evidence is stored outside release packaging under `backups`:

- Remote schema: 258 relations, 289 policies, 407 functions, 109 migrations.
- Remote data: 214 tables, 2,840 rows, SHA-256 `1AFC30BB61E3A14213994CBE8008C981E9F00DEC920232F7136AADA773FC5A61`.
- A second schema snapshot was captured before the final matching migration: 258 relations, 289 policies, 410 functions, 111 migrations.

## Verification results

Commands run from `C:\Users\micha\Mort\flutter_mort` unless otherwise noted:

- `flutter pub get`: PASS. Dependencies resolved; 43 newer incompatible package versions were reported as informational.
- `dart format lib test`: PASS. 167 files checked, 0 changed on final run.
- `flutter analyze`: PASS. No issues found.
- `flutter test`: PASS. All 177 tests passed.
- `flutter build web --release` through `scripts\build-web-preview.ps1`: PASS. `build\web` created; Wasm dry run passed.
- `scripts\build-closed-test-apk.ps1`: PASS. Signed release APK built.
- `scripts\build-play-aab.ps1`: PASS. Signed, obfuscated release AAB built; symbols retained outside the repository.
- `scripts\qa-android-apk.ps1 -RequireSigned`: PASS. Package `com.mortapp.mobile`, version `0.9.6+96`, min SDK 24, target SDK 36, 10 permissions, signed.
- `node scripts\qa-aab-secret-scan.mjs`: PASS. 2,610 extracted APK/AAB entries scanned against five available sensitive values.

Commands run from `C:\Users\micha\Mort`:

- `npx supabase migration list --linked`: PASS. All local and remote migrations matched, including the three redesign migrations.
- `node scripts\qa-redesign-backend.mjs`: PASS. Fee control, auth-bound transportation, forged value rejection, legacy wrapper denial, RLS isolation, and rollback verified.
- `npx supabase db lint --linked --level warning`: COMPLETED. No redesign-migration warning. Pre-existing RevenueCat text/text-array and unused identity/support parameter warnings remain.
- `.\scripts\secret-scan.ps1`: PASS.
- `.\scripts\sensitive-file-scan.ps1`: PASS. 1,584 files, 42 reviewed app media files, and 10 available secret values checked.
- `adb devices -l` and `emulator -list-avds`: No connected Android device and no configured AVD.

Remote backend QA used an explicit transaction and rolled back every write. It verified that forged `1`-cent fee and payout fields on a 2,500-cent job returned server values `2500 / 274 / 2226`.

## Errors found and fixed

- Analyzer found an incorrect `MortLoadingState` name during implementation; changed to the existing `MortLoading` component.
- Formatter found unescaped dollar literals in tests; corrected without changing currency behavior.
- Full tests found a 6.6-pixel splash overflow at compact height; made the splash scroll safely and replaced fixed flex spacers.
- Full tests found transportation incorrectly lowering an otherwise complete teen profile to 90%; made the preference optional in completion scoring.
- Full tests found a stale `MORT` text assertion after the intentional `M O R T` wordmark; updated the assertion.
- Visual QA found whole-dollar formatting hiding cents; currency now consistently shows two decimal places.
- Web visual QA found an old green bootstrap mark and low-contrast copy; replaced the loader mark and corrected contrast.
- A local Flutter web restart found port 8765 held by its previous child process; the verified Flutter child was stopped before restart.
- The privacy scanner initially rejected the new brand image and generated adaptive icons; reviewed them and added narrow path allowlists.

## Release artifacts and size

- APK: `build/play/mort-play-closed-test-qa.apk`
  - 78,773,577 bytes
  - SHA-256 `241BF7A1988268A9BD2385CCC08BF36D8F2CB9A67746251DF4169DC190E2334B`
- AAB: `build/play/mort-closed-test.aab`
  - 62,811,036 bytes
  - SHA-256 `B16F55A32F05825C318DCBB76F59535F616FCF3A238C2AEED05FF305A825923D`
  - Signed and obfuscated

Best available pre-redesign 0.9.5 baseline:

- APK: 77,082,652 bytes. Increase: 1,690,925 bytes (about 2.19%).
- AAB: 61,493,557 bytes. Increase: 1,317,479 bytes (about 2.14%).

The larger generated rose-gold icon set accounts for part of the increase. Runtime card blur is opt-in and is not used on high-volume list items by default.

## Files changed for this redesign

Core and app source:

- `flutter_mort/assets/branding/mort_arrow_rose_gold.png`
- `flutter_mort/lib/core/errors/user_facing_error.dart`
- `flutter_mort/lib/core/money/mort_service_fee.dart`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/core/theme/mort_colors.dart`
- `flutter_mort/lib/core/theme/mort_spacing.dart`
- `flutter_mort/lib/core/theme/mort_theme.dart`
- `flutter_mort/lib/core/theme/mort_tokens.dart`
- `flutter_mort/lib/core/theme/mort_typography.dart`
- `flutter_mort/lib/core/utils/formatters.dart`
- `flutter_mort/lib/core/utils/validators.dart`
- `flutter_mort/lib/core/widgets/mort_brand.dart`
- `flutter_mort/lib/core/widgets/mort_design_components.dart`
- `flutter_mort/lib/core/widgets/mort_widgets.dart`
- `flutter_mort/lib/data/models/job.dart`
- `flutter_mort/lib/data/models/profile.dart`
- `flutter_mort/lib/data/repositories/jobs_repository.dart`
- `flutter_mort/lib/data/repositories/profile_repository.dart`
- `flutter_mort/lib/features/guardian/guardian_mode_screens.dart`
- `flutter_mort/lib/features/jobs/job_progress_screen.dart`
- `flutter_mort/lib/features/jobs/job_screens.dart`
- `flutter_mort/lib/features/jobs/teen_job_screens.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/lib/features/onboarding/transportation_screen.dart`
- `flutter_mort/lib/features/support/support_screens.dart`
- `flutter_mort/pubspec.yaml`
- `flutter_mort/pubspec.lock`

Tests, backend, and release controls:

- `flutter_mort/test/job_progress_widget_test.dart`
- `flutter_mort/test/mort_redesign_test.dart`
- `flutter_mort/test/mort_service_fee_test.dart`
- `flutter_mort/test/transportation_preferences_test.dart`
- `flutter_mort/test/widget_test.dart`
- `scripts/qa-redesign-backend.mjs`
- `scripts/sensitive-file-scan.ps1`
- `supabase/migrations/20260728183833_teen_transportation_preferences.sql`
- `supabase/migrations/20260728184631_mort_fixed_service_fee.sql`
- `supabase/migrations/20260728185618_job_transportation_matching.sql`

Generated platform branding:

- Android launcher PNGs under `flutter_mort/android/app/src/main/res/mipmap-*`
- Android adaptive foreground PNGs under `flutter_mort/android/app/src/main/res/drawable-*`
- Android adaptive-icon XML under `flutter_mort/android/app/src/main/res/mipmap-anydpi-v26`
- `flutter_mort/android/app/src/main/res/values/colors.xml`
- iOS AppIcon PNGs and `Contents.json` under `flutter_mort/ios/Runner/Assets.xcassets/AppIcon.appiconset`
- `flutter_mort/ios/Runner.xcodeproj/project.pbxproj`
- `flutter_mort/web/favicon.png`
- `flutter_mort/web/icons/Icon-192.png`
- `flutter_mort/web/icons/Icon-512.png`
- `flutter_mort/web/icons/Icon-maskable-192.png`
- `flutter_mort/web/icons/Icon-maskable-512.png`
- `flutter_mort/web/index.html`
- `flutter_mort/web/manifest.json`
- Removed `flutter_mort/web/icons/mort-mark.svg`

`docs/WEB_BUILD_CONFIG_STATUS.md` was refreshed by the verified web build. This report and the packaging script are delivery files. Other dirty reviewer-mode and repository changes present before this redesign were preserved.

## Visual and manual QA

The real Flutter web app was run and inspected at a 390 x 844 iPhone-sized viewport. Splash, welcome, and sign-up screens rendered with the supplied arrow, rose-gold hierarchy, readable light-blue safety surfaces, working scroll behavior, and no browser render errors. The only console warning was Flutter replacing the existing viewport meta tag.

Native Android manual testing was not performed because no device or AVD was available. Native iPhone, TestFlight, camera/photo permission, notification permission, StoreKit, and App Store purchase testing were not performed on Windows.

Manual device checklist still required:

1. Install the signed closed-test build on representative low-, mid-, and high-density Android phones.
2. Verify launcher safe zones, cold start, text scaling, TalkBack, reduced motion, dark contrast, keyboard insets, and back navigation.
3. Exercise teen, adult, guardian, and admin navigation with real QA accounts.
4. Publish a private pilot job, apply cross-account, accept, message, enter start and finish PINs, submit proof, and review completion.
5. Deny and later grant camera, photo, location, and notification permissions.
6. Test offline, slow network, expired auth, blocked account, report/block, Safety Ping, and retry behavior.
7. Test iPhone Safari PWA separately, then native iPhone through TestFlight when Apple program access is available.

## Remaining blockers and warnings

- Actual identity/provider verification is not connected; real ID collection remains disabled and sandbox verification is QA-only.
- Public marketplace access remains closed until production verification and operational moderation exist.
- Stripe live job payments remain disabled. The service fee accounting is authoritative, but this pass did not process or pay real money.
- Guardian Mode remains optional. Policy and legal review may still impose age-specific requirements.
- Native purchases, AdMob, push notifications, camera/photo behavior, and iOS permission prompts still require physical-device testing.
- App Store Connect, TestFlight, Google Play closed-track review, privacy disclosures, child/teen-safety review, terms, tax, labor, insurance, payment, and local-law review remain external work.
- The database linter's pre-existing RevenueCat cast warnings should be resolved before enabling related live fulfillment.
- Supabase leaked-password protection is a deferred, plan-limited security enhancement on the Free plan. When Supabase is upgraded to Pro, enable it immediately and rerun Auth security advisors.
- Do not open the public marketplace or accept real users solely from these automated results.
