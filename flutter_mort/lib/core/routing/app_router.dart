import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../../data/services/supabase_service.dart';
import '../config/app_config.dart';
import '../errors/user_facing_error.dart';
import '../../features/monetization/screens/ad_free_screen.dart';
import '../../features/monetization/screens/job_boost_paywall_screen.dart';
import '../../features/monetization/screens/monetization_home_screen.dart';
import '../../features/monetization/screens/google_play_billing_screens.dart';
import '../../features/monetization/screens/username_change_paywall_screen.dart';
import '../../features/guardian/guardian_mode_screens.dart';
import '../../features/guardian/guardian_safety_pings_screen.dart';
import '../../features/guide/mort_guide_screens.dart';
import '../../features/jobs/job_screens.dart';
import '../../features/jobs/job_progress_screen.dart';
import '../../features/jobs/application_screens.dart';
import '../../features/jobs/teen_job_screens.dart';
import '../../features/jobs/proof_review_screen.dart';
import '../../features/legal/contract_payment_screens.dart';
import '../../features/legal/legal_screens.dart';
import '../../features/legal/trust_foundation_screens.dart';
import '../../features/mort_screens.dart';
import '../../features/mission/mission_pilot_screens.dart';
import '../../features/mission/partner_staff_screens.dart';
import '../../features/profile/review_screens.dart';
import '../../features/reviewer/reviewer_screens.dart';
import '../../features/profile/activity_history_screen.dart';
import '../../features/notifications/notification_center_screen.dart';
import '../../features/onboarding/compact_onboarding.dart';
import '../../features/payments/stripe_marketplace_screens.dart';
import '../../features/payments/admin_payment_operations_screen.dart';
import '../../features/admin/admin_moderation_detail_screen.dart';
import '../../features/admin/admin_operational_alerts_screen.dart';
import '../../features/auth/google_auth_screens.dart';
import '../../features/auth/unified_auth_screen.dart';
import '../../features/safety/trust_safety_screens.dart';
import '../../features/support/support_screens.dart';
import '../../features/support/support_assistant_screen.dart';
import '../../features/settings/account_management_screens.dart';
import '../../features/settings/experience_settings_screen.dart';
import '../../features/settings/native_permissions_screen.dart';
import '../../features/settings/release_diagnostics_screen.dart';
import '../../features/trust/account_trust_screens.dart';
import '../../features/trust/teen_verification_screens.dart';
import '../../features/teen/teen_profile_screen.dart';
import '../../features/teen/teen_shell.dart';
import '../../services/screen_security_service.dart';
import '../widgets/mort_widgets.dart';
import '../reviewer/reviewer_session.dart';
import 'route_access.dart';

const legacyOnboardingPaths = <String>[
  '/onboarding/age',
  '/onboarding/role',
  '/onboarding/profile',
  '/onboarding/skills',
  '/onboarding/availability',
  '/onboarding/transportation',
  '/onboarding/payment',
  '/onboarding/guardian',
  '/onboarding/safety',
  '/onboarding/preferences',
  '/onboarding/review',
];

