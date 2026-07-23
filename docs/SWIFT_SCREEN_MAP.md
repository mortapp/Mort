# MORT Native Swift Screen Map

Status date: 2026-07-14

All destinations use one SwiftUI `NavigationStack` with typed `AppRoute` values. Role tabs are selected only after Supabase session restore, profile fetch, account-status validation, and onboarding validation.

## Startup and auth

| Experience | Flutter reference | Swift view/route | Status |
| --- | --- | --- | --- |
| Native launch/config loading | `SplashScreen`, setup-required screen | `MORTApp`, `AppBootstrap`, `RootView`, `ConfigurationFailureView` | Implemented source |
| Welcome/auth switcher | `WelcomeScreen` | `AuthView` | Implemented source |
| Sign in | `SignInScreen` | `SignInView` | Supabase wired |
| Sign up | `SignUpScreen` | `SignUpView` | Supabase wired |
| Email confirmation | account status/auth flow | `EmailConfirmationView` | Supabase callback wired |
| Forgot password | `ForgotPasswordScreen` | `ForgotPasswordView` | Supabase recovery wired |
| Set recovered password | auth recovery flow | `PasswordRecoveryView` | Supabase update wired |
| Restricted/suspended account | `AccountStatusScreen` | `RestrictedAccountView` | profile status wired |
| Startup failure | `SetupRequiredScreen` | `ConfigurationFailureView` | Client-safe configuration only |

## Onboarding

| Experience | Flutter reference | Swift view/step | Status |
| --- | --- | --- | --- |
| Welcome and role/account choice | onboarding hub/role | `OnboardingView`: welcome, role | Implemented |
| DOB age gate | `AgeGateScreen` | `OnboardingView`: age + `MortDateField` | Implemented and tested in source |
| Profile basics | `ProfileSetupScreen` | `OnboardingView`: basics | Supabase wired |
| Optional avatar | avatar widgets | `OnboardingView`: avatar | Private storage wired |
| Skills/availability/categories/goals | skills, availability, profile screens | `OnboardingView`: preferences | Profile fields wired |
| Payment preference | `PaymentPreferenceScreen` | `OnboardingView`: payment | Preference-only contract wired |
| Optional Guardian Mode | `GuardianOptionalOnboardingScreen` | `OnboardingView`: guardian | Invite/code/skip RPCs wired |
| Safety education | safety/academy screens | `OnboardingView`: safety | Implemented, always free |
| Final acknowledgement | onboarding completion | `OnboardingView`: acknowledgement | Profile completion wired |

Business is an adult backend role with `adult_profiles.business_type = business`; it is not a fake client-only admin or a new unsupported authorization role.

## Role shells

| Role | Tabs | Swift source | Status |
| --- | --- | --- | --- |
| Teen | Jobs, Applied, Messages, Safety, You | `TeenShellView` | Implemented source |
| Adult/business | Home, Jobs, Post, Applicants, You | `AdultShellView` | Implemented source |
| Guardian | Guardian, Approvals, Pings, Safety, You | `GuardianShellView` | Implemented source |
| Admin | Admin, Reports, Verify, Support, You | `AdminShellView` | Implemented source; server auth remains mandatory |

## Jobs and applications

| Experience | Flutter reference | Swift view/route | Backend/status |
| --- | --- | --- | --- |
| Teen job feed | `TeenJobFeedScreen` | `JobFeedView` / `.jobFeed` | `jobs`, wired |
| Job detail and apply | `TeenJobDetailScreen` | `JobDetailView` / `.jobDetail` | eligibility/apply RPCs, wired |
| Saved jobs | `SavedJobsScreen` | `SavedJobsView` / `.savedJobs` | `saved_jobs`, wired |
| Adult dashboard | role home | `AdultDashboardView` | role data wired |
| Eight-step post/edit job | `JobCreationScreen` | `JobWizardView` / `.jobWizard` | draft/publish RPC, wired |
| My posted jobs | `AdultJobsScreen` | `MyJobsView` / `.myJobs` | `jobs`, wired |
| Job lifecycle/timeline/boost | `AdultJobManagementScreen` | `JobManagementView` / `.jobManagement` | manage/status/boost RPCs, wired |
| Teen applications | `ApplicationListScreen` teen | `ApplicationsView(.teen)` | wired |
| Adult applicants | `ApplicationListScreen` adult | `ApplicationsView(.adult)` | wired |
| Guardian approvals | guardian approval routes | `ApplicationsView(.guardian)` | authorized Guardian Mode only |
| Application detail/timeline/actions | application routes | `ApplicationDetailView` | transition RPC, wired |
| Proof upload | `ProofUploadScreen` | `ProofUploadView` / `.proofUpload` | private bucket + RPC, wired |
| Proof review/resubmission actions | Flutter route reuses list | no destination claiming these actions | Missing backend contract |

## Messaging and safety

