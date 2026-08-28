import { Platform } from "react-native";
import type {
  CustomerInfo,
  MakePurchaseResult,
  PurchasesOfferings,
  PurchasesPackage
} from "react-native-purchases";

import {
  IAP_ENABLED,
  REVENUECAT_ANDROID_API_KEY,
  REVENUECAT_ENTITLEMENT_AD_FREE,
  REVENUECAT_ENTITLEMENT_ADULT_PRO,
  REVENUECAT_ENTITLEMENT_BUSINESS_BOOST,
  REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS,
  REVENUECAT_ENTITLEMENT_JOB_BOOST,
  REVENUECAT_ENTITLEMENT_LIFETIME,
  REVENUECAT_ENTITLEMENT_PREMIUM,
  REVENUECAT_ENTITLEMENT_PROFILE_STYLE_PACK,
  REVENUECAT_ENTITLEMENT_USERNAME_CHANGE_TOKEN,
  REVENUECAT_IOS_API_KEY
} from "@/lib/env";

export type RevenueCatEntitlements = {
  premium: boolean;
  plus: boolean;
  adFree: boolean;
  adultPro: boolean;
  businessBoost: boolean;
  guardianPlus: boolean;
  lifetime: boolean;
  profileStylePack: boolean;
  usernameChangeToken: boolean;
  jobBoost: boolean;
};

export type RevenueCatStatus =
  | "disabled"
  | "unsupported-platform"
  | "missing-api-key"
  | "configured"
  | "error";

export type RevenueCatSnapshot = {
  status: RevenueCatStatus;
  customerInfo: CustomerInfo | null;
  offerings: PurchasesOfferings | null;
  entitlements: RevenueCatEntitlements;
  message?: string;
};

const emptyEntitlements: RevenueCatEntitlements = {
  premium: false,
  plus: false,
  adFree: false,
  adultPro: false,
  businessBoost: false,
  guardianPlus: false,
  lifetime: false,
  profileStylePack: false,
  usernameChangeToken: false,
  jobBoost: false
};

let configured = false;
let configuredUserId: string | null = null;

function getPlatformApiKey() {
  if (Platform.OS === "ios") return REVENUECAT_IOS_API_KEY;
  if (Platform.OS === "android") return REVENUECAT_ANDROID_API_KEY;
  return "";
}

export function getRevenueCatSetupStatus(): RevenueCatStatus {
  if (!IAP_ENABLED) return "disabled";
  if (Platform.OS !== "ios" && Platform.OS !== "android") return "unsupported-platform";
  if (!getPlatformApiKey()) return "missing-api-key";
  return configured ? "configured" : "configured";
}

export function extractEntitlements(customerInfo: CustomerInfo | null): RevenueCatEntitlements {
  const active = customerInfo?.entitlements.active ?? {};
  const plus = Boolean(active[REVENUECAT_ENTITLEMENT_PREMIUM]);
  const lifetime = Boolean(active[REVENUECAT_ENTITLEMENT_LIFETIME]);
  const jobBoost = Boolean(active[REVENUECAT_ENTITLEMENT_JOB_BOOST] || active[REVENUECAT_ENTITLEMENT_BUSINESS_BOOST]);

  return {
    premium: plus || lifetime,
    plus,
    adFree: Boolean(active[REVENUECAT_ENTITLEMENT_AD_FREE]) || plus || lifetime,
    adultPro: Boolean(active[REVENUECAT_ENTITLEMENT_ADULT_PRO]),
    businessBoost: jobBoost,
    guardianPlus: Boolean(active[REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS]),
    lifetime,
    profileStylePack: Boolean(active[REVENUECAT_ENTITLEMENT_PROFILE_STYLE_PACK]),
    usernameChangeToken: Boolean(active[REVENUECAT_ENTITLEMENT_USERNAME_CHANGE_TOKEN]),
    jobBoost
  };
}

export async function configureRevenueCat(appUserID?: string | null): Promise<RevenueCatStatus> {
  if (!IAP_ENABLED) return "disabled";
  if (Platform.OS !== "ios" && Platform.OS !== "android") return "unsupported-platform";

  const apiKey = getPlatformApiKey();
  if (!apiKey) return "missing-api-key";

  const PurchasesModule = await import("react-native-purchases");
  const Purchases = PurchasesModule.default;

  if (!configured) {
    await Purchases.setLogLevel(PurchasesModule.LOG_LEVEL.INFO);
    Purchases.configure({ apiKey, appUserID: appUserID ?? undefined });
    configured = true;
    configuredUserId = appUserID ?? null;
    return "configured";
  }

  if (appUserID && configuredUserId !== appUserID) {
    const result = await Purchases.logIn(appUserID);
    configuredUserId = appUserID;
    if (!result.customerInfo) return "configured";
  }

  return "configured";
}

export async function refreshRevenueCatSnapshot(appUserID?: string | null): Promise<RevenueCatSnapshot> {
  const status = await configureRevenueCat(appUserID);
  if (status !== "configured") {
    return {
      status,
      customerInfo: null,
      offerings: null,
      entitlements: emptyEntitlements,
      message: statusMessage(status)
    };
  }

  const Purchases = (await import("react-native-purchases")).default;
  const [customerInfo, offerings] = await Promise.all([Purchases.getCustomerInfo(), Purchases.getOfferings()]);

  return {
    status,
    customerInfo,
    offerings,
    entitlements: extractEntitlements(customerInfo)
  };
}

export async function purchaseRevenueCatPackage(
  aPackage: PurchasesPackage,
  appUserID?: string | null
): Promise<MakePurchaseResult> {
  const status = await configureRevenueCat(appUserID);
  if (status !== "configured") {
    throw new Error(statusMessage(status));
  }

  const Purchases = (await import("react-native-purchases")).default;
  return Purchases.purchasePackage(aPackage);
}

export async function restoreRevenueCatPurchases(appUserID?: string | null) {
  const status = await configureRevenueCat(appUserID);
  if (status !== "configured") {
    throw new Error(statusMessage(status));
  }

  const Purchases = (await import("react-native-purchases")).default;
  return Purchases.restorePurchases();
}

export async function logOutRevenueCat() {
  if (!configured) return;
  if (Platform.OS !== "ios" && Platform.OS !== "android") return;

  const Purchases = (await import("react-native-purchases")).default;
  await Purchases.logOut();
  configuredUserId = null;
}

export function statusMessage(status: RevenueCatStatus) {
  if (status === "disabled") return "In-app purchases are disabled for this build.";
  if (status === "unsupported-platform") return "RevenueCat purchases require a native iOS or Android build.";
  if (status === "missing-api-key") return "RevenueCat public SDK API key is missing for this platform.";
  if (status === "error") return "RevenueCat could not complete the request.";
  return "RevenueCat is configured.";
}

export function packageDisplayName(aPackage: PurchasesPackage) {
  return aPackage.product.title || aPackage.identifier;
}

export function packagePrice(aPackage: PurchasesPackage) {
  return aPackage.product.priceString || "Price unavailable";
}
