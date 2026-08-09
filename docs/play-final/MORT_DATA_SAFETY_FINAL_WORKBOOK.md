> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM

# Data Safety Final Workbook

This workbook is a code/schema recommendation for version `0.9.14+104`. The adult owner must compare it to the exact Play-accepted AAB and hosted processor contracts.

| Category | Collected | Shared | Purpose | Required | Ephemeral | Transit | Retention | Deletion | Code/table path | Storage path |
|---|---|---|---|---|---|---|---|---|---|---|
| Legal/profile name | Yes | No sale; Supabase processor | Account/profile and job attribution | Required/optional by role | No | HTTPS | Account lifecycle; narrow retained evidence where legitimate | Deleted or deidentified through deletion workflow | profile_repository.dart; profiles | profile-avatars |
| Email | Yes | No sale; Supabase processor | Auth, recovery, service notices | Required | No | HTTPS | Account lifecycle/security retention | Auth deletion workflow | Supabase Auth | None |
| Phone | Optional | No sale; Supabase processor | Optional trust/recovery flow | Optional | No | HTTPS | Until removed/deletion | User/deletion control | Auth/profile trust flows | None |
| Age band/private DOB | Yes | No sale; Supabase processor | 13+ gate and role safety | Required | No | HTTPS | Account lifecycle/audit | Deletion with narrow compliance retention | onboarding; profiles.date_of_birth/age_band | None |
| Account ID | Yes | No sale; Supabase processor | Authorization and audit | Required | No | HTTPS | Account/audit lifecycle | Deleted/deidentified where allowed | auth.uid; foreign keys | None |
| Profile image | Optional | No sale; Supabase processor | Profile | Optional | No | HTTPS | Until removed/deletion | Owner remove/deletion | avatar_repository.dart | profile-avatars |
| Approximate location | Optional | No sale; Supabase processor | Nearby/manual-area matching | Optional | No | HTTPS | Profile/job lifecycle | Edit/deletion | jobs/profile/location repositories | None |
| Temporary precise location | Optional | Authorized recipient only; Supabase processor | Foreground active-job safety | Optional | Yes after expiry | HTTPS | Short-lived session/audit | Expiry/stop/deletion rules | trust_safety_repository.dart; job_location_share_sessions | None |
| Messages/media | Yes when used | Participants/moderators as authorized; Supabase processor | Job coordination and safety | Optional feature | No | HTTPS | Conversation/safety retention | Deletion with narrow evidence retention | messaging_repository.dart; messages | report-uploads/incident-evidence when submitted |
| Jobs/applications/contracts | Yes | Matched participants; Supabase processor | Pilot marketplace workflow | Required to transact | No | HTTPS | Transaction/dispute lifecycle | Deletion/deidentification subject to obligations | jobs/applications/legal repositories | proof-uploads |
| Reviews/reports/support | Optional | Authorized users/moderators; Supabase processor | Trust, safety, support | Optional | No | HTTPS | Moderation/safety/support policy | Delete ordinary data; retain narrow evidence | reviews/safety/support repositories | report-uploads/incident-evidence |
| Work/payment history | When work used | Participants/moderators as authorized; Supabase processor | Completion and obligation record | Required for workflow | No | HTTPS | Transaction/dispute lifecycle | Deletion/deidentification subject to disputes | contracts, obligations, disputes | proof-uploads |
| Device/session/diagnostics | Yes/limited | Supabase and OS providers as needed | Security, auth, crash investigation | Required for security | Some ephemeral | HTTPS | Security retention | Expiry/deletion where applicable | Supabase auth; device_info; security events | None |
| Organization affiliation | Optional | Organization staff and participant as scoped; Supabase processor | Pilot eligibility/support | Optional | No | HTTPS | Membership/attestation expiry | Revocation/deletion rules | mission_pilot_repository.dart; partner tables | None |
| Guardian/Support Circle | Optional | Only linked authorized users; Supabase processor | Optional support and safety | Optional | No | HTTPS | Until unlink/deletion | Unlink/deletion | guardian_repository.dart; support_circle tables | None |

Bundled SDK conclusion: Supabase, secure storage, local auth, image picker,
geolocation/geocoding, Firebase Core/Messaging, Sentry, device/package info, URL
launcher, cached images, and Flutter runtime remain. Firebase remote push and
Sentry crash reporting are fail-closed and uninitialized in the closed-test
profile. AdMob and RevenueCat SDKs are not bundled. Verify the final dependency,
Play SDK Index, and bundle reports before checking Play fields.

- [ ] Owner confirms each category against the exact accepted AAB.
- [ ] Owner confirms encryption, retention, deletion, and processor statements.
- [ ] Owner reruns this audit after any SDK, permission, schema, or policy change.
