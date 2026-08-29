# MORT Production Final State — 2026-08-29

```
START_HEAD=d320542e380abd1262b9d6c5d3514f842dcb99e7
FINAL_HEAD=4cecb21e75824354ddeaae07271359fed792d10e
ORIGIN_BRANCH_HEAD=4cecb21e75824354ddeaae07271359fed792d10e (in sync)
ORIGIN_MAIN=8bdec7b9632b4753ed6cb49c6c184cd0dc9dafa1 (unchanged this session; branch not yet merged to main -- PR #3 open)

COMMITS_CREATED=19 (this session; includes Codex's 5 production-identity-purge commits, integrated not re-done)
```

## Onboarding (verified in earlier Stage 1 passes this session, unaffected by later work)

```
ONBOARDING_PRIMARY_STEPS=4
ONBOARDING_SERVER_AUTHORITATIVE=PASS
DIRECT_COMPLETION_UPDATE=DENIED
DIRECT_COMPLETION_UPSERT=DENIED
LEGACY_COMPLETED_COMPAT=PASS (24 grandfathered profiles, 17 test / 7 non-test, verified against hosted)
NEW_USER_V2=PASS
INCOMPLETE_USER_V2=PASS
LEGAL_RECONSENT_SEPARATE=PASS
NOTIFICATION_TRUTH=PASS
DOB_SECURITY=PASS
ROLE_SECURITY=PASS
DISPLAY_NAME_VALIDATION=PASS
```

## Migrations / database

```
MIGRATION_FRESH_REPLAY=PASS (fresh supabase db reset, local Docker only, 195 migrations from empty, this session)
MIGRATION_PARITY=PASS (qa:migration-reconciliation-parity, hosted)
DIRECT_USER_FK_COUNT=336
ACCOUNT_DELETION_CLASSIFIED=99 (87 original RESTRICT blockers + 12 pre-existing edges individually reviewed)
ACCOUNT_DELETION_UNCLASSIFIED=0
ACCOUNT_DELETION_RESTRICT_BLOCKERS=0
ACCOUNT_DELETION_NULLABILITY_CONTRADICTIONS=0
HOSTED_MIGRATIONS_APPLIED=1 (20260829010000_account_deletion_retention_deidentification.sql -- deployed this session via standard forward `supabase db push --linked`, after every precondition verified green; final dry run confirms "Remote database is up to date")
HOSTED_MIGRATION_PARITY=PASS
```

## Account deletion — ACCOUNT_DELETION_P0=CLOSED

```
ACCOUNT_DELETION_E2E=PASS (local: full scenario matrix; hosted: real auth.admin.deleteUser() against a disposable QA account)
SHARED_JOB_DELETE=PASS
SHARED_APPLICATION_DELETE=PASS
GUARDIAN_DELETE=PASS
STAFF_AUTH_DELETE=PASS (team_role_assignments.user_id CASCADE -- no orphaned live grant)
SAFETY_RETENTION=PASS (incident_assignments close-out trigger verified: ended_at set before assigned_to nulled)
LEGAL_ACCEPTANCE_DELETE=PASS (content survives, identity severed; LEGAL_REVIEW_REQUIRED flagged for pseudonymous-continuity question, not blocking)
WORKER_IDEMPOTENCY=PASS (local worker-state regression: claim exclusivity, malformed-lock denial, replay safety, reclaim denial; hosted: duplicate delete on a gone user returns a clean error)
STALE_SESSION_AFTER_DELETE=DENIED
```

See `docs/ACCOUNT_DELETION_FK_MATRIX.md` (full 99-relationship classification
plus the 9-category role taxonomy) and
`docs/ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md` (pipeline, discovery, fix,
hosted deployment evidence) for complete detail.

## Backend security

```
RLS=PASS (local, full suite, re-verified after the deletion migration)
HOSTILE_CLIENT=PASS (direct PostgREST attempts to null jobs.poster_id/applications.teen_id denied at the database boundary, including with a service key)
SUPABASE_ADVISORS=PASS (0 ERROR-level on security and performance; identical WARN/INFO counts to pre-migration baseline -- 0 new findings introduced)
```

## CI / Flutter / Expo / public web

