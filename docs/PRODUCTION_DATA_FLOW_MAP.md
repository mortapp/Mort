# MORT Production Data Flow Map

Audit date: 2026-08-29. Every entry is evidence-grounded (file paths cited); anything not directly verifiable from code is marked UNVERIFIED. "Dependency present" and "actively wired into the shipping build" are tracked separately — several integrations here are backend/SDK foundations that are **not yet reachable** in the current shipping build.

## Ground truth: the current shipping release profile

The single most load-bearing fact for this whole document is `scripts/build-standard-closed-test-apk.ps1`, which is what `.github/workflows/mort-signed-closed-test.yml` actually builds today:

```
-ReleaseStage closed_test  -OperationalMode closed_pilot  -ArtifactKind Apk
-PlayReviewModeEnabled $false
-GoogleAuthEnabled $true
-PublicMarketplaceEnabled $false
-IdentityVerificationEnabled $false
-RemotePushEnabled $false
-CrashReportingEnabled $false
-PublicActivationApproved $false
-AdsEnabled $false
```

`scripts/build-production-pilot-aab.ps1` (the next stage up) additionally hard-fails today because `flutter_mort/lib/core/observability/production_crash_provider.dart` and `flutter_mort/lib/features/notifications/remote_push_service.dart` do not exist in the repo — so even the pilot profile that would turn on push/crash/ads cannot currently build. `scripts/build-production-public-aab.ps1` unconditionally throws `BLOCKED-EXTERNAL: public production requires approved identity provider, legal terms, moderation operations, native QA, push/crash providers, and audited server activation.`

That means, as of today, only Google Sign-In is actually active among the optional integrations below; everything else optional is off.

## Integrations

### Supabase Auth
```
ACTIVE_IN_PRODUCTION=YES
DATA_SENT=email, password hash (managed by Supabase Auth), session/refresh tokens, JWT claims
PURPOSE=authentication, session management
REQUIRED_OR_OPTIONAL=required
PROVIDER=Supabase (rakjydmgwwgtdislanbt)
DISCLOSURE=covered generally by scripts/build-public-legal-site.mjs privacy page ("Account ID, email...")
DATA_SAFETY_CATEGORY=Personal info (email address, user IDs)
RETENTION=until account deletion; see ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md
DELETION_BEHAVIOR=auth.users row deleted by supabase/functions/account-deletion-processor/index.ts via auth.admin.deleteUser()
EVIDENCE=lib/data/repositories (Supabase client usage throughout), supabase/functions/account-deletion-processor/index.ts
```

### Supabase Database (Postgres)
```
ACTIVE_IN_PRODUCTION=YES
DATA_SENT=the entire application data model -- profiles, jobs, applications, messages, reviews, reports, safety records, legal acceptances, etc.
PURPOSE=all product functionality
REQUIRED_OR_OPTIONAL=required
PROVIDER=Supabase (rakjydmgwwgtdislanbt)
DISCLOSURE=privacy page covers major categories at a high level
DATA_SAFETY_CATEGORY=multiple (personal info, app activity, messages, financial info)
RETENTION=varies by table; see DATA_RETENTION_REGISTRY.md (to be produced) and ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md
DELETION_BEHAVIOR=cascades from auth.users -> profiles for most tables; see the deletion audit for the RESTRICT-constraint finding being fixed separately (cross-reference below)
EVIDENCE=supabase/migrations/*.sql (194 files)
```

### Supabase Storage
```
ACTIVE_IN_PRODUCTION=YES
DATA_SENT=avatars, job proof photos, support/incident evidence attachments
PURPOSE=user-uploaded media
REQUIRED_OR_OPTIONAL=optional (avatar), situational (proof/evidence uploads tied to specific flows)
PROVIDER=Supabase
DISCLOSURE=privacy page mentions "optional profile image" and "proofs"
DATA_SAFETY_CATEGORY=Photos and videos
RETENTION=owned objects removed by the deletion worker (supabase/functions/account-deletion-processor/index.ts removeOwnedStorage); evidence buckets have separate restricted-access policies
DELETION_BEHAVIOR=explicit paginated removal in the deletion worker, not just DB cascade
EVIDENCE=supabase/functions/account-deletion-processor/index.ts, supabase/migrations/20260728223111_account_deletion_storage_listing_rpc.sql
```

