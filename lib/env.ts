export const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "";
export const APP_ENV = process.env.EXPO_PUBLIC_APP_ENV ?? "development";

export const REVENUECAT_IOS_API_KEY = process.env.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY ?? "";
export const REVENUECAT_ANDROID_API_KEY = process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_API_KEY ?? "";
export const REVENUECAT_ENTITLEMENT_PLUS = process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_PLUS ?? "mort_plus";
export const REVENUECAT_ENTITLEMENT_PREMIUM =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_PREMIUM ?? REVENUECAT_ENTITLEMENT_PLUS;
export const REVENUECAT_ENTITLEMENT_AD_FREE =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_AD_FREE ?? "mort_ad_free";
export const REVENUECAT_ENTITLEMENT_ADULT_PRO =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_ADULT_PRO ?? "mort_adult_pro";
export const REVENUECAT_ENTITLEMENT_BUSINESS_BOOST =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_BUSINESS_BOOST ?? "mort_job_boost";
export const REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS ?? "mort_guardian_plus";
export const REVENUECAT_ENTITLEMENT_LIFETIME =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_LIFETIME ?? "mort_lifetime";
export const REVENUECAT_ENTITLEMENT_PROFILE_STYLE_PACK =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_PROFILE_STYLE_PACK ?? "mort_profile_style_pack";
export const REVENUECAT_ENTITLEMENT_USERNAME_CHANGE_TOKEN =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_USERNAME_CHANGE_TOKEN ?? "mort_username_change_token";
export const REVENUECAT_ENTITLEMENT_JOB_BOOST =
  process.env.EXPO_PUBLIC_REVENUECAT_ENTITLEMENT_JOB_BOOST ?? "mort_job_boost";

export const ADMOB_IOS_APP_ID =
  process.env.EXPO_PUBLIC_ADMOB_IOS_APP_ID ?? "ca-app-pub-9412242686563958~6217664808";
export const ADMOB_ANDROID_APP_ID = process.env.EXPO_PUBLIC_ADMOB_ANDROID_APP_ID ?? "";
export const ADMOB_IOS_BANNER_AD_UNIT_ID = process.env.EXPO_PUBLIC_ADMOB_IOS_BANNER_AD_UNIT_ID ?? "";
export const ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID =
  process.env.EXPO_PUBLIC_ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID ?? "";
export const ADMOB_IOS_REWARDED_AD_UNIT_ID = process.env.EXPO_PUBLIC_ADMOB_IOS_REWARDED_AD_UNIT_ID ?? "";
export const ADMOB_IOS_NATIVE_AD_UNIT_ID = process.env.EXPO_PUBLIC_ADMOB_IOS_NATIVE_AD_UNIT_ID ?? "";
export const ADMOB_ANDROID_BANNER_AD_UNIT_ID =
  process.env.EXPO_PUBLIC_ADMOB_ANDROID_BANNER_AD_UNIT_ID ?? "";
export const ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID =
  process.env.EXPO_PUBLIC_ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID ?? "";
export const ADMOB_ANDROID_REWARDED_AD_UNIT_ID =
  process.env.EXPO_PUBLIC_ADMOB_ANDROID_REWARDED_AD_UNIT_ID ?? "";
export const ADMOB_ANDROID_NATIVE_AD_UNIT_ID =
  process.env.EXPO_PUBLIC_ADMOB_ANDROID_NATIVE_AD_UNIT_ID ?? "";

export const ADS_ENABLED = process.env.EXPO_PUBLIC_ADS_ENABLED === "true";
export const IAP_ENABLED = process.env.EXPO_PUBLIC_IAP_ENABLED === "true";
export const USE_TEST_ADS = process.env.EXPO_PUBLIC_USE_TEST_ADS !== "false";

const isHostedSupabaseUrl = SUPABASE_URL.startsWith("https://") && SUPABASE_URL.includes(".supabase.co");
const isLocalSupabaseUrl =
  SUPABASE_URL.startsWith("http://127.0.0.1:") ||
  SUPABASE_URL.startsWith("http://localhost:");

export const isSupabaseConfigured =
  (isHostedSupabaseUrl || isLocalSupabaseUrl) &&
  SUPABASE_ANON_KEY.length > 20;
