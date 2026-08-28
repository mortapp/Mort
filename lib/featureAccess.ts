import type { RevenueCatEntitlements } from "@/lib/revenuecat";
import type { UserRole } from "@/types/domain";

export type FeatureAccessInput = {
  role: UserRole | null;
  entitlements: RevenueCatEntitlements;
  isPremium: boolean;
  isAdFree: boolean;
};

export type FeatureAccess = {
  canShowAds: boolean;
  canChangeUsernameFree: boolean;
  canUseUsernameToken: boolean;
  canUsePremiumThemes: boolean;
  canUseExtraPortfolioSlots: boolean;
  canUseSavedJobFolders: boolean;
  canUseAdvancedFilters: boolean;
  canUseGoalAnalytics: boolean;
  canUseAdultApplicantSorting: boolean;
  canUseJobBoost: boolean;
  canUseGuardianWeeklyDigest: boolean;
  canUseBusinessAnalytics: boolean;
};

export function getFeatureAccess(input: FeatureAccessInput): FeatureAccess {
  const premium = input.isPremium || input.entitlements.plus || input.entitlements.lifetime;
  const adultPro = input.entitlements.adultPro || input.entitlements.lifetime;
  const guardianPlus = input.entitlements.guardianPlus || input.entitlements.lifetime;
  const styleAccess = premium || input.entitlements.profileStylePack;
  const jobBoost = input.role === "adult" && (adultPro || input.entitlements.jobBoost || input.entitlements.businessBoost);

  return {
    canShowAds: !input.isAdFree,
    canChangeUsernameFree: true,
    canUseUsernameToken: input.entitlements.usernameChangeToken || premium,
    canUsePremiumThemes: styleAccess,
    canUseExtraPortfolioSlots: premium,
    canUseSavedJobFolders: premium,
    canUseAdvancedFilters: premium,
    canUseGoalAnalytics: premium,
    canUseAdultApplicantSorting: input.role === "adult" && adultPro,
    canUseJobBoost: jobBoost,
    canUseGuardianWeeklyDigest: input.role === "guardian" && guardianPlus,
    canUseBusinessAnalytics: input.role === "adult" && adultPro
  };
}