### Supabase Edge Functions (Deno)
```
ACTIVE_IN_PRODUCTION=YES (at least account-deletion-processor; others exist for Stripe Connect)
DATA_SENT=varies per function
PURPOSE=server-side operations requiring service-role privileges (account deletion worker, Stripe Connect account status)
REQUIRED_OR_OPTIONAL=required for the flows they serve
PROVIDER=Supabase
DISCLOSURE=not separately disclosed as "edge functions" -- covered by the general backend description
DATA_SAFETY_CATEGORY=N/A (infrastructure, not a distinct data category)
RETENTION=N/A
DELETION_BEHAVIOR=N/A
EVIDENCE=supabase/functions/account-deletion-processor/index.ts, supabase/functions/stripe-create-connected-account, supabase/functions/stripe-get-connected-account-status
```

### Google Sign-In / OAuth
```
ACTIVE_IN_PRODUCTION=YES (GoogleAuthEnabled=$true in the current closed_test build)
DATA_SENT=Google account email and profile info exchanged during OAuth; no google_sign_in native SDK is used
PURPOSE=alternative authentication method
REQUIRED_OR_OPTIONAL=optional (email/password auth also exists)
PROVIDER=Google, brokered through Supabase Auth (PKCE, browser-based OAuth)
DISCLOSURE=NOT currently mentioned by name in the public-site privacy page (scripts/build-public-legal-site.mjs) -- gap to fix in the Privacy Policy rewrite
DATA_SAFETY_CATEGORY=Personal info (email address), App activity (if scopes beyond basic profile are requested -- UNVERIFIED, would need the actual OAuth consent screen scopes)
RETENTION=same as any auth identity -- tied to the Supabase auth.identities row, cascades on auth.users deletion
DELETION_BEHAVIOR=auth.identities has ON DELETE CASCADE from auth.users (verified via pg_constraint)
EVIDENCE=scripts/android-release-profile-common.ps1 GoogleAuthEnabled forbidden-secret guard, flutter_mort/lib/core/config/app_config.dart:187-188 (googleAuthEnabled = bool.fromEnvironment('GOOGLE_AUTH_ENABLED')), scripts/build-standard-closed-test-apk.ps1 (-GoogleAuthEnabled $true); NOT in flutter_mort/pubspec.yaml as a native SDK (no google_sign_in package) -- confirms it's the Supabase-brokered browser OAuth flow, not a native Google SDK integration
```

### Firebase / FCM (push notifications)
```
ACTIVE_IN_PRODUCTION=NO
DATA_SENT=none currently -- no push is sent
PURPOSE=would be remote push notification delivery
REQUIRED_OR_OPTIONAL=N/A (disabled)
PROVIDER=Firebase / Google
DISCLOSURE=not disclosed; would need disclosure once activated
DATA_SAFETY_CATEGORY=Device or other IDs (push token) -- once active
RETENTION=N/A while inactive
DELETION_BEHAVIOR=push_tokens table has ON DELETE CASCADE from profiles (verified), so tokens are removed on deletion whenever they exist
EVIDENCE=firebase_core/firebase_messaging ARE in flutter_mort/pubspec.yaml, and supabase/migrations/20260730090000_fcm_remote_push_foundation.sql + 20260730091000_fcm_device_limit_hardening.sql build the full backend (push_tokens table, device-limit hardening) -- but: (1) no flutter_mort/android/app/google-services.json exists in the repo or is injected by any CI workflow or build script (grep across .github/workflows/*.yml and scripts/*.ps1 found zero references), so the Firebase SDK cannot initialize; (2) scripts/build-standard-closed-test-apk.ps1 passes -RemotePushEnabled $false for the actual current shipping build; (3) scripts/build-production-pilot-aab.ps1, which would set RemotePushEnabled=$true, hard-fails at the top because flutter_mort/lib/features/notifications/remote_push_service.dart does not exist. Net: this is a real, substantial backend foundation with no live client wiring yet.
```

### RevenueCat
```
ACTIVE_IN_PRODUCTION=NO
DATA_SENT=none currently
PURPOSE=would be subscription/entitlement management
REQUIRED_OR_OPTIONAL=N/A (no client integration exists)
PROVIDER=RevenueCat
DISCLOSURE=not disclosed
DATA_SAFETY_CATEGORY=N/A while inactive
RETENTION=N/A
DELETION_BEHAVIOR=revenuecat_events (SET NULL) and revenuecat_product_states (CASCADE) tables exist and would need real deletion behavior once live
EVIDENCE=NO revenuecat or purchases_flutter (or any RevenueCat SDK) package in flutter_mort/pubspec.yaml. Backend-only foundation: supabase/migrations reference revenuecat_events, revenuecat_product_states, subscription_entitlements, subscription_events, user_subscription_status tables and a webhook handler exist, but there is no client-side purchase flow to originate real events. This is a backend-foundation-only integration -- membership/Stage 2 work (per the continuation directive) needs to audit this table set before building a client, not assume it's wired.
```

