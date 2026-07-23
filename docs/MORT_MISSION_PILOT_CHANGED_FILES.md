# MORT Mission Pilot Changed Files

This inventory covers the mission/closed-pilot continuation and its corrective migrations.

## Supabase

- `supabase/migrations/20260719012241_mission_closed_pilot_independence.sql`
- `supabase/migrations/20260719020850_mission_closed_pilot_security_fixes.sql`
- `supabase/migrations/20260719021044_no_permanent_address_onboarding.sql`
- `supabase/migrations/20260719021142_align_no_address_profile_constraint.sql`
- `supabase/migrations/20260719021727_fix_support_circle_rls_recursion.sql`
- `supabase/migrations/20260719022554_fix_partner_roster_audit_volatility.sql`
- `supabase/migrations/20260719022701_grant_mission_rls_boolean_helpers.sql`
- `supabase/migrations/20260719030922_mission_pilot_advisor_fixes.sql`
- `supabase/migrations/20260719031115_mission_pilot_lint_fixes.sql`
- `supabase/functions/document-vault-access/index.ts`

## QA and operations

- `scripts/mission-pilot-qa-suites.mjs` and the 17 `scripts/qa-*.mjs` mission wrappers named in the request
- `scripts/audit-mission-pilot-remote.mjs`
- `scripts/backup-feature-schema.mjs`
- `scripts/package-mission-pilot-independence.ps1`

## SwiftUI

- `swift_mort/MORT/Models/MissionPilot.swift`
- `swift_mort/MORT/Repositories/MissionPilotRepository.swift`
- `swift_mort/MORT/Features/Mission/MissionPilotViews.swift`
- `swift_mort/MORT/Models/Profile.swift`
- `swift_mort/MORT/Repositories/ProfileRepository.swift`
- `swift_mort/MORT/App/DependencyContainer.swift`
- `swift_mort/MORT/App/Router.swift`
- `swift_mort/MORT/Features/Home/RoleShells.swift`
- `swift_mort/MORT/Features/Settings/SettingsView.swift`
- `swift_mort/MORT/Features/Onboarding/OnboardingView.swift`
- `swift_mort/MORTTests/SessionRoutingTests.swift`
- `swift_mort/MORTTests/MissionPilotContractTests.swift`
- `swift_mort/scripts/static-audit.ps1`
- `swift_mort/MORT.xcodeproj/project.pbxproj`

## Flutter Web/PWA

- `flutter_mort/lib/data/models/mission_pilot.dart`
- `flutter_mort/lib/data/repositories/mission_pilot_repository.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/data/models/profile.dart`
- `flutter_mort/lib/data/repositories/profile_repository.dart`
- `flutter_mort/lib/features/mission/mission_pilot_screens.dart`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/test/mission_pilot_test.dart`
- `docs/WEB_BUILD_CONFIG_STATUS.md`

## Documentation

The 18 requested mission/pilot/safety/document/privacy policies plus the five implementation, advisor, RLS/storage, validation, and changed-file reports are included under `docs/`.
