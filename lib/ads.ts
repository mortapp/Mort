import { Platform } from "react-native";

import {
  ADMOB_ANDROID_BANNER_AD_UNIT_ID,
  ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID,
  ADMOB_ANDROID_NATIVE_AD_UNIT_ID,
  ADMOB_ANDROID_REWARDED_AD_UNIT_ID,
  ADMOB_IOS_BANNER_AD_UNIT_ID,
  ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID,
  ADMOB_IOS_NATIVE_AD_UNIT_ID,
  ADMOB_IOS_REWARDED_AD_UNIT_ID,
  ADS_ENABLED,
  USE_TEST_ADS
} from "@/lib/env";
import { configureMobileAds } from "@/lib/mobileAdsBridge";
import type { UserRole } from "@/types/domain";

export type AdPlacement =
  | "teen-feed"
  | "adult-dashboard"
  | "settings"
  | "hustle-academy"
  | "profile"
  | "job-search"
  | "saved-jobs"
  | "notifications-empty"
  | "adult-job-templates"
  | "home-dashboard"
  | "chat"
  | "safety"
  | "report"
  | "proof"
  | "verification"
  | "guardian-approval"
  | "admin"
  | "payment"
  | "paywall";

export type AdFormat = "banner" | "interstitial" | "rewarded" | "native";

export type AdEligibilityInput = {
  placement: AdPlacement;
  format: AdFormat;
  role?: UserRole | null;
  age?: number | null;
  hasAdFreeEntitlement?: boolean;
  personalizedAdsAllowed?: boolean;
  consentReady?: boolean;
};

export type AdEligibility = {
  allowed: boolean;
  reason: string;
  requestNonPersonalizedAdsOnly: boolean;
};

const sensitivePlacements: AdPlacement[] = [
  "chat",
  "safety",
  "report",
  "proof",
  "verification",
  "guardian-approval",
  "admin",
  "payment",
  "paywall"
];

let initialized = false;
let lastInterstitialAt = 0;
let usefulActionCount = 0;
let interstitialsThisSession = 0;

export async function initializeAds(role?: UserRole | null, age?: number | null) {
  if (!ADS_ENABLED) return { initialized: false, reason: "Ads are disabled for this build." };
  if (Platform.OS !== "ios" && Platform.OS !== "android") {
    return { initialized: false, reason: "Ads require a native iOS or Android build." };
  }

  const conservative = role === "teen" || !role || (typeof age === "number" && age < 18);

  if (!initialized) {
    await configureMobileAds({ conservative });
    initialized = true;
  }

  return { initialized: true, reason: "Google Mobile Ads initialized." };
}

export function markUsefulAdAction() {
  usefulActionCount += 1;
}

export function evaluateAdEligibility(input: AdEligibilityInput): AdEligibility {
  const isTeenOrUnknown = input.role === "teen" || !input.role || (typeof input.age === "number" && input.age < 18);
  const requestNonPersonalizedAdsOnly = isTeenOrUnknown || input.personalizedAdsAllowed !== true;

  if (!ADS_ENABLED) return { allowed: false, reason: "Ads are disabled for this build.", requestNonPersonalizedAdsOnly };
  if (Platform.OS !== "ios" && Platform.OS !== "android") {
    return { allowed: false, reason: "Ads require a native iOS or Android build.", requestNonPersonalizedAdsOnly };
  }
  if (input.hasAdFreeEntitlement) {
    return { allowed: false, reason: "Ads hidden because ad-free entitlement is active.", requestNonPersonalizedAdsOnly };
  }
  if (input.consentReady !== true) {
    return { allowed: false, reason: "Ads wait for consent and privacy setup.", requestNonPersonalizedAdsOnly };
  }
  if (sensitivePlacements.includes(input.placement)) {
    return { allowed: false, reason: "Ads are disabled on this safety-sensitive screen.", requestNonPersonalizedAdsOnly };
  }
  if (!getAdUnitId(input.format)) {
    return { allowed: false, reason: "Ad unit ID is missing for this platform/format.", requestNonPersonalizedAdsOnly };
  }
  if (input.format === "rewarded" && input.role === "teen") {
    return { allowed: false, reason: "Rewarded ads are disabled for teen users until legal review approves placements.", requestNonPersonalizedAdsOnly };
  }
  if (input.format === "interstitial") {
    const now = Date.now();
    if (interstitialsThisSession >= 1) {
      return { allowed: false, reason: "Interstitial frequency cap reached for this session.", requestNonPersonalizedAdsOnly };
    }
    if (now - lastInterstitialAt < 10 * 60 * 1000) {
      return { allowed: false, reason: "Interstitial cooldown is active.", requestNonPersonalizedAdsOnly };
    }
    if (input.role === "teen" && usefulActionCount < 5) {
      return { allowed: false, reason: "Teen users need useful actions before any interstitial.", requestNonPersonalizedAdsOnly };
    }
  }

  return { allowed: true, reason: "Ad placement is eligible.", requestNonPersonalizedAdsOnly };
}

export function markInterstitialShown() {
  lastInterstitialAt = Date.now();
  interstitialsThisSession += 1;
}

export function getAdUnitId(format: AdFormat) {
  if (USE_TEST_ADS) return getTestAdUnitId(format);

  if (Platform.OS === "ios") {
    if (format === "banner") return ADMOB_IOS_BANNER_AD_UNIT_ID;
    if (format === "interstitial") return ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID;
    if (format === "rewarded") return ADMOB_IOS_REWARDED_AD_UNIT_ID;
    return ADMOB_IOS_NATIVE_AD_UNIT_ID;
  }

  if (Platform.OS === "android") {
    if (format === "banner") return ADMOB_ANDROID_BANNER_AD_UNIT_ID;
    if (format === "interstitial") return ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID;
    if (format === "rewarded") return ADMOB_ANDROID_REWARDED_AD_UNIT_ID;
    return ADMOB_ANDROID_NATIVE_AD_UNIT_ID;
  }

  return "";
}

function getTestAdUnitId(format: AdFormat) {
  if (format === "banner") return "ca-app-pub-3940256099942544/6300978111";
  if (format === "interstitial") return "ca-app-pub-3940256099942544/1033173712";
  if (format === "rewarded") return "ca-app-pub-3940256099942544/5224354917";
  return "ca-app-pub-3940256099942544/2247696110";
}
