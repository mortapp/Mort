# MORT Swift Backend Contract Map

Status date: 2026-07-14

Backend project: `rakjydmgwwgtdislanbt`

The Swift app uses the existing hosted Supabase backend. This map describes client calls present in `swift_mort`; it does not authorize schema resets or destructive changes.

## Configuration boundary

| Client-safe setting | Swift source |
| --- | --- |
| Supabase HTTPS URL | `AppConfiguration`, injected through `Config/Secrets.xcconfig` |
| Supabase public client/anon key | `AppConfiguration`, injected through `Config/Secrets.xcconfig` |
| RevenueCat public iOS SDK key | `AppConfiguration`, injected through `Config/Secrets.xcconfig` |
| AdMob app/banner/rewarded IDs | `Config/Base.xcconfig`; public identifiers |

Server-only secrets are prohibited from the app and zip. This includes service-role credentials, database credentials, access tokens, RevenueCat secret API keys, webhook secrets, and AI provider keys.

## Repository map

| Swift repository | Backend contract |
| --- | --- |
| `AuthRepository` | Supabase Auth signup, signin, session restore, PKCE callback, password recovery, update password, signout |
| `ProfileRepository` | `profiles`, role profile tables, `payment_preferences`, username RPCs, `get_my_profile` |
| `JobRepository` | `jobs`, `job_status_events`, job draft/publish and lifecycle RPCs |
| `SavedJobRepository` | `saved_jobs` |
| `ApplicationRepository` | `applications`, `application_status_events`, eligibility/apply/transition RPCs |
| `MessageRepository` | `message_threads`, `messages`, Realtime changes, `send_safe_message` |
| `GuardianRepository` | guardian connections/preferences/private profile data and Guardian Mode RPCs |
| `SafetyRepository` | `reports`, `blocks`, `safety_pings` |
| `NotificationRepository` | in-app `notifications` rows and read timestamps |
| `ReviewRepository` | `reviews` with server/RLS enforcement |
| `SupportRepository` | support ticket RPC and user-visible `support_tickets` |
| `VerificationRepository` | `business_verifications` and private verification upload |
| `StorageRepository` | four private buckets plus `avatar-url` signed URL function |
| `MonetizationRepository` | entitlements, subscriptions, ad preferences/eligibility, paywall/ad events, username and boost credits |
| `AdminRepository` | server-authorized profile list, queue reads/writes, monetization overview |
| `PortfolioRepository` | intentionally unavailable because no shared backend portfolio contract exists |

## Direct table contracts

| Table | Swift use | Authorization expectation |
| --- | --- | --- |
| `profiles` | current/public profile reads and permitted profile updates | RLS plus protected-field trigger/RPC rules |
| `teen_profiles` | role row creation through `ProfileRepository` | owner and server policy |
| `adult_profiles` | adult/business subtype and business fields | owner and admin policy |
| `guardian_profiles` | guardian role row and private emergency contact | owner/admin; never public contact data |
| `payment_preferences` | preference-only details | owner and authorized job relationship only |
| `jobs` | feed, detail, poster jobs, admin queue | published visibility and poster/admin ownership rules |
| `job_status_events` | lifecycle timeline | authorized job participants/admin |
| `saved_jobs` | save, unsave, saved list | owner only |
| `applications` | teen/adult/guardian lists and detail | application participants/authorized guardian/admin |
| `application_status_events` | application timeline | authorized participants/admin |
| `message_threads` | conversation list | thread participants only |
| `messages` | paged thread messages | participants only; sending uses RPC scanner |
| `guardian_connections` | invite/link list | linked teen/guardian/admin only |
| `guardian_preferences` | selected alert/approval preferences | linked authorized accounts only |
| `reports` | submit and own report history; admin queue | reporter sees own status, admin moderates |
| `blocks` | block/unblock/list | blocker owns records; server applies interaction restrictions |
| `safety_pings` | teen check-in and guardian-authorized view | teen, preference-authorized guardian, admin |
| `reviews` | completed-job reviews and moderation | job participants plus approved/public visibility rules |
| `notifications` | recipient list/read state | recipient only; server creates events |
| `support_tickets` | requester list and admin queue | requester/support admin |
| `business_verifications` | submit/status/admin review | submitting adult and admin |
| `user_ad_preferences` | age-restricted and personalization preference | owner only |
| `user_subscription_status` | backend-confirmed subscription cache | owner/admin; never a client purchase-success write |

Role-profile creation also uses the dynamic `teen_profiles`, `adult_profiles`, or `guardian_profiles` table selected from a closed enum. It is not selected from user-controlled text.

## RPC contracts used by Swift