### Google Play Billing / in-app purchases
```
ACTIVE_IN_PRODUCTION=NO
DATA_SENT=none currently
PURPOSE=would be digital purchase processing
REQUIRED_OR_OPTIONAL=N/A
PROVIDER=Google Play
DISCLOSURE=not disclosed
DATA_SAFETY_CATEGORY=Financial info (purchase history), once active
RETENTION=N/A
DELETION_BEHAVIOR=N/A
EVIDENCE=no in_app_purchase or billing_client package in flutter_mort/pubspec.yaml. play_billing_runtime_controls table exists in migrations (backend foundation only, same pattern as RevenueCat above).
```

### Ads / AdMob (google_mobile_ads)
```
ACTIVE_IN_PRODUCTION=NO (in the current closed_test build); planned ON for production_pilot
DATA_SENT=when active: ad request data via Google Mobile Ads SDK; app-ads.txt declares publisher ID pub-9883419411387958 (real, confirmed, not a placeholder per scripts/build-public-legal-site.mjs comment)
PURPOSE=advertising revenue (a "MORT Spark" rewarded-ad cosmetic feature is described in the drafted privacy copy)
REQUIRED_OR_OPTIONAL=optional feature; policy text explicitly excludes ads from safety/reporting/Guardian/messages/payment/PIN/legal screens
PROVIDER=Google (AdMob)
DISCLOSURE=already drafted in scripts/build-public-legal-site.mjs privacy/index.html (see "Advertising" section) -- this is a good, specific, already-written disclosure to reuse verbatim rather than rewrite
DATA_SAFETY_CATEGORY=App activity / Device or other IDs (ad-serving), depending on final SDK configuration; note AndroidManifest.xml explicitly removes AD_ID, ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS permissions via tools:node="remove" -- confirms an intentional privacy-hardened default
RETENTION=third-party (Google) -- MORT does not store ad-serving data server-side per the drafted copy
DELETION_BEHAVIOR=ad_impressions/ad_click_events use SET NULL from profiles; ad_frequency_caps uses CASCADE
EVIDENCE=flutter_mort/pubspec.yaml (google_mobile_ads: ^5.3.1), flutter_mort/android/app/src/main/AndroidManifest.xml (AD_ID permission removals), flutter_mort/lib/core/config/app_config.dart:283-284 (adsEnabled = bool.fromEnvironment('ADS_ENABLED')) and lines 404-409 (ad init gated on adsEnabled), scripts/build-standard-closed-test-apk.ps1 (-AdsEnabled $false), scripts/build-production-pilot-aab.ps1 (-AdsEnabled $true, but this profile cannot currently build -- see Firebase section), scripts/build-public-legal-site.mjs line ~336 (app-ads.txt)
```

### Analytics / crash reporting (Sentry)
```
ACTIVE_IN_PRODUCTION=NO
DATA_SENT=none currently
PURPOSE=would be crash reporting and error diagnostics
REQUIRED_OR_OPTIONAL=N/A while inactive
PROVIDER=Sentry
DISCLOSURE=not disclosed
DATA_SAFETY_CATEGORY=Diagnostics / Crash logs, once active
RETENTION=N/A
DELETION_BEHAVIOR=N/A
EVIDENCE=sentry_flutter is in flutter_mort/pubspec.yaml; scripts/build-standard-closed-test-apk.ps1 passes -CrashReportingEnabled $false; scripts/build-production-pilot-aab.ps1 requires flutter_mort/lib/core/observability/production_crash_provider.dart to exist before it will even attempt that build stage, and that file does not exist in the repo. Same "dependency present, not wired" pattern as Firebase.
```

