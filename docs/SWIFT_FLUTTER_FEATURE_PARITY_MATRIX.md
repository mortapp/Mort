# MORT Flutter to Swift Feature Parity Matrix

Status date: 2026-07-17

This is source-level migration accounting, not a claim that the iOS app builds or runs. `Static: pass` means the Swift source and referenced backend contract were inspected on Windows and included in the generated Xcode project. Every implemented row still requires a real Mac/Xcode build. User-facing rows also require physical iPhone verification.

Status meanings:

- `Implemented`: a concrete Swift implementation exists.
- `Partial`: useful source exists, but the complete feature contract does not.
- `Missing`: no honest end-to-end implementation exists.
- `Wired`: calls the existing Supabase/SDK contract rather than returning fake success.
- `Local`: native UI or device logic only; no backend write is expected.

| # | Feature | Flutter reference | Swift implementation | Backend/API | Swift status | Wiring | Static | Mac | iPhone |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Startup/config failure state | `lib/app.dart`, `mort_screens.dart` | `AppBootstrap.swift`, `MORTApp.swift`, `RootView.swift` | client-safe xcconfig | Implemented | Local | pass | required | required |
| 2 | Signup and email confirmation | `mort_screens.dart` | `AuthViews.swift`, `AuthRepository.swift` | Supabase Auth + `mort://` PKCE links | Implemented | Wired | pass | required | required |
| 3 | Signin and signout | `mort_screens.dart` | `AuthViews.swift`, `SessionStore.swift` | Supabase Auth | Implemented | Wired | pass | required | required |
| 4 | Session restore/refresh/expiry routing | `app.dart`, `route_access.dart` | `SessionStore.swift`, `RootView.swift` | auth state stream + `get_my_profile` | Implemented | Wired | pass | required | required |
| 5 | Password reset and recovery callback | `mort_screens.dart` | `AuthViews.swift`, `AuthRepository.swift` | Supabase PKCE recovery | Implemented | Wired | pass | required | required |
| 6 | Restricted account routing | `AccountStatusScreen` | `RestrictedAccountView`, `SessionRouting` | profile `account_status` | Implemented | Wired | pass | required | required |
| 7 | DOB entry, date picker, leap year, age role gate | `date_of_birth.dart`, `AgeGateScreen` | `DateOfBirth.swift`, `MortDateField`, tests | date-only profile field | Implemented | Wired | pass | required | required |
| 8 | Teen onboarding | `OnboardingHubScreen`, profile/skills/availability screens | `OnboardingView.swift` | profile/teen/payment RPC/table contracts | Implemented | Wired | pass | required | required |
| 9 | Adult and business onboarding | `ProfileSetupScreen`; business route is a scaffold | `OnboardingView.swift`, `BusinessProfileView` | `profiles`, `adult_profiles` | Implemented | Wired | pass | required | required |
| 10 | Guardian onboarding | `OnboardingHubScreen`, guardian screens | `OnboardingView.swift`, `EmergencyContactView` | guardian profile/contracts | Implemented | Wired | pass | required | required |
| 11 | Optional Guardian Mode setup/skip | `guardian_mode_screens.dart` | `OnboardingView.swift`, `GuardianModeView` | guardian invite/skip RPCs | Implemented | Wired | pass | required | required |
| 12 | Teen/adult/guardian/admin navigation | `app_router.dart`, role home | `RoleShells.swift`, typed `Router` | profile role + RLS | Implemented | Wired | pass | required | required |
| 13 | Profile view/edit, skills, availability, goals | `ProfileSetupScreen`, settings profile | `ProfileViews.swift` | `profiles` | Implemented | Wired | pass | required | required |
| 14 | Adult/business profile details | Flutter business route is a scaffold | `RoleProfileViews.swift` | `adult_profiles` | Implemented | Wired | pass | required | required |
| 15 | Guardian emergency contact | guardian profile reference | `EmergencyContactView` | private `guardian_profiles` fields | Implemented | Wired | pass | required | required |
| 16 | Avatar fallback/select/camera/interactive crop/replace/remove | `profile_avatar_widgets.dart` | `ProfileViews.swift`, `AvatarCropView`, `CameraPicker`, `ImageProcessingService` | private avatar bucket + `avatar-url` | Implemented | Wired | pass | required | required |
| 17 | Portfolio management | Flutter route is a coming-later scaffold | unavailable screen only | no shared schema/RPC | Missing | None | n/a | after backend | after backend |
| 18 | Adult analytics | Flutter route is a coming-later scaffold | unavailable screen only | no privacy-reviewed API | Missing | None | n/a | after backend | after backend |
| 19 | Job feed loading/skeleton/refresh/error/empty | `teen_job_screens.dart` | `JobFeedView.swift` | `jobs` | Implemented | Wired | pass | required | required |
| 20 | Job search/filter/sort/pagination/QA exclusion | `teen_job_screens.dart` | `JobFeedView.swift`, `JobRepository.swift` | PostgREST filters/range | Implemented | Wired | pass | required | required |
| 21 | Saved jobs | `SavedJobsScreen` | `SavedJobsView`, `SavedJobRepository` | `saved_jobs` | Implemented | Wired | pass | required | required |
| 22 | Job detail and conditional guardian requirement | `TeenJobDetailScreen` | `JobDetailView.swift` | job + eligibility RPC | Implemented | Wired | pass | required | required |
| 23 | Eight-step job creation wizard | `JobCreationScreen` | `JobWizardView.swift` | `save_job_draft_or_publish` | Implemented | Wired | pass | required | required |
| 24 | Draft/resume/publish and lifecycle actions | adult job screens | `JobWizardView`, `MyJobsView` | `manage_job`, status events | Implemented | Wired | pass | required | required |
| 25 | Job boost credit/status | monetization/job screens | `MyJobsView`, `MonetizationRepository` | boost RPCs | Implemented | Wired | pass | required | required |
| 26 | Proposal, availability, eligibility, apply | job/application screens | `JobDetailView`, `ApplicationRepository` | eligibility + submit RPCs | Implemented | Wired | pass | required | required |
| 27 | Application lists/details/timeline | `application_screens.dart` | `ApplicationsView`, `ApplicationDetailView` | applications/status events | Implemented | Wired | pass | required | required |
| 28 | Adult application review | `ApplicationListScreen` | `ApplicationDetailView` adult actions | transition RPC | Implemented | Wired | pass | required | required |
| 29 | Guardian approval/rejection | guardian approval routes | `ApplicationsView`, `ApplicationDetailView` | transition RPC + guardian RLS | Implemented | Wired | pass | required | required |
| 30 | Withdraw/start/complete application lifecycle | application screens | `ApplicationDetailView` | transition RPC | Implemented | Wired | pass | required | required |
| 31 | Proof photo/camera/private upload/submit | `ProofUploadScreen` | `ProofUploadView`, `StorageRepository` | private bucket + proof RPC | Implemented | Wired | pass | required | required |
| 32 | Proof approve/reject/request resubmission | `ProofReviewScreen`, applications repository | `ProofReviewView`, `ApplicationRepository` | `review_application_proof`, proof review events, completion gate | Implemented | Wired | pass | required | required |
| 33 | Two-sided completed-job reviews/reporting | `review_screens.dart` | `ReviewViews.swift` | `reviews`, report table/RLS | Implemented | Wired | pass | required | required |
| 34 | Conversation list and thread | `MessagesScreen`, `MessageThreadScreen` | `MessagingViews.swift` | message tables | Implemented | Wired | pass | required | required |
| 35 | Message paging/realtime/send/error retry | messaging repository/screens | `MessageRepository`, `MessageThreadView` | Realtime + `send_safe_message` | Implemented | Wired | pass | required | required |
| 36 | Accurate message unread state | `MessagesScreen`, messaging repository | `MessagingViews`, `MessageRepository` | participant read cursor, thread-list and mark-read RPCs | Implemented | Wired | pass | required | required |
| 37 | Message safety scanner warning | messaging screens/errors | `MessageBubble`, translated errors | `send_safe_message` | Implemented | Wired | pass | required | required |
| 38 | Report user/job/message/review and block/unblock | report/block routes | `SafetyViews.swift` | `reports`, `blocks` | Implemented | Wired | pass | required | required |
| 39 | Safety Ping, Safety Center, emergency/AI guidance | `SafetyCenterScreen`, guardian ping screen, academy | `SafetyViews.swift`, `GuardianSafetyPingsView`, legal views | `safety_pings` + authorized delivery | Implemented | Wired | pass | required | required |
| 40 | In-app notification center/read state | notification screens | `NotificationCenterView.swift` | `notifications` | Implemented | Wired | pass | required | required |
| 41 | Notification destination/deep-link routing | limited Flutter routing | `NotificationDestinationResolver`, `NotificationCenterView`, `SessionStore` | current notification data payloads + `mort://notifications` | Implemented | Wired | pass | required | required |
| 42 | iOS permission and APNs registration architecture | Flutter/Expo push reference | `PushNotificationService`, app delegate, settings | Apple APIs only | Implemented | Local | pass | required | required |
| 43 | APNs token persistence and delivery | Expo push architecture | deliberately disabled | Expo-only token column/provider | Missing | None | n/a | after backend | after backend |
| 44 | Support tickets and activity history | `SupportScreen`, activity screen | `SupportCenterView`, `ActivityHistoryView` | support RPC/tables + role history | Implemented | Wired | pass | required | required |
| 45 | Adult/business verification | `VerificationScreen` | `VerificationView.swift` | private bucket + verification RPC | Implemented | Wired | pass | required | required |
| 46 | Payment preference-only flow | `PaymentPreferenceScreen` | `PaymentPreferenceView` | profiles/payment preferences | Implemented | Wired | pass | required | required |
| 47 | RevenueCat configure/identify/CustomerInfo/offerings | RevenueCat service/providers | `RevenueCatService.swift` | RevenueCat iOS SDK | Implemented | SDK wired | pass | required | required |
| 48 | Real prices, purchase, cancel, restore, Customer Center | monetization screens | `PaywallViews.swift` | StoreKit through RevenueCat | Implemented | SDK wired | pass | required | required |
| 49 | Optional native paywall and free-safety promises | Flutter paywall screens | `PaywallView` | offerings + analytics RPC | Implemented | Wired | pass | required | required |
| 50 | Username credits and job boost consumption | username/paywall screens | `UsernameView`, `MyJobsView` | username/boost RPCs | Implemented | Wired | pass | required | required |
| 51 | Ad eligibility, banner, test IDs, ad-free/sensitive gating | Flutter ad widgets | `AdViews`, `AdMobService` | backend eligibility + Google SDK | Implemented; ads off | Wired | pass | required | required |
| 52 | Rewarded ad user placement/reward policy | Flutter rewarded button scaffold | service can load/present; no approved placement | Google SDK | Partial | SDK only | pass | required | required |
| 53 | Google UMP/ATT runtime consent flow | ad preference screen | preference UI and permission copy only | UMP/ATT not integrated | Partial | Incomplete | pass | required | required |
| 54 | Admin dashboard and queue navigation | admin queue screens | `AdminViews.swift` | server-authorized queues/overview | Implemented | Wired | pass | required | required |
| 55 | Detailed admin evidence and complete per-queue actions | Flutter generic admin cards | generic record/update only | incomplete detail contracts | Partial | Incomplete | pass | required | required |
| 56 | Settings, legal drafts, signout, deletion request | settings/legal/support screens | `SettingsView`, `LegalViews`, deletion support request | tables/RPCs where available | Implemented | Wired | pass | required | required |
| 57 | Native dark design system and reusable states | Flutter theme/widgets | `DesignSystem` | local | Implemented | Local | pass | required | required |
| 58 | Private storage, signed URLs, metadata removal | uploads/avatar repositories | `StorageRepository`, `ImageProcessingService` | four private buckets/function | Implemented | Wired | pass | required | required |
| 59 | RLS/server authority and structured errors | repository base/errors | all Swift repositories + `MortError` | existing RLS/RPCs | Implemented | Wired | pass | required | required |
| 60 | Native tests, privacy manifest, permissions, Xcode packaging | Flutter tests/web config | `MORTTests`, `MORTUITests`, plist/assets/config | XCTest/Xcode/Apple | Implemented source | Local | pass | required | required |

## Source-level percentage

Implemented rows counted: 54

Audited feature units: 60

Source-level parity: **90.0%** (`54 / 60`).

Partial and missing rows are not counted. The percentage does not include Mac compilation, simulator execution, physical iPhone behavior, RevenueCat sandbox results, AdMob test delivery, APNs delivery, TestFlight, or App Store/legal/teen-safety approval.
