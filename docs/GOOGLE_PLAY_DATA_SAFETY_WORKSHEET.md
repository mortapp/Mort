# Google Play Data Safety Worksheet — 2026-08-29

**Not for submission.** This prepares exact owner answers for the Play
Console Data Safety form, grounded in `docs/PRODUCTION_DATA_FLOW_MAP.md` and
direct code/schema evidence. Every category below distinguishes "collected"
(the app/backend actually captures and stores it) from "shared" (transmitted
to a party outside MORT for their own purposes — MORT does not sell data and
this worksheet finds no category where a third party uses MORT data for its
own independent purposes beyond processing on MORT's behalf).

Reference build for "currently active": `scripts/build-standard-closed-test-apk.ps1`
(`-GoogleAuthEnabled $true`, `-PublicMarketplaceEnabled $false`,
`-IdentityVerificationEnabled $false`, `-RemotePushEnabled $false`,
`-CrashReportingEnabled $false`, `-AdsEnabled $false`) — the actual shipping
configuration as of this session, not the eventual production-pilot profile.

## Personal info

| Data type | Collected | Shared | Purpose | Required/Optional | Encrypted in transit | Deletion available | Evidence |
|---|---|---|---|---|---|---|---|
| Name (display name) | YES | NO | Account functionality, marketplace display | Required | YES (Supabase TLS) | YES (deidentified/deleted per FK matrix) | `public.profiles.display_name`; onboarding v2 `save_my_onboarding_account_v2` |
| Email address | YES | NO (Supabase Auth processes it on MORT's behalf; not shared for Supabase's own purposes) | Account creation, authentication | Required | YES | YES (`auth.users` row deleted by the deletion worker) | Supabase Auth, all sign-up/sign-in flows |
| User IDs | YES | NO | Account functionality | Required | YES | YES | `auth.users.id`, `public.profiles.id` |
| Phone number | NO | N/A | N/A | N/A | N/A | N/A | No phone/SMS field found in `public.profiles` or onboarding RPCs |
| Physical address | NO (no street-address field) | N/A | N/A | N/A | N/A | N/A | `city`/`state` only (see Location below); no street-address column exists |
| Race, ethnicity, religion, sexual orientation, political views | NO | N/A | N/A | N/A | N/A | N/A | No such fields anywhere in the schema |
| Other info (date of birth, age band, role) | YES | NO | Age/role eligibility enforcement (teen/adult/guardian gating), legal compliance | Required | YES | Partially — DOB is a protected, server-authoritative security boundary; profile deleted on account deletion, DOB does not survive deidentification anywhere in the FK matrix | `public.profiles.dob`, `role`; `20260730011600_require_explicit_onboarding_completion_flag.sql` and onboarding v2 completion gate |

## Financial info

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Purchase history | **NO** (currently) | N/A | N/A | N/A | RevenueCat/Play Billing are backend-foundation-only per the data flow map — no client SDK integration exists yet (`flutter_mort/pubspec.yaml` has neither `purchases_flutter` nor `in_app_purchase`). Re-audit before membership launch: this answer will become YES once a real purchase flow ships. |
| Payment info (card numbers, etc.) | NO | N/A | N/A | N/A | MORT does not process real-world job payments (`mort_payments_disabled_zero_fee.sql`) and has no card-collection UI. Any future digital purchases go through Google Play's own payment sheet, which MORT never sees. |

## Location

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Approximate location | YES | NO | General service area display, job-site coordination | Required for job-adjacent features, optional for browsing | `public.profiles.city`/`state`; `ACCESS_COARSE_LOCATION` in `AndroidManifest.xml` |
| Precise location | **PARTIAL — situational, not continuous** | NO | Job-site private location, active-job safety location sharing | Optional, feature-gated | `job_private_locations`, `job_location_share_sessions` tables; `ACCESS_FINE_LOCATION` is declared and requestable in the manifest, but only invoked for specific job-context/safety flows, never background collection. Data Safety form should answer "collected" for precise location given the permission is requestable and the feature exists, with purpose scoped to "App functionality" (job coordination/safety), not advertising or analytics. |

## Messages

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| In-app messages | YES | NO | Job-context communication between marketplace participants | Required for the messaging feature | `public.messages`, `message_threads`; server-authorized context rules (Phase 40) — not open/anonymous chat |
| SMS/MMS/other telephony messages | NO | N/A | N/A | N/A | No SMS integration found |

## Photos and videos

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Photos | YES | NO | Optional profile avatar, job-completion proof | Optional (avatar), situational (proof) | `image_picker` in `pubspec.yaml`; Supabase Storage buckets; `proof_uploads` table |
| Videos | PARTIAL | NO | `video_profile_job_hardening` migration (`20260802062226`) suggests video-profile support exists in the backend | Optional | Needs a targeted follow-up read of that migration and the corresponding Flutter screen before a final answer — flagged rather than guessed |

## Files and documents

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Files/docs | **NO** (currently) | N/A | N/A | N/A | Identity-verification evidence collection is disabled (`IdentityVerificationEnabled $false`); the schema (`identity_verification_evidence`, `document_capture_sessions`) exists as a provider-neutral foundation but is not live-collecting real documents in the current shipping build |

## App activity

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| App interactions (jobs posted/applied, reviews, reports) | YES | NO | Core marketplace functionality | Required for marketplace features | `public.jobs`, `applications`, `reviews`, `reports` |
| In-app search history | NO | N/A | N/A | N/A | No persisted search-history table found |
| Installed apps | NO | N/A | N/A | N/A | Not collected |
| Other user-generated content | YES (reviews, support tickets) | NO | Trust/safety, customer support | Optional | `public.reviews`, `support_conversations` |

## App info and performance

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Crash logs | **NO** (currently) | N/A | N/A | N/A | `sentry_flutter` is in `pubspec.yaml` but `-CrashReportingEnabled $false` in the current shipping build; `production_crash_provider.dart` (needed for the next release profile) does not exist yet in the repo. Re-audit before enabling. |
| Diagnostics | NO (currently) | N/A | N/A | N/A | Same as above |
| Other performance data | NO | N/A | N/A | N/A | No APM/performance-monitoring SDK found active |

## Device or other IDs

| Data type | Collected | Shared | Purpose | Required/Optional | Notes |
|---|---|---|---|---|---|
| Device or other IDs (push token) | **NO** (currently) | N/A | N/A | N/A | Firebase/FCM backend foundation exists (`push_tokens` table, `20260730090000_fcm_remote_push_foundation.sql`) but `-RemotePushEnabled $false` and no `google-services.json` ships in the current build — no live push token is ever generated. Re-audit before enabling; when active, disclose token collection for notification delivery, deletion via the deletion worker's token cleanup. |

## Not applicable / not collected at all

Contacts, calendar, audio files, health and fitness, web browsing history: no
code path, table, or SDK found for any of these. Not included as a
collected category.

## Ads

`AdsEnabled $false` in the current shipping build. `google_mobile_ads` is a
real dependency and `AndroidManifest.xml` explicitly *removes*
`AD_ID`/`ACCESS_ADSERVICES_*` permissions via `tools:node="remove"` —
confirming a deliberately privacy-hardened default, not an oversight. When
ads are enabled for a later release profile, the drafted privacy copy
(`scripts/build-public-legal-site.mjs`, "Advertising" section) already
describes the intended scope precisely (non-personalized for teens, excluded
from all safety/legal/payment/messaging screens) and should drive the Data
Safety "Ads or marketing" purpose answer at that time — **not answered YES
today**.

## Encryption and deletion, worksheet-wide

- **Encrypted in transit**: YES for every category above — all traffic goes
  through Supabase's HTTPS/TLS endpoints; no category uses a plaintext
  channel.
- **Users can request data deletion**: YES — in-app (Settings → Account →
  Delete account) and via the public web self-service flow (magic-link
  verified), both calling the same `request_account_deletion` /
  `service_*` pipeline verified in `ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md`.
  Ordinary personal data listed above is deleted or deidentified per the FK
  matrix; narrow safety/legal/financial records may be retained deidentified
  where the matrix specifies (see that document for the exact per-column
  disposition, not a blanket claim here).

## Explicitly NOT claimed in this worksheet

Per Policy Truth Law, this worksheet does not claim collection for AI
provider data sharing (the actual external AI provider, if any, was left
`UNVERIFIED` in the data flow map — needs a dedicated follow-up read of the
support Edge Functions before the Data Safety form's AI-related question,
if any, can be answered), identity verification (disabled), payments beyond
what Google Play's own payment sheet handles, or precise location as
continuous/background (it is not — only situational, job-context invocation).