### Location (geolocator, geocoding)
```
ACTIVE_IN_PRODUCTION=PARTIAL
DATA_SENT=coarse/approximate area for general use; job-context "private location" and "temporary active-job safety location" for specific workflows (job_private_locations, job_location_share_sessions tables)
PURPOSE=general area display, job-site coordination, active-job safety location sharing
REQUIRED_OR_OPTIONAL=optional for general browsing; the app requests both ACCESS_COARSE_LOCATION and ACCESS_FINE_LOCATION in the manifest
DISCLOSURE=already drafted: "Approximate area and optional foreground location when a user invokes a location feature. Background location is not collected." (scripts/build-public-legal-site.mjs privacy page)
DATA_SAFETY_CATEGORY=Location (approximate and/or precise, depending on which permission the user grants and which feature is invoked) -- UNVERIFIED which specific screens actually request ACCESS_FINE_LOCATION vs ACCESS_COARSE_LOCATION; both permissions are declared in the manifest so precise location is at least requestable
RETENTION=job_location_share_sessions is presumably session-scoped (time-limited); UNVERIFIED exact TTL -- needs a read of the migration for exact expiry logic
DELETION_BEHAVIOR=job_location_share_sessions and job_private_locations both CASCADE from profiles
EVIDENCE=flutter_mort/pubspec.yaml (geolocator ^14.0.3, geocoding ^5.0.0), flutter_mort/android/app/src/main/AndroidManifest.xml (ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION), supabase/migrations/20260819000000_job_site_precise_location_and_distance.sql, job_private_locations / job_location_share_sessions tables (pg_constraint dump)
```

### Maps
```
ACTIVE_IN_PRODUCTION=NO
EVIDENCE=no maps SDK (google_maps_flutter or similar) found in flutter_mort/pubspec.yaml
```

### Image upload / camera / photo picker
```
ACTIVE_IN_PRODUCTION=YES
DATA_SENT=user-selected/captured photos (avatar, job proof)
PURPOSE=avatar upload, job completion proof
REQUIRED_OR_OPTIONAL=optional (avatar), situational (proof)
PROVIDER=on-device (image_picker), stored in Supabase Storage
DISCLOSURE=drafted privacy copy mentions "optional profile image" and "proofs"
DATA_SAFETY_CATEGORY=Photos and videos
RETENTION=owned storage objects removed by the deletion worker
DELETION_BEHAVIOR=see Supabase Storage entry above
EVIDENCE=flutter_mort/pubspec.yaml (image_picker ^1.2.3), AndroidManifest.xml CAMERA permission, proof_uploads table (CASCADE from profiles)
```

### Support tools / AI provider
```
ACTIVE_IN_PRODUCTION=PARTIAL -- deterministic support is real; live third-party AI provider calls are gated by a runtime flag and circuit breaker, not proven always-on
DATA_SENT=support message text (classified by a SQL-based, in-database classifier -- private.support_classify_message -- not an external network call) when the deterministic path is used; if the AI provider path is enabled, message text would go to that provider
PURPOSE=customer support triage and response
REQUIRED_OR_OPTIONAL=optional (users can also reach a human via support tickets)
PROVIDER=first-party deterministic classifier is in-database SQL (no external network call for classification itself); an actual external AI provider (name UNVERIFIED from this audit -- no explicit "anthropic" or "openai" string found in a quick pass, would need a dedicated read of the edge functions calling out) is gated by MORT_SUPPORT_AI_ENABLED / chatbotAiEnabled and a database-backed circuit breaker (support_provider_circuit_status / support_record_provider_failure, added in 20260812010000_support_ai_hardening_followup.sql)
DISCLOSURE=not currently disclosed as "AI" in the drafted public policy pages
DATA_SAFETY_CATEGORY=Messages (support conversations)
RETENTION=support_user_preferences.retention_days-driven (per-user configurable; QA fixtures show a "save_history"/retention_days pattern); UNVERIFIED exact default
DELETION_BEHAVIOR=support_conversations CASCADE from profiles; support_messages SET NULL (author_id) -- meaning ticket content can outlive the identity of who wrote it, consistent with the RESTRICT-to-SET-NULL pattern being applied elsewhere for support_attachments/support_evidence_attachments/support_internal_notes (see cross-reference below)
EVIDENCE=supabase/migrations/20260729195632_mort_support_chatbot_foundation.sql through 20260817120000_support_ai_account_wording_coverage_fix.sql (a long hardening series), 20260812010000_support_ai_hardening_followup.sql (classifier + circuit breaker), flutter_mort/lib/core/config/app_config.dart chatbotAiEnabled = bool.fromEnvironment(...). This needs a follow-up, more targeted audit specifically to name the actual external provider (if any) before the Privacy Policy can make a specific "MORT uses AI provider X" claim -- for now, treat as UNVERIFIED whether an external network call to a named third-party AI vendor is live versus the support flow being entirely deterministic/in-database today.
```