String canonicalOnboardingPath(String path) =>
    legacyOnboardingPaths.contains(path) ? '/onboarding' : path;

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/auth/sign-in',
        builder: (_, _) => const UnifiedAuthScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (_, _) =>
            const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
      ),
      if (AppConfig.playReviewModeEnabled) ...[
        _reviewer('/review', const ReviewerRoleSelectorScreen()),
        _reviewer('/review/teen', const ReviewerTeenScreen()),
        _reviewer('/review/adult', const ReviewerAdultScreen()),
        _reviewer('/review/guardian', const ReviewerGuardianScreen()),
        _reviewer('/review/support', const ReviewerSupportScreen()),
        _reviewer('/review/admin', const ReviewerAdminScreen()),
      ],
      GoRoute(
        path: '/auth-callback',
        builder: (_, state) => OAuthCallbackScreen(callbackUri: state.uri),
      ),
      GoRoute(
        path: '/auth/confirm',
        builder: (_, _) => const EmailConfirmationCallbackScreen(),
      ),
      GoRoute(
        path: '/auth-confirm',
        builder: (_, _) => const EmailConfirmationCallbackScreen(),
      ),
      GoRoute(
        path: '/auth/recovery',
        builder: (_, _) => const PasswordRecoveryCallbackScreen(),
      ),
      GoRoute(
        path: '/auth-recovery',
        builder: (_, _) => const PasswordRecoveryCallbackScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      _guarded(
        '/onboarding',
        const CompactOnboardingScreen(),
        allowIncompleteOnboarding: true,
      ),
      for (final legacyPath in legacyOnboardingPaths)
        GoRoute(
          path: legacyPath,
          redirect: (_, state) => canonicalOnboardingPath(state.uri.path),
        ),
      _guarded('/account-status', const AccountStatusScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => GuardedRoute(
          requiredRole: UserRole.teen,
          child: TeenShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teen/home',
                builder: (_, _) => const RoleHomeScreen(role: UserRole.teen),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teen/jobs',
                builder: (_, _) => const TeenJobFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teen/safety',
                builder: (_, _) => const SafetyCenterScreen(),
                routes: [
                  GoRoute(
                    path: 'applications/:applicationId',
                    builder: (_, state) => SensitiveScreenProtection(
                      child: JobSafetyWorkspaceScreen(
                        applicationId:
                            state.pathParameters['applicationId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teen/messages',
                builder: (_, _) =>
                    const SensitiveScreenProtection(child: MessagesScreen()),
                routes: [
                  GoRoute(
                    path: ':conversationId',
                    builder: (_, state) => SensitiveScreenProtection(
                      child: MessageThreadScreen(
                        threadId: state.pathParameters['conversationId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teen/profile',
                builder: (_, _) => const TeenProfileDestinationScreen(),
              ),
            ],
          ),
        ],
      ),
      _guarded(
        '/teen/applications',
        const ApplicationListScreen(),
        role: UserRole.teen,
      ),
      GoRoute(
        path: '/teen/applications/:id',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.teen,
          child: ApplicationDetailScreen(
            view: ApplicationView.teen,
            applicationId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/teen/jobs/:id',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.teen,
          child: TeenJobDetailScreen(jobId: state.pathParameters['id'] ?? ''),
        ),
      ),
      _guarded('/teen/saved', const SavedJobsScreen(), role: UserRole.teen),
      GoRoute(
        path: '/teen/proof/:applicationId',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.teen,
          child: SensitiveScreenProtection(
            child: ProofUploadScreen(
              applicationId: state.pathParameters['applicationId'] ?? '',
            ),
          ),
        ),
      ),
      _guarded(
        '/teen/profile/edit',
        const ProfileSetupScreen(initialRole: UserRole.teen),
        role: UserRole.teen,
      ),
      _guarded(
        '/teen/portfolio',
        _pilotUnavailable(
          'Portfolio',
          'Public portfolio publishing is not available for this account. Your completed work still appears in private activity history.',
        ),
        role: UserRole.teen,
      ),
      _guarded('/teen/skills', const SkillsScreen(), role: UserRole.teen),
      _guarded(
        '/teen/availability',
        const AvailabilityScreen(),
        role: UserRole.teen,
      ),
      _guarded('/teen/goals', const EarningsGoalsScreen(), role: UserRole.teen),
      _guarded('/teen/hustle-academy', _academy(), role: UserRole.teen),
      _guarded(
        '/adult/home',
        const RoleHomeScreen(role: UserRole.adult),
        role: UserRole.adult,
      ),
      _guarded(
        '/adult/post-job',
        const JobCreationScreen(),
        role: UserRole.adult,
      ),
      _guarded('/adult/jobs', const AdultJobsScreen(), role: UserRole.adult),
      GoRoute(
        path: '/adult/jobs/:id',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.adult,
          child: AdultJobManagementScreen(
            jobId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/adult/jobs/:id/edit',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.adult,
          child: JobCreationScreen(jobId: state.pathParameters['id']),
        ),
      ),
      _guarded(
        '/adult/applicants',
        const ApplicationListScreen(view: ApplicationView.adult),
        role: UserRole.adult,
      ),
      GoRoute(
        path: '/adult/applicants/:applicationId',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.adult,
          child: ApplicationDetailScreen(
            view: ApplicationView.adult,
            applicationId: state.pathParameters['applicationId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/adult/proof-review/:applicationId',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.adult,
          child: SensitiveScreenProtection(
            child: ProofReviewScreen(
              applicationId: state.pathParameters['applicationId'] ?? '',
            ),
          ),
        ),
      ),
      _guarded(
        '/adult/verification',
        const IdentityVerificationScreen(),
        role: UserRole.adult,
      ),
      _guarded(
        '/adult/business-verification',
        const VerificationScreen(),
        role: UserRole.adult,
      ),
      _guarded(
        '/adult/profile',
        const ProfileSetupScreen(initialRole: UserRole.adult),
        role: UserRole.adult,
      ),
      _guarded(
        '/adult/business',
        _pilotUnavailable(
          'Business profile',
          'Public business profiles are not available for this account. Eligible posters can still manage their jobs.',
        ),
        role: UserRole.adult,
      ),
      _guarded(
        '/adult/analytics',
        _pilotUnavailable(
          'Analytics',
          'Paid analytics are not included in this release. Job and applicant status remain available from job management.',
        ),
        role: UserRole.adult,
      ),
      _guarded(
        '/guardian/home',
        const RoleHomeScreen(role: UserRole.guardian),
        role: UserRole.guardian,
      ),
      _guarded(
        '/guardian/linked-teens',
        const GuardianModeScreen(),
        role: UserRole.guardian,
      ),
      _guarded(
        '/guardian/approvals',
        const ApplicationListScreen(view: ApplicationView.guardian),
        role: UserRole.guardian,
      ),
      GoRoute(
        path: '/guardian/approvals/:applicationId',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.guardian,
          child: ApplicationDetailScreen(
            view: ApplicationView.guardian,
            applicationId: state.pathParameters['applicationId'] ?? '',
          ),
        ),
      ),
      _guarded(
        '/guardian/permissions',
        const GuardianModeScreen(),
        role: UserRole.guardian,
      ),
      _guarded(
        '/guardian/safety-pings',
        const GuardianSafetyPingsScreen(),
        role: UserRole.guardian,
      ),
      _guarded(
        '/guardian/activity',
        const ActivityHistoryScreen(),
        role: UserRole.guardian,
      ),
      _guarded(
        '/guardian/emergency-contacts',
        _pilotUnavailable(
          'Emergency contacts',
          'The optional emergency-contact bundle is not available. Safety Ping and reporting remain available without payment.',
        ),
        role: UserRole.guardian,
      ),
      _guarded(
        '/admin/home',
        const RoleHomeScreen(role: UserRole.admin),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/restricted-queues',
        const FeatureScaffoldScreen(
          eyebrow: 'Least privilege',
          title: 'Restricted safety queues',
          description:
              'Identity, child-safety, incident, preservation, and lawful-request records are separated by specialized backend roles.',
          actions: [
            MortAction(
              label: 'Account trust review',
              icon: Icons.shield_outlined,
              route: '/admin/account-trust',
            ),
            MortAction(
              label: 'Adult ID review',
              icon: Icons.badge_outlined,
              route: '/admin/adult-id',
            ),
            MortAction(
              label: 'Teen school-ID review',
              icon: Icons.school_outlined,
              route: '/admin/teen-school-id',
            ),
            MortAction(
              label: 'Teen alternatives',
              icon: Icons.alt_route,
              route: '/admin/teen-alternatives',
            ),
            MortAction(
              label: 'Business verification',
              icon: Icons.business,
              route: '/admin/business-verifications',
            ),
            MortAction(
              label: 'Verification appeals',
              icon: Icons.replay_outlined,
              route: '/admin/verification-appeals',
            ),
            MortAction(
              label: 'Account ban appeals',
              icon: Icons.restore_outlined,
              route: '/admin/ban-appeals',
            ),
            MortAction(
              label: 'All incident cases',
              icon: Icons.folder_shared_outlined,
              route: '/admin/incidents',
            ),
            MortAction(
              label: 'Person mismatch',
              icon: Icons.person_off_outlined,
              route: '/admin/person-mismatch',
            ),
            MortAction(
              label: 'Sexual safety',
              icon: Icons.health_and_safety_outlined,
              route: '/admin/sexual-safety',
            ),
            MortAction(
              label: 'Grooming signals',
              icon: Icons.warning_amber,
              route: '/admin/grooming-signals',
            ),
            MortAction(
              label: 'Abduction concerns',
              icon: Icons.crisis_alert,
              route: '/admin/abduction-concerns',
            ),
            MortAction(
              label: 'Threats and violence',
              icon: Icons.gpp_bad_outlined,
              route: '/admin/threats-violence',
            ),
            MortAction(
              label: 'Property and theft',
              icon: Icons.home_work_outlined,
              route: '/admin/property-theft',
            ),
            MortAction(
              label: 'Account sharing',
              icon: Icons.no_accounts_outlined,
              route: '/admin/account-sharing',
            ),
            MortAction(
              label: 'Evidence preservation',
              icon: Icons.inventory_2_outlined,
              route: '/admin/evidence-preservation',
            ),
            MortAction(
              label: 'Lawful requests',
              icon: Icons.balance_outlined,
              route: '/admin/lawful-requests',
            ),
          ],
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/reports',
        const AdminQueueScreen(
          title: 'Reports',
          table: 'reports',
          detailRoutePrefix: '/admin/reports',
        ),
        role: UserRole.admin,
      ),
      GoRoute(
        path: '/admin/reports/:id',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.admin,
          child: AdminModerationDetailScreen(
            recordType: AdminModerationRecordType.report,
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      _guarded(
        '/admin/verifications',
        const AdminQueueScreen(
          title: 'Identity verification review',
          table: 'identity_verifications',
          subtitle:
              'Only verification reviewers and senior safety moderators can read this queue. Raw evidence requires a separate logged grant.',
          orFilter:
              'status.eq.verification_pending,status.eq.manual_review,status.eq.additional_information_required,status.eq.appeal_pending',
          detailRoutePrefix: '/admin/verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/adult-id',
        const AdminQueueScreen(
          title: 'Adult ID review',
          table: 'identity_verifications',
          equals: {'account_role': 'adult'},
          detailRoutePrefix: '/admin/verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/teen-school-id',
        const AdminQueueScreen(
          title: 'Teen school-ID review',
          table: 'identity_verifications',
          equals: {'account_role': 'teen', 'evidence_route': 'school_photo_id'},
          detailRoutePrefix: '/admin/verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/teen-alternatives',
        const AdminQueueScreen(
          title: 'Teen alternative-evidence review',
          table: 'identity_verifications',
          equals: {'account_role': 'teen'},
          notEquals: {'evidence_route': 'school_photo_id'},
          detailRoutePrefix: '/admin/verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/business-verifications',
        const AdminQueueScreen(
          title: 'Business verification',
          table: 'business_verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/verification-appeals',
        const AdminQueueScreen(
          title: 'Verification appeals',
          table: 'identity_verifications',
          equals: {'status': 'appeal_pending'},
          detailRoutePrefix: '/admin/verifications',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/ban-appeals',
        const AdminBanAppealsScreen(),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/incidents',
        const AdminQueueScreen(
          title: 'Incident cases',
          table: 'safety_incidents',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/person-mismatch',
        const AdminQueueScreen(
          title: 'Person-mismatch reports',
          table: 'safety_incidents',
          equals: {'category': 'identity_mismatch'},
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/sexual-safety',
        const AdminQueueScreen(
          title: 'Sexual-safety reports',
          table: 'safety_incidents',
          orFilter:
              'category.eq.sexual_harassment,category.eq.sexual_conduct,category.eq.inappropriate_touching,category.eq.inappropriate_images',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/grooming-signals',
        const AdminQueueScreen(
          title: 'Grooming signals',
          table: 'safety_incidents',
          orFilter:
              'category.eq.child_safety_concern,category.eq.off_platform_pressure,category.eq.personal_information_request',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/abduction-concerns',
        const AdminQueueScreen(
          title: 'Kidnapping or abduction concerns',
          table: 'safety_incidents',
          equals: {'category': 'kidnapping_abduction_concern'},
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/threats-violence',
        const AdminQueueScreen(
          title: 'Threats and violence',
          table: 'safety_incidents',
          orFilter:
              'category.eq.threats,category.eq.assault,category.eq.attempted_assault,category.eq.weapons',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/property-theft',
        const AdminQueueScreen(
          title: 'Property damage and theft',
          table: 'safety_incidents',
          orFilter: 'category.eq.property_damage,category.eq.theft',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/account-sharing',
        const AdminQueueScreen(
          title: 'Account sharing and impersonation',
          table: 'safety_incidents',
          orFilter:
              'category.eq.account_sharing,category.eq.impersonation,category.eq.fake_document',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/evidence-preservation',
        const AdminQueueScreen(
          title: 'Evidence preservation',
          table: 'safety_incidents',
          orFilter:
              'legal_hold.eq.true,preservation_status.eq.preserve_relevant_records',
          sensitiveAction: AdminSensitiveQueueAction.incident,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/lawful-requests',
        const AdminQueueScreen(
          title: 'Lawful requests',
          table: 'incident_law_enforcement_requests',
          subtitle:
              'Visible only to the specialized legal-request reviewer role. This is not a legal approval workflow.',
        ),
        role: UserRole.admin,
      ),
      GoRoute(
        path: '/admin/verifications/:id',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.admin,
          child: AdminModerationDetailScreen(
            recordType: AdminModerationRecordType.identityVerification,
            recordId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      _guarded(
        '/admin/jobs',
        const AdminQueueScreen(
          title: 'Jobs moderation',
          table: 'jobs',
          moderationAction: AdminModerationQueueAction.rejectJob,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/messages',
        const AdminQueueScreen(
          title: 'Flagged messages',
          table: 'messages',
          statusField: 'scanner_status',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/safety-pings',
        const AdminQueueScreen(title: 'Safety pings', table: 'safety_pings'),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/users',
        const AdminQueueScreen(
          title: 'Users',
          table: 'profiles',
          statusField: 'account_status',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/monetization',
        const AdminQueueScreen(
          title: 'Paywall events',
          table: 'paywall_events',
          statusField: 'event_type',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/payment-operations',
        const SensitiveScreenProtection(child: AdminPaymentOperationsScreen()),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/operational-alerts',
        const SensitiveScreenProtection(child: AdminOperationalAlertsScreen()),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/support',
        const AdminSupportQueueScreen(),
        role: UserRole.admin,
      ),
      GoRoute(
        path: '/admin/support/ticket/:ticketId',
        builder: (_, state) => GuardedRoute(
          requiredRole: UserRole.admin,
          child: AdminSupportTicketScreen(
            ticketId: state.pathParameters['ticketId'] ?? '',
          ),
        ),
      ),
      _guarded(
        '/admin/reviews',
        const AdminQueueScreen(
          title: 'Review moderation',
          table: 'reviews',
          statusField: 'moderation_status',
          moderationAction: AdminModerationQueueAction.approveReview,
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/admin/action-logs',
        const AdminQueueScreen(
          title: 'Action logs',
          table: 'admin_action_logs',
          statusField: 'action',
        ),
        role: UserRole.admin,
      ),
      _guarded(
        '/safety',
        const SensitiveScreenProtection(child: SafetyCenterScreen()),
      ),
      _guarded(
        '/messages',
        const SensitiveScreenProtection(child: MessagesScreen()),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: MessageThreadScreen(
              threadId: state.pathParameters['conversationId'] ?? '',
            ),
          ),
        ),
      ),
      _guarded(
        '/notifications',
        const SensitiveScreenProtection(child: NotificationCenterScreen()),
      ),
      GoRoute(
        path: '/reviews/:applicationId',
        builder: (_, state) => GuardedRoute(
          child: LeaveReviewScreen(
            applicationId: state.pathParameters['applicationId'] ?? '',
          ),
        ),
      ),
      _guarded('/settings/reviews', const MyReviewsScreen()),
      _guarded('/settings/activity', const ActivityHistoryScreen()),
      _guarded(
        '/settings/identity-verification',
        const IdentityVerificationScreen(),
        allowIncompleteOnboarding: true,
      ),
      _guarded('/settings/account-trust', const AccountTrustScreen()),
      _guarded('/mission/pilot-eligibility', const PilotEligibilityScreen()),
      _guarded('/mission/partner-invitation', const PartnerInvitationScreen()),
      _guarded(
        '/mission/partner-affiliation',
        const PartnerAffiliationScreen(),
      ),
      _guarded('/mission/discreet-mode', const DiscreetModeScreen()),
      _guarded(
        '/mission/support-circle',
        const SupportCircleScreen(),
        role: UserRole.teen,
      ),
      _guarded(
        '/mission/earnings-goals',
        const EarningsGoalsScreen(),
        role: UserRole.teen,
      ),
      _guarded(
        '/mission/future-independence',
        const FutureIndependenceScreen(),
        role: UserRole.teen,
      ),
      _guarded(
        '/mission/resources',
        const ResourceDirectoryScreen(),
        role: UserRole.teen,
      ),
      _guarded('/mission/pilot-job-safety', const PilotJobSafetyScreen()),
      _guarded(
        '/mission/verification-wording',
        const VerificationExplanationScreen(),
      ),
      _guarded('/mission/document-review', const DocumentReviewStatusScreen()),
      _guarded('/partner/home', const PartnerStaffHomeScreen()),
      GoRoute(
        path: '/partner/participants/:organizationId',
        builder: (_, state) => GuardedRoute(
          child: PartnerParticipantsScreen(
            organizationId: state.pathParameters['organizationId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/partner/invites/:organizationId',
        builder: (_, state) => GuardedRoute(
          child: PartnerInvitesScreen(
            organizationId: state.pathParameters['organizationId'] ?? '',
          ),
        ),
      ),
      _guarded(
        '/settings/device-security',
        const DeviceSecuritySettingsScreen(),
      ),
      _guarded('/settings/native-permissions', const NativePermissionsScreen()),
      if (AppConfig.showReleaseDiagnostics)
        _guarded(
          '/settings/release-diagnostics',
          const ReleaseDiagnosticsScreen(),
        ),
      _guarded('/settings/passkeys', const PasskeySettingsScreen()),
      _guarded(
        '/settings/school-affiliation',
        const SchoolEmailVerificationScreen(),
      ),
      _guarded('/settings/partner-code', const PartnerCodeVerificationScreen()),
      _guarded(
        '/settings/business-registry',
        const BusinessRegistryMatchScreen(),
      ),
      _guarded('/settings/digital-id', const DigitalIDAvailabilityScreen()),
      _guarded('/settings/trust-appeal', const VerificationAppealScreen()),
      _guarded(
        '/admin/account-trust',
        const TrustAdminReviewScreen(),
        role: UserRole.admin,
      ),
      _guarded('/settings/safety-circle', const SafetyCircleScreen()),
      _guarded(
        '/settings/safety-cases',
        const SensitiveScreenProtection(child: SafetyCasesScreen()),
      ),
      _guarded(
        '/settings/security-sessions',
        const SensitiveScreenProtection(child: SecuritySessionsScreen()),
      ),
      _guarded(
        '/settings/active-sessions',
        const SensitiveScreenProtection(child: AccountSessionsScreen()),
      ),
      _guarded(
        '/settings/account-deletion',
        const SensitiveScreenProtection(child: AccountDeletionRequestScreen()),
      ),
      GoRoute(
        path: '/applications/:applicationId/safety',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: JobSafetyWorkspaceScreen(
              applicationId: state.pathParameters['applicationId'] ?? '',
            ),
          ),
        ),
      ),
      _guarded(
        '/report',
        const SensitiveScreenProtection(child: ReportScreen()),
      ),
      GoRoute(
        path: '/report/job/:id',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: ReportScreen(targetJobId: state.pathParameters['id']),
          ),
        ),
      ),
      GoRoute(
        path: '/report/message/:id',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: ReportScreen(targetMessageId: state.pathParameters['id']),
          ),
        ),
      ),
      GoRoute(
        path: '/report/user/:id',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: ReportScreen(targetUserId: state.pathParameters['id']),
          ),
        ),
      ),
      GoRoute(
        path: '/report/review/:id',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: ReportScreen(targetReviewId: state.pathParameters['id']),
          ),
        ),
      ),
      GoRoute(
        path: '/block/user/:id',
        builder: (_, state) => GuardedRoute(
          child: BlockUserScreen(targetUserId: state.pathParameters['id']),
        ),
      ),
      _guarded('/settings', const SettingsScreen()),
      _guarded('/settings/blocked-users', const BlockedUsersScreen()),
      _guarded('/settings/profile', const ProfileSetupScreen()),
      _guarded('/settings/connected-accounts', const ConnectedAccountsScreen()),
      _guarded('/settings/guardian-mode', const GuardianModeScreen()),
      _guarded('/settings/username', const UsernameSettingsScreen()),
      _guarded('/settings/accessibility', const ExperienceSettingsScreen()),
      _guarded(
        '/settings/appearance',
        const ExperienceSettingsScreen(appearanceFirst: true),
      ),
      _guarded('/settings/privacy', const PrivacySettingsScreen()),
      _guarded('/settings/safety', const SafetySettingsScreen()),
      _guarded('/settings/data', const DataControlsScreen()),
      _guarded('/settings/about', const AboutMortScreen()),
      _guarded('/settings/subscription', const MortPlusView()),
      _guarded('/settings/ad-preferences', const AdPreferencesScreen()),
      _guarded('/settings/legal', _legalIndex()),
      _guarded('/legal-center', const LegalCenterScreen()),
      _guarded('/legal-center/teen-summary', const TeenTermsSummaryScreen()),
      GoRoute(
        path: '/legal-center/version/:versionId',
        builder: (_, state) => GuardedRoute(
          child: LegalClickwrapScreen(
            versionId: state.pathParameters['versionId'] ?? '',
            title: state.uri.queryParameters['title'] ?? 'Legal document',
            signatureRequired: state.uri.queryParameters['signature'] == 'true',
          ),
        ),
      ),
      _guarded('/contracts', const JobContractsScreen()),
      GoRoute(
        path: '/contracts/:contractId',
        builder: (_, state) => GuardedRoute(
          child: JobContractScreen(
            contractId: state.pathParameters['contractId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/contracts/:contractId/change',
        builder: (_, state) => GuardedRoute(
          child: ContractChangeScreen(
            contractId: state.pathParameters['contractId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/contracts/:contractId/payment',
        builder: (_, state) => GuardedRoute(
          child: PaymentStatusScreen(
            contractId: state.pathParameters['contractId'] ?? '',
          ),
        ),
      ),
      if (AppConfig.marketplacePaymentsEnabled) ...[
        GoRoute(
          path: '/contracts/:contractId/fund',
          builder: (_, state) => GuardedRoute(
            requiredRole: UserRole.adult,
            child: StripeJobFundingScreen(
              contractId: state.pathParameters['contractId'] ?? '',
            ),
          ),
        ),
        _guarded(
          '/payments/stripe/payout-setup',
          const StripePayoutSetupScreen(),
          role: UserRole.teen,
        ),
      ],
      GoRoute(
        path: '/payments/:obligationId/nonpayment',
        builder: (_, state) => GuardedRoute(
          child: NonpaymentReportScreen(
            obligationId: state.pathParameters['obligationId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/disputes/:disputeId',
        builder: (_, state) => GuardedRoute(
          child: PaymentDisputeScreen(
            disputeId: state.pathParameters['disputeId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/disputes/:disputeId/export',
        builder: (_, state) => GuardedRoute(
          child: SensitiveScreenProtection(
            child: EvidenceExportScreen(
              disputeId: state.pathParameters['disputeId'] ?? '',
            ),
          ),
        ),
      ),
      _guarded('/trust/foundations', const TrustFoundationsScreen()),
      _guarded(
        '/trust/document-capture',
        const BrowserSafeCapturePreparationScreen(),
      ),
      _guarded('/trust/liveness', const LivenessExplanationScreen()),
      _guarded(
        '/trust/teen-verification',
        const TeenVerificationOptionsScreen(),
      ),
      _guarded(
        '/trust/teen-verification/capture',
        const TeenVerificationCapturePreparationScreen(),
      ),
      _guarded('/trust/device-auth', const DeviceAuthExplanationScreen()),
      GoRoute(path: '/support', builder: (_, _) => const SupportHomeScreen()),
      _guarded('/support/chat', const SupportAssistantScreen()),
      _guarded('/support/chat/history', const SupportAssistantHistoryScreen()),
      GoRoute(
        path: '/support/chat/:conversationId',
        builder: (_, state) => GuardedRoute(
          child: SupportAssistantScreen(
            initialConversationId: state.pathParameters['conversationId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/support/new',
        builder: (_, state) => GuardedRoute(
          child: NewSupportConversationScreen(
            relatedJobId: state.uri.queryParameters['jobId'],
            relatedApplicationId: state.uri.queryParameters['applicationId'],
            relatedContractId: state.uri.queryParameters['contractId'],
            relatedDisputeId: state.uri.queryParameters['disputeId'],
            initialCategory: state.uri.queryParameters['category'],
          ),
        ),
      ),
      GoRoute(
        path: '/support/ticket/:ticketId',
        builder: (_, state) => GuardedRoute(
          child: SupportTicketScreen(
            ticketId: state.pathParameters['ticketId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/jobs/progress/:applicationId',
        builder: (_, state) => GuardedRoute(
          child: JobProgressScreen(
            applicationId: state.pathParameters['applicationId'] ?? '',
          ),
        ),
      ),
      _guarded('/guide', const MortGuideView()),
      _guarded('/guide/history', const MortGuideHistoryView()),
      _guarded('/guide/delete-history', const MortGuideDeleteHistoryView()),
      GoRoute(
        path: '/guide/conversation/:conversationId',
        builder: (_, state) => GuardedRoute(
          child: MortGuideView(
            initialConversationId: state.pathParameters['conversationId'],
          ),
        ),
      ),
      _guarded('/monetization', const MonetizationHomeScreen()),
      _guarded('/monetization/paywall', const MortPlusView()),
      _guarded('/monetization/ad-free', const AdFreeScreen()),
      _guarded(
        '/monetization/username-change',
        const UsernameChangePaywallScreen(),
      ),
      _guarded('/monetization/job-boost', const JobBoostPaywallScreen()),
      _guarded('/monetization/restore', const RestorePurchasesView()),
      _guarded('/monetization/manage', const ManageSubscriptionView()),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const LegalDocScreen(title: 'Terms'),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const LegalDocScreen(title: 'Privacy'),
      ),
      GoRoute(
        path: '/legal/community-rules',
        builder: (_, _) => const LegalDocScreen(title: 'Community rules'),
      ),
      GoRoute(
        path: '/legal/payment-disclaimer',
        builder: (_, _) => const LegalDocScreen(title: 'Payment disclaimer'),
      ),
      GoRoute(
        path: '/legal/verification-disclaimer',
        builder: (_, _) =>
            const LegalDocScreen(title: 'Verification disclaimer'),
      ),
      GoRoute(
        path: '/legal/ad-disclosure',
        builder: (_, _) => const LegalDocScreen(title: 'Ad disclosure'),
      ),
      GoRoute(
        path: '/legal/subscription-disclosure',
        builder: (_, _) =>
            const LegalDocScreen(title: 'Subscription disclosure'),
      ),
      GoRoute(
        path: '/legal/teen-safety',
        builder: (_, _) => const LegalDocScreen(title: 'Teen safety'),
      ),
      GoRoute(
        path: '/legal/guardian-guide',
        builder: (_, _) => const LegalDocScreen(title: 'Guardian guide'),
      ),
    ],
    errorBuilder: (_, state) => MortErrorStateScreen(
      title: 'Route not found',
      message: state.error?.toString() ?? 'This route is not mapped.',
    ),
  );
});

GoRoute _guarded(
  String path,
  Widget child, {
  UserRole? role,
  bool allowIncompleteOnboarding = false,
}) {
  return GoRoute(
    path: path,
    builder: (_, _) => GuardedRoute(
      requiredRole: role,
      allowIncompleteOnboarding: allowIncompleteOnboarding,
      child: child,
    ),
  );
}

GoRoute _reviewer(String path, Widget child) {
  return GoRoute(
    path: path,
    builder: (_, _) => ReviewerRouteGuard(child: child),
  );
}

class ReviewerRouteGuard extends ConsumerWidget {
  const ReviewerRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewer = ref.watch(reviewerSessionProvider);
    final productionSessionPresent =
        ref.watch(authRepositoryProvider).currentUser != null;
    if (productionSessionPresent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (reviewer.isActive) reviewer.exit();
      });
      return const ReviewerSessionRequiredScreen();
    }
    if (!reviewer.isActive) {
      return const ReviewerSessionRequiredScreen();
    }
    return child;
  }
}

class GuardedRoute extends ConsumerWidget {
  const GuardedRoute({
    super.key,
    required this.child,
    this.requiredRole,
    this.allowIncompleteOnboarding = false,
  });

  final Widget child;
  final UserRole? requiredRole;
  final bool allowIncompleteOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseService.isInitialized) return const SetupRequiredScreen();
    ref.watch(authStateProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) return const AuthRequiredScreen();

    final profile = ref.watch(currentProfileProvider);
    final runtimeStatus = ref.watch(releaseModeStatusProvider);
    return profile.when(
      loading: () => const MortLoading(),
      error: (error, _) => MortErrorStateScreen(
        title: 'Profile guard error',
        message: userFacingError(error),
      ),
      data: (profile) {
        final maintenance = runtimeStatus.asData?.value['maintenance_mode'];
        if (maintenance == true) {
          return const MaintenanceModeScreen();
        }
        if (runtimeStatus.hasError) {
          return MortErrorStateScreen(
            title: 'Safety controls unavailable',
            message:
                'MORT could not verify its server safety controls. Check your connection and retry.',
          );
        }
        if (runtimeStatus.isLoading) return const MortLoading();
        final decision = evaluateRouteAccess(
          hasSession: true,
          profile: profile,
          requiredRole: requiredRole,
          allowIncompleteOnboarding: allowIncompleteOnboarding,
        );
        return switch (decision) {
          RouteAccessDecision.allow => child,
          RouteAccessDecision.authenticationRequired =>
            const AuthRequiredScreen(),
          RouteAccessDecision.onboardingRequired =>
            const OnboardingRequiredScreen(),
          RouteAccessDecision.accountRestricted => const AccountStatusScreen(),
          RouteAccessDecision.wrongRole => WrongRoleScreen(
            requiredRole: requiredRole!,
          ),
        };
      },
    );
  }
}

Widget _pilotUnavailable(String title, String description) {
  return FeatureScaffoldScreen(
    eyebrow: 'Not available',
    title: title,
    description: description,
    actions: const [
      MortAction(
        label: 'Back home',
        icon: Icons.home,
        route: '/account-status',
      ),
    ],
  );
}

Widget _academy() {
  return const FeatureScaffoldScreen(
    eyebrow: 'Hustle Academy',
    title: 'Learn safe earning',
    description:
        'Safety basics, proposals, scams, payment MVP, teen-safe jobs, and unsafe-situation guidance.',
    children: [
      FeatureChecklist(
        items: [
          'Keep communication on MORT.',
          'Do not share phone numbers, exact addresses, or social handles.',
          'Avoid upfront fees and off-platform pressure.',
          'Ask a guardian when a job feels unclear.',
        ],
      ),
    ],
  );
}

Widget _legalIndex() {
  return const FeatureScaffoldScreen(
    eyebrow: 'Legal',
    title: 'Disclosures and rules',
    description:
        'Review MORT rules, privacy practices, safety standards, and current disclosures. Independent legal and teen-safety review is still required before broader release.',
    actions: [
      MortAction(label: 'Terms', icon: Icons.article, route: '/legal/terms'),
      MortAction(
        label: 'Privacy',
        icon: Icons.privacy_tip,
        route: '/legal/privacy',
      ),
      MortAction(
        label: 'Ad disclosure',
        icon: Icons.ads_click,
        route: '/legal/ad-disclosure',
      ),
      MortAction(
        label: 'Teen safety',
        icon: Icons.shield,
        route: '/legal/teen-safety',
      ),
    ],
  );
}
