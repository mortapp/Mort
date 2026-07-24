import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/oauth_flow.dart';
import '../models/profile.dart';
import '../models/account_trust.dart';
import '../services/supabase_service.dart';
import 'account_trust_repository.dart';
import 'account_deletion_repository.dart';
import 'admin_repository.dart';
import 'applications_repository.dart';
import 'auth_repository.dart';
import 'avatar_repository.dart';
import 'guardian_repository.dart';
import 'jobs_repository.dart';
import 'job_execution_repository.dart';
import 'legal_contract_repository.dart';
import 'messaging_repository.dart';
import 'mission_pilot_repository.dart';
import 'mort_guide_repository.dart';
import 'monetization_repository.dart';
import 'notifications_repository.dart';
import 'profile_repository.dart';
import 'reviews_repository.dart';
import 'safety_repository.dart';
import 'support_repository.dart';
import 'stripe_marketplace_repository.dart';
import 'trust_safety_repository.dart';
import 'uploads_repository.dart';

final supabaseConfiguredProvider = Provider<bool>(
  (ref) => SupabaseService.isConfigured,
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepository(),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);
final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(),
);
final jobExecutionRepositoryProvider = Provider<JobExecutionRepository>(
  (ref) => JobExecutionRepository(),
);
final legalContractRepositoryProvider = Provider<LegalContractRepository>(
  (ref) => LegalContractRepository(),
);
final applicationsRepositoryProvider = Provider<ApplicationsRepository>(
  (ref) => ApplicationsRepository(),
);
final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => MessagingRepository(),
);
final missionPilotRepositoryProvider = Provider<MissionPilotRepository>(
  (ref) => MissionPilotRepository(),
);
final mortGuideRepositoryProvider = Provider<MortGuideRepository>(
  (ref) => MortGuideRepository(),
);
final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SafetyRepository(),
);
final trustSafetyRepositoryProvider = Provider<TrustSafetyRepository>(
  (ref) => TrustSafetyRepository(),
);
final accountTrustRepositoryProvider = Provider<AccountTrustRepository>(
  (ref) => AccountTrustRepository(),
);
final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepository(),
);
final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(),
);
final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepository(),
);
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);
final uploadsRepositoryProvider = Provider<UploadsRepository>(
  (ref) => UploadsRepository(),
);
final monetizationRepositoryProvider = Provider<MonetizationRepository>(
  (ref) => MonetizationRepository(),
);
final reviewsRepositoryProvider = Provider<ReviewsRepository>(
  (ref) => ReviewsRepository(),
);
final stripeMarketplaceRepositoryProvider =
    Provider<StripeMarketplaceRepository>(
      (ref) => StripeMarketplaceRepository(),
    );

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final oauthFlowStateProvider = StreamProvider<OAuthFlowSnapshot>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.oauthState;
  yield* repository.oauthStates;
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  if (!SupabaseService.isInitialized) return null;
  return ref.watch(profileRepositoryProvider).getCurrentProfile();
});

final accountTrustProfileProvider = FutureProvider<AccountTrustProfile>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(accountTrustRepositoryProvider).getMyProfile();
});
