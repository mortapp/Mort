import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/oauth_flow.dart';
import '../models/profile.dart';
import '../models/onboarding_progress.dart';
import '../models/job.dart';
import '../models/account_trust.dart';
import '../services/supabase_service.dart';
import '../services/secure_draft_storage.dart';
import 'account_trust_repository.dart';
import 'account_deletion_repository.dart';
import 'admin_repository.dart';
import 'applications_repository.dart';
import 'auth_repository.dart';
import 'avatar_repository.dart';
import 'guardian_repository.dart';
import 'jobs_repository.dart';
import 'job_execution_repository.dart';
import 'leaderboard_repository.dart';
import 'legal_contract_repository.dart';
import 'messaging_repository.dart';
import 'mission_pilot_repository.dart';
import 'mort_guide_repository.dart';
import 'monetization_repository.dart';
import 'notifications_repository.dart';
import 'observability_repository.dart';
import 'profile_repository.dart';
import 'reviews_repository.dart';
import 'safety_repository.dart';
import 'support_repository.dart';
import 'support_assistant_repository.dart';
import 'stripe_marketplace_repository.dart';
import 'trust_safety_repository.dart';
import 'uploads_repository.dart';

final supabaseConfiguredProvider = Provider<bool>(
  (ref) => SupabaseService.isConfigured,
);
final supabaseReadyProvider = Provider<bool>(
  (ref) => SupabaseService.isInitialized,
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
final secureDraftStorageProvider = Provider<MortSecureDraftStorage>(
  (ref) => MortSecureDraftStorage(),
);
final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(),
);
final openJobsProvider = AsyncNotifierProvider.autoDispose
    .family<OpenJobsController, JobFeedState, JobSearchFilters>(
      OpenJobsController.new,
    );

class JobFeedState {
  const JobFeedState({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.loadingMore = false,
    this.servedFromSessionCache = false,
    this.paginationError,
  });

  final List<Job> items;
  final bool hasMore;
  final JobPageCursor? nextCursor;
  final bool loadingMore;
  final bool servedFromSessionCache;
  final Object? paginationError;

  factory JobFeedState.fromPage(JobPage page) => JobFeedState(
    items: page.items,
    hasMore: page.hasMore,
    nextCursor: page.nextCursor,
    servedFromSessionCache: page.servedFromSessionCache,
  );

  JobFeedState copyWith({
    List<Job>? items,
    bool? hasMore,
    JobPageCursor? nextCursor,
    bool? loadingMore,
    bool? servedFromSessionCache,
    Object? paginationError,
    bool clearPaginationError = false,
    bool clearNextCursor = false,
  }) => JobFeedState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
    servedFromSessionCache:
        servedFromSessionCache ?? this.servedFromSessionCache,
    paginationError: clearPaginationError
        ? null
        : paginationError ?? this.paginationError,
  );
}

class OpenJobsController extends AsyncNotifier<JobFeedState> {
  OpenJobsController(this.filters);

  final JobSearchFilters filters;

  @override
  Future<JobFeedState> build() async {
    final page = await ref
        .watch(jobsRepositoryProvider)
        .listOpenJobsPage(filters: filters);
    return JobFeedState.fromPage(page);
  }

  Future<void> loadNext() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        current.nextCursor == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(loadingMore: true, clearPaginationError: true),
    );
    try {
      final page = await ref
          .read(jobsRepositoryProvider)
          .listOpenJobsPage(filters: filters, cursor: current.nextCursor);
      final existingIds = current.items.map((job) => job.id).toSet();
      final appended = [
        ...current.items,
        ...page.items.where((job) => existingIds.add(job.id)),
      ];
      state = AsyncData(
        current.copyWith(
          items: appended,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loadingMore: false,
          servedFromSessionCache:
              current.servedFromSessionCache || page.servedFromSessionCache,
          clearPaginationError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(loadingMore: false, paginationError: error),
      );
    }
  }
}

final jobExecutionRepositoryProvider = Provider<JobExecutionRepository>(
  (ref) => JobExecutionRepository(),
);
final legalContractRepositoryProvider = Provider<LegalContractRepository>(
  (ref) => LegalContractRepository(),
);
final applicationsRepositoryProvider = Provider<ApplicationsRepository>(
  (ref) => ApplicationsRepository(),
);
final myApplicationsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(applicationsRepositoryProvider).listMyApplications(),
);
final myJobsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(jobsRepositoryProvider).listMyJobs(),
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
final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(),
);
final leaderboardProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(leaderboardRepositoryProvider).getLeaderboard(limit: 5),
);
final myLeaderboardRankProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(leaderboardRepositoryProvider).getMyRank(),
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
final supportAssistantRepositoryProvider = Provider<SupportAssistantRepository>(
  (ref) => SupportAssistantRepository(),
);
final supportAssistantConversationsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(supportAssistantRepositoryProvider).listConversations(),
);
final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepository(),
);
final guardianConnectionsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(guardianRepositoryProvider).listConnections(),
);
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);
final observabilityRepositoryProvider = Provider<ObservabilityRepository>(
  (ref) => ObservabilityRepository(),
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
final receivedReviewsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(reviewsRepositoryProvider).listReceived(),
);
final myReportsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(safetyRepositoryProvider).listMyReports(),
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

final onboardingProgressProvider = FutureProvider<OnboardingProgress>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getOnboardingProgress();
});

final accountTrustProfileProvider = FutureProvider<AccountTrustProfile>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(accountTrustRepositoryProvider).getMyProfile();
});

void invalidateUserScopedProviders(WidgetRef ref) {
  ref.invalidate(authStateProvider);
  ref.invalidate(oauthFlowStateProvider);
  ref.invalidate(currentProfileProvider);
  ref.invalidate(onboardingProgressProvider);
  ref.invalidate(accountTrustProfileProvider);
  ref.invalidate(openJobsProvider);
  ref.invalidate(myApplicationsProvider);
  ref.invalidate(myJobsProvider);
  ref.invalidate(supportAssistantConversationsProvider);
  ref.invalidate(guardianConnectionsProvider);
  ref.invalidate(receivedReviewsProvider);
  ref.invalidate(myReportsProvider);
  ref.invalidate(authRepositoryProvider);
  ref.invalidate(avatarRepositoryProvider);
  ref.invalidate(profileRepositoryProvider);
  ref.invalidate(jobsRepositoryProvider);
  ref.invalidate(jobExecutionRepositoryProvider);
  ref.invalidate(applicationsRepositoryProvider);
  ref.invalidate(messagingRepositoryProvider);
  ref.invalidate(notificationsRepositoryProvider);
  ref.invalidate(supportRepositoryProvider);
  ref.invalidate(supportAssistantRepositoryProvider);
  ref.invalidate(uploadsRepositoryProvider);
  ref.invalidate(monetizationRepositoryProvider);
  ref.invalidate(reviewsRepositoryProvider);
  ref.invalidate(guardianRepositoryProvider);
  ref.invalidate(safetyRepositoryProvider);
  ref.invalidate(trustSafetyRepositoryProvider);
  ref.invalidate(accountTrustRepositoryProvider);
  ref.invalidate(accountDeletionRepositoryProvider);
  ref.invalidate(adminRepositoryProvider);
}