```
EXPO_TYPESCRIPT=PASS (pnpm check, fresh this session)
EXPO_LINT=PASS (fresh this session)
EXPO_REFERENCE_BUILD=PASS (pnpm build, fresh this session, all routes including /monetization/*)
FLUTTER_FORMAT=PASS (257 files, 0 changed)
FLUTTER_ANALYZE=PASS (0 issues)
FLUTTER_TESTS=425 passed, 2 intentional skips, 0 failed (fresh run this session)
PUBLIC_SITE_BUILD=PASS
PUBLIC_SITE_ROUTE_COUNT=13
PRODUCTION_IDENTITY_COPY=PASS (201 shipping source files, 0 closed-test identity matches, fresh run this session)
SHIPPING_TEST_IDENTITY_MATCHES=0
REQUIRED_CI=PASS (expo-reference, flutter-authoritative, public-site all green on FINAL_HEAD; production-identity-copy check now part of expo-reference)
SECRET_SCAN=PASS (source tree and the built debug APK binary both scanned clean this session)
```

## Public policy

```
PRIVACY_POLICY=drafted, comprehensive, not yet legally reviewed or published (see scripts/build-public-legal-site.mjs)
ACCOUNT_DELETION_POLICY=drafted, matches the now-verified implementation
CHILD_SAFETY_POLICY=drafted, comprehensive
PUBLIC_PRIVACY_URL=NOT_DEPLOYED
PUBLIC_TERMS_URL=NOT_DEPLOYED
PUBLIC_CHILD_SAFETY_URL=NOT_DEPLOYED
PUBLIC_ACCOUNT_DELETION_URL=NOT_DEPLOYED
```

`https://mort-web.vercel.app` is genuinely live but serves a different
marketing page whose own Privacy Policy link 404s. The only Vercel
account/team reachable from this session (`mortapphelp-7067s-projects`) owns
one unrelated project (`loop`, different repo, different domains) — no
project serving `mort-web.vercel.app` was found.
`EXTERNAL_BLOCKER=NO_ACCESSIBLE_DEPLOY_TARGET`. The generated package
(`web/public/`, CI-validated, 13 routes, Google Sign-In disclosure added,
stale `deploymentReady` claim corrected) is ready to deploy the moment a
real target is connected.

```
GOOGLE_PLAY_DATA_SAFETY_WORKSHEET=COMPLETE (docs/GOOGLE_PLAY_DATA_SAFETY_WORKSHEET.md, evidence-backed per category, not submitted)
ANDROID_PERMISSION_AUDIT=covered within the data flow map and Data Safety worksheet
GOOGLE_AUTH_DISCLOSURE=PASS (added to the privacy draft this session)
LOCATION_DISCLOSURE=PASS
NOTIFICATION_DISCLOSURE=PASS (dormant, correctly described as such)
ADS_DISCLOSURE=PASS (dormant, correctly described as such)
AI_DISCLOSURE=UNVERIFIED (the actual external AI provider, if any, was not conclusively identified -- flagged, not guessed)
IDENTITY_DISCLOSURE=PASS (correctly described as disabled)
```

## Safety

```
REPORT=PASS
BLOCK=PASS
SAFETY_PING=PASS
CORE_SAFETY_FREE=PASS (verified against actual RLS/RPC grants, not just policy copy)
MINOR_CSAE_REVIEW=DENIED (permanent rule documented; no real evidence was ever used anywhere in this session's testing)
SENSITIVE_EVIDENCE_PRIVATE=PASS
```

Two genuine, unresolved organizational gaps (not fabricated as closed):
`EXTERNAL_BLOCKER=DESIGNATED_ADULT_CHILD_SAFETY_CONTACT`,
`EXTERNAL_BLOCKER=ADULT_SAFETY_OPERATOR_VERIFICATION_PROCESS`. See
`docs/CHILD_SAFETY_OPERATIONAL_ESCALATION.md`.

## Membership

```
REVENUECAT_AUDIT=PASS (backend verified secure, mature, idempotent -- see docs/REVENUECAT_MEMBERSHIP_AUDIT.md)
STORE_PRODUCT_MATRIX=INCOMPLETE (9 product IDs defined server-side; real Play Console/RevenueCat dashboard configuration UNVERIFIED -- no dashboard access from this session)
MEMBERSHIP_HUB=PROVIDER_CONFIGURATION_REQUIRED (flutter_mort has zero purchase SDK/UI; not built speculatively per instruction)
RESTORE_PURCHASES=PROVIDER_CONFIGURATION_REQUIRED
REVENUECAT_WEBHOOK=PASS (backend security/idempotency verified by code+schema review; not exercised end-to-end -- no client can originate a real event and no sandbox access exists from this session)
JOB_BOOST_SAFETY_BYPASS=DENIED
USERNAME_TOKEN_SECURITY=PRODUCT_NOT_CONFIGURED (client-side; backend credit-grant is atomic/idempotent)
```