| RPC | Purpose |
| --- | --- |
| `get_my_profile` | Return the caller's protected profile projection |
| `admin_list_profiles` | Server-authorized admin profile projection |
| `create_guardian_invite_v2` | Create optional guardian invite |
| `accept_guardian_invite` | Accept invite code |
| `cancel_guardian_invite` | Cancel pending link |
| `resend_guardian_invite` | Rotate/resend pending invite |
| `unlink_guardian` | Remove authorized connection |
| `set_guardian_setup_skipped` | Record optional skip without blocking account use |
| `get_guardian_policy_for_user` | Resolve linked/paused/approval policy |
| `set_teen_pause` | Authorized guardian pause/resume |
| `save_job_draft_or_publish` | Validate and atomically save draft or publish |
| `manage_job` | Pause, resume, close applications, duplicate, delete draft, or cancel |
| `get_job_application_eligibility` | Structured eligibility and denial reason |
| `submit_job_application` | Submit proposal and availability |
| `update_application_status_v2` | Role-authorized application transitions |
| `submit_application_proof` | Bind a private uploaded object to an application transactionally |
| `review_application_proof` | Poster-only approve, request-resubmission, or reject action with meaningful notes, stale-proof protection, and event audit |
| `get_my_message_threads` | Participant-only thread projection with server-authoritative incoming unread counts |
| `mark_message_thread_read` | Advance only the caller's participant cursor monotonically and idempotently |
| `send_safe_message` | Server-side rules/AI-assisted safety scan and send |
| `create_support_ticket` | Create auditable support/deletion request |
| `submit_business_verification` | Bind private evidence to a verification request |
| `get_my_entitlements` | Backend entitlement view |
| `record_paywall_event` | Optional paywall analytics event |
| `get_ad_eligibility` | Server gate for placement/format/age/consent/frequency |
| `record_ad_impression` | Record a loaded eligible ad impression |
| `record_feature_usage` | Record permitted premium feature usage |
| `admin_monetization_overview` | Server-authorized aggregate overview |
| `get_username_change_status` | Free/paid credit status |
| `request_username_change` | Validated username change |
| `get_job_boost_credit_status` | Available/used boost credits |
| `consume_job_boost_credit` | Apply one backend-confirmed credit to an eligible job |

## Private storage

| Bucket | Swift behavior |
| --- | --- |
| `profile-avatars` | owner upload/remove; signed own URL; other approved profiles use `avatar-url` |
| `proof-uploads` | teen owner path, JPEG metadata removal, RPC-bound proof row, participant-authorized short-lived review URL, orphan cleanup attempt |
| `verification-uploads` | adult owner path, private evidence, RPC-bound verification row, orphan cleanup attempt |
| `report-uploads` | recognized by signed URL allowlist; report attachment UI is not implemented |

All four buckets must remain private. Storage upsert/replacement policy needs INSERT, SELECT, and UPDATE where replacement is permitted; the Swift avatar flow currently creates a new object, updates the profile, then removes the previous object.

## Edge Functions

| Function | Native use/status |
| --- | --- |
| `avatar-url` | Invoked for authorized signed avatar URLs |
| `revenuecat-webhook` | Server-side entitlement source; native client never receives its secret |
| `send-push` | Existing Expo push delivery; not an APNs provider |
| `ai-safety` | Backend safety architecture; message send still goes through the database RPC |
| `ai-risk-score` | Not deployed; legacy fake-success scaffold removed |
| `ai-recommendations` | Not deployed; legacy fake-success scaffold removed |
| `ai-support` | Existing server capability; support ticket flow remains available without it |

## Known contract gaps

- `push_tokens.expo_push_token` and `send-push` are Expo-specific. Swift captures an APNs token in memory but intentionally does not persist it. Add new native token fields/table and an APNs provider additively.
- No portfolio table/RPC exists.
- No privacy-reviewed adult analytics API exists.
- Proof review now uses `review_application_proof`, append-only `proof_review_events`, private decision notifications, stale-submission rejection, and a completion trigger that requires approved proof where expected.
- Message unread state now uses participant `last_read_at`, `get_my_message_threads`, and `mark_message_thread_read`; own messages do not inflate unread counts and outsiders cannot discover or alter participant state.
- Existing notification producers emit camel-case identifiers for threads, jobs, applications, guardian links, reviews, verification, reports, support tickets, and safety pings. Swift now maps those shapes through one role-aware resolver and accepts the same contract through `mort://notifications` links. APNs token storage/provider delivery remains a separate missing contract.
- No self-service account deletion RPC exists; Swift creates an auditable support request.
- Generic admin queue updates are server-authorized, but full evidence/detail/action contracts remain incomplete.

## Verification boundary

The contracts above were traced statically to repository calls and the existing SQL/function source. No schema reset or destructive remote action was performed in this Swift migration pass. Native integration still requires authenticated Mac/iPhone QA against hosted Supabase and explicit cross-account RLS denial tests.