### Identity provider / government ID verification
```
ACTIVE_IN_PRODUCTION=NO (IdentityVerificationEnabled=$false in the current closed_test build)
DATA_SENT=none currently for real ID documents
PURPOSE=would be adult/business identity verification for marketplace trust
REQUIRED_OR_OPTIONAL=N/A while disabled
PROVIDER=UNVERIFIED (identity_verification_provider_safe_foundation.sql suggests a provider-neutral foundation was built, not necessarily a live integration)
DISCLOSURE=already correctly drafted: "Real government-ID images, face templates, provider identity verification... are disabled in this release." (privacy page)
DATA_SAFETY_CATEGORY=N/A while disabled
RETENTION=identity_verifications rows exist for sandbox/QA testing (environment='sandbox') per feature-qa-helpers.mjs, distinct from any real production collection
DELETION_BEHAVIOR=identity_verifications CASCADE from profiles; identity_verification_evidence is being converted from RESTRICT to SET NULL (see cross-reference below)
EVIDENCE=scripts/android-release-profile-common.ps1 (-IdentityVerificationEnabled param, required and validated), supabase/migrations/20260718051719_identity_verification_provider_safe_foundation.sql, supabase/migrations/20260730110000_identity_provider_neutral_completion.sql, scripts/build-standard-closed-test-apk.ps1 (-IdentityVerificationEnabled $false)
```

### Stripe
```
ACTIVE_IN_PRODUCTION=NO for job payments; PARTIAL for Connect account onboarding infrastructure
DATA_SENT=Stripe Connect account creation/status calls exist as Edge Functions, but the whole job-payment path is explicitly zero-fee/disabled
PURPOSE=would be job payment processing and/or platform fee collection
REQUIRED_OR_OPTIONAL=N/A -- MORT does not process or hold job payment money today
PROVIDER=Stripe
DISCLOSURE=already correctly drafted: "MORT does not hold, transfer, or guarantee money" and the dedicated payment-disputes page explicitly says "MORT records agreed payment terms... It does not hold funds, provide escrow, guarantee payment, collect cards..."
DATA_SAFETY_CATEGORY=N/A for job payments; Financial info if/when digital purchases (separate from job payments) go live via RevenueCat/Play Billing
RETENTION=Stripe-linked tables (private.stripe_customers, stripe_connected_accounts, stripe_account_onboarding_sessions, etc.) are financial records the deletion worker defers via a dedicated hold mechanism (service_check_account_deletion_financial_retention / service_hold_account_deletion_for_financial_retention in supabase/functions/account-deletion-processor/index.ts) rather than deleting immediately. The hold only inspects stripe_connected_accounts/stripe_customers/stripe_job_payment_intents; the other five Stripe/staff tables that reference auth.users were, until this session's fix, ON DELETE RESTRICT with no corresponding hold check -- see the cross-reference below and ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md for the corrected, verified state (all eight now ON DELETE SET NULL, locally validated, not yet deployed to hosted)
DELETION_BEHAVIOR=deferred via financial-retention hold for the three tables it checks; deidentified via ON DELETE SET NULL for all eight once the fix migration is deployed (not cascaded, not RESTRICT)
EVIDENCE=supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql, 20260728220236_mort_payments_disabled_zero_fee.sql, 20260728221118_fix_payment_disabled_transportation_wrapper.sql, supabase/functions/stripe-create-connected-account, supabase/functions/stripe-get-connected-account-status, supabase/functions/account-deletion-processor/index.ts (financial retention check)
```

## Cross-reference: account deletion RESTRICT-constraint fix

While researching Supabase Database and the RESTRICT-linked tables above, this audit found that `auth.admin.deleteUser()` (the real call the account-deletion worker makes) fails for any account with a `legal_acceptances` row -- which is effectively every onboarded user -- because that table (and ~76 other columns across ~50 tables) use `ON DELETE RESTRICT` toward `profiles(id)`, blocking the cascade from `auth.users`. This was verified empirically against a local test user (not just read from code).

This is being fixed in a separate migration (converting the RESTRICT constraints to SET NULL, preserving row content while detaching the identity reference, mirroring the existing `account_deletion_requests.user_id` pattern) -- **not** by this audit. See the account deletion implementation audit and the coordinator's migration work for the authoritative fix status; do not assume it is fixed as of this document's write time without checking current migration state.