| Experience | Flutter reference | Swift view/route | Backend/status |
| --- | --- | --- | --- |
| Conversation list | `MessagesScreen` | `MessageListView` / `.messages` | participant RLS, wired |
| Message thread | `MessageThreadScreen` | `MessageThreadView` / `.messageThread` | paging/Realtime/safe send, wired |
| Accurate unread badges | limited reference | no fabricated badge | Missing read-state contract |
| Safety Center | `SafetyCenterScreen` | `SafetyCenterView` / `.safetyCenter` | Implemented, always free |
| Submit report | report routes | `ReportView` / `.report` | `reports`, wired |
| Blocked accounts | block/settings routes | `BlockedUsersView` / `.blockedUsers` | `blocks`, wired |
| Safety Ping | Safety Center | `SafetyPingSheet` | `safety_pings`, wired |
| Guardian Mode links/preferences | `GuardianModeScreen` | `GuardianModeView` / `.guardianMode` | guardian RPCs, wired |
| Guardian safety pings | `GuardianSafetyPingsScreen` | `GuardianSafetyPingsView` | preference-authorized rows |

## Profile, trust, and support

| Experience | Flutter reference | Swift view/route | Backend/status |
| --- | --- | --- | --- |
| Profile/edit | profile setup/settings | `ProfileView` / `.profile` | `profiles`, wired |
| Avatar editor | avatar widgets | `AvatarEditorView`, `AvatarCropView` / `.avatar` | camera/library, pan/zoom crop, metadata-removing encode, private storage |
| Adult/business profile | Flutter route is a scaffold | `BusinessProfileView` / `.businessProfile` | `adult_profiles`, wired |
| Guardian emergency contact | guardian profile | `EmergencyContactView` / `.emergencyContact` | private guardian row, wired |
| Username | `UsernameSettingsScreen` | `UsernameView` / `.username` | username RPCs, wired |
| Reviews | `MyReviewsScreen` | `ReviewsView` / `.reviews` | approved received reviews |
| Leave review | `LeaveReviewScreen` | `LeaveReviewView` / `.leaveReview` | completed-job enforcement |
| Activity history | `ActivityHistoryScreen` | `ActivityHistoryView` / `.activity` | RLS-visible activity |
| Business verification | `VerificationScreen` | `VerificationView` / `.verification` | private storage + RPC |
| Support | `SupportScreen` | `SupportCenterView` / `.support` | ticket RPC/list, wired |
| Portfolio | coming-later Flutter route | `UnavailableFeatureView` | Missing schema/RLS/API |
| Adult analytics | coming-later Flutter route | `UnavailableFeatureView` | Missing privacy-reviewed API |

## Notifications, monetization, ads, and settings

| Experience | Flutter reference | Swift view/route | Backend/status |
| --- | --- | --- | --- |
| In-app notification center | notification screens | `NotificationCenterView`, `NotificationDestinationResolver` / `.notifications` | list/read state plus role-aware payload and `mort://notifications` routing wired |
| Push permissions | Expo/native reference | `PushSettingsView` / `.pushSettings` | APNs registration only; delivery incomplete |
| Optional perks/paywall | paywall screens | `PaywallView` / `.monetization` | RevenueCat + event RPC wired |
| Manage subscription | manage screen | `CustomerCenterScreen` / `.customerCenter` | RevenueCat Customer Center wired |
| Ad preferences | `AdPreferencesScreen` | `AdPreferencesView` / `.adPreferences` | backend preference wired |
| Banner placement | Flutter ad widget | `MortBannerPlacement` in feed | disabled; backend and SDK gated |
| Payment preference | payment screen | `PaymentPreferenceView` / `.paymentPreferences` | preference-only wired |
| Main settings | `SettingsScreen` | `SettingsView` / `.settings` | Implemented |
| Account deletion request | support/settings reference | `AccountDeletionRequestView` | real support request; not instant deletion |
| Legal and safety documents | legal routes | `LegalDocumentView` / `.legal` | Draft copy; formal legal review required |

## Admin

| Experience | Flutter reference | Swift view/route | Backend/status |
| --- | --- | --- | --- |
| Dashboard/counts/monetization | role home/admin routes | `AdminDashboardView` | server-authorized queries |
| Users | admin queue | `AdminQueueView(.users)` | `admin_list_profiles` + status update |
| Jobs | admin queue | `AdminQueueView(.jobs)` | RLS/admin update |
| Reports | admin queue | `AdminQueueView(.reports)` | RLS/admin update |
| Verification | admin queue | `AdminQueueView(.verifications)` | RLS/admin update |
| Safety | admin queue | `AdminQueueView(.safety)` | RLS/admin read/update |
| Support | admin queue | `AdminQueueView(.support)` | RLS/admin update |
| Monetization | dashboard | monetization overview cards | admin overview RPC |
| Full evidence/detail workflows | generic Flutter/Swift records | not complete | Additional backend contracts and device UX required |

## Verification state

The listed Swift screens exist in source and are included in `MORT.xcodeproj`. None has been compiled by Xcode, run in an iOS simulator, or exercised on a physical iPhone during this Windows pass.