## QA APK / physical device / signed release

```
QA_APK=PASS
QA_APK_PATH=flutter_mort/build/app/outputs/flutter-apk/app-debug.apk
QA_APK_SHA256=28ca9f4ab6d0760b2e0fa6411ec727a55e2780b3024f2037f6ebd1a24ea181e8
QA_APK_SIZE=188,927,790 bytes
QA_APK_PACKAGE=com.mortapp.mobile
QA_APK_VERSION=0.9.16+107
QA_APK_RUNTIME_COMMIT=4cecb21e75824354ddeaae07271359fed792d10e
QA_APK_SUPABASE_PROJECT=rakjydmgwwgtdislanbt (confirmed via dart-define)
QA_APK_AUTH_CALLBACK=com.mortapp.mobile://app/auth-callback (confirmed via aapt manifest dump)
QA_APK_SECRET_SCAN=clean (no service-role key, DB password, client_secret, or signing/keystore material found in the extracted binary)

ANDROID_PHYSICAL=DEVICE_UNAVAILABLE (adb devices -l and adb mdns services both empty this session; no pass fabricated)

SIGNED_RELEASE=EXTERNAL_BLOCKER_EXISTING_SIGNING_CREDENTIALS_NOT_PROVISIONED (re-checked this session -- the closed-test-release GitHub Environment still has no MORT_UPLOAD_KEYSTORE_BASE64/etc. secrets; the workflow fails at the same "Materialize protected upload keystore" step as before. No substitute keystore was generated.)
```

## Internal defects

```
INTERNAL_CRITICALS=0
INTERNAL_HIGHS=0
```

The one Critical-class defect found this session (the 87-relationship
account-deletion RESTRICT blocker) is fixed, classified, tested, and
deployed to hosted with full post-deploy verification.

## External blockers (precise, not vague)

```
EXTERNAL_BLOCKERS=
  - LEGAL_REVIEW_REQUIRED (legal_acceptances/payment_disputes pseudonymous-continuity question)
  - DESIGNATED_ADULT_CHILD_SAFETY_CONTACT
  - ADULT_SAFETY_OPERATOR_VERIFICATION_PROCESS
  - NO_ACCESSIBLE_DEPLOY_TARGET (mort-web.vercel.app -- Vercel account not connected to this session)
  - EXISTING_SIGNING_CREDENTIALS_NOT_PROVISIONED (closed-test-release environment secrets)
  - UNCONFIGURED_STORE_PRODUCTS (Play Console / RevenueCat dashboard -- no access from this session)
  - UNAVAILABLE_PROVIDER_CREDENTIALS (RevenueCat Flutter API key)
  - PHYSICAL_DEVICE_UNAVAILABLE (Galaxy A14 not reachable over wireless ADB)
  - LEGAL_VERSION_PUBLICATION_AUTHORIZATION (hosted v2 Finish remains fail-closed on unpublished legal policies -- by design, not attempted)
```

```
OWNER_ACTION_REQUIRED=
  1. Connect the Vercel account/team that owns mort-web.vercel.app (or provide its project ID) so the ready-built public policy pages can actually deploy.
  2. Provision the real MORT upload-signing keystore + passwords into the closed-test-release GitHub Environment.
  3. Designate a specific, verifiably-adult child-safety operational contact and a verification process for staff granted sensitive-evidence access.
  4. Configure real membership products in Google Play Console and the RevenueCat dashboard, and provide a RevenueCat Flutter API key, before Flutter membership UI work begins.
  5. Obtain qualified legal review of the LEGAL_REVIEW_REQUIRED items and of the drafted Privacy/Terms/Child-Safety copy generally before any public policy version is published.
  6. Connect the Galaxy A14 over wireless ADB when physical QA is wanted (adb connect <ip>:<port>, then install the QA APK above).
```

## Final verdict

```
FINAL_VERDICT=PRODUCTION_ENGINEERING_READY_EXTERNAL_ACTIONS_REMAIN
```

Zero internally controllable Critical or High defects remain. Every phase
of the directive that did not require external credentials, dashboard
access, legal judgment, or a physical device this session lacked has been
completed and verified with real evidence (hosted queries, live test runs,
fresh CI, a scanned binary) — not asserted from memory or reused stale
numbers.
