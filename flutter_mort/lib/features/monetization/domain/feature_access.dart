import '../../../core/config/app_config.dart';
import '../data/revenuecat_service.dart';

class FeatureAccess {
  const FeatureAccess({
    required this.canShowAds,
    required this.canUsePlus,
    required this.canUseAdFree,
    required this.canUseAdultPro,
    required this.canUseGuardianPlus,
    required this.canUseUsernameChangeToken,
    required this.canUseJobBoost,
    required this.canUsePremiumThemes,
    required this.canUseExtraPortfolioSlots,
    required this.canUseSavedJobFolders,
    required this.canUseAdvancedFilters,
    required this.canUseGoalAnalytics,
    required this.canUseAdultApplicantSorting,
    required this.canUseGuardianWeeklyDigest,
  });

  final bool canShowAds;
  final bool canUsePlus;
  final bool canUseAdFree;
  final bool canUseAdultPro;
  final bool canUseGuardianPlus;
  final bool canUseUsernameChangeToken;
  final bool canUseJobBoost;
  final bool canUsePremiumThemes;
  final bool canUseExtraPortfolioSlots;
  final bool canUseSavedJobFolders;
  final bool canUseAdvancedFilters;
  final bool canUseGoalAnalytics;
  final bool canUseAdultApplicantSorting;
  final bool canUseGuardianWeeklyDigest;

  factory FeatureAccess.fromEntitlements(RevenueCatEntitlementState state) {
    final plus = state.isPlus;
    final adFree = state.isAdFree;
    final adultPro = state.isAdultPro;
    final guardianPlus = state.isGuardianPlus;

    return FeatureAccess(
      canShowAds: AppConfig.adsEnabled && !adFree,
      canUsePlus: plus,
      canUseAdFree: adFree,
      canUseAdultPro: adultPro,
      canUseGuardianPlus: guardianPlus,
      canUseUsernameChangeToken: state.hasUsernameToken,
      canUseJobBoost: state.hasJobBoost,
      canUsePremiumThemes: plus || state.hasProfileStylePack,
      canUseExtraPortfolioSlots: plus,
      canUseSavedJobFolders: plus,
      canUseAdvancedFilters: plus,
      canUseGoalAnalytics: plus,
      canUseAdultApplicantSorting: adultPro,
      canUseGuardianWeeklyDigest: guardianPlus,
    );
  }

  bool get safetyToolsFree => true;
  bool get basicApplyingFree => true;
  bool get basicGuardianModeFree => true;
  bool get proofUploadFree => true;
  bool get reportBlockSafetyPingFree => true;
}
