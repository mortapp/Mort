import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const expectedFlutterSdkKey = ["test", "YKOBjNITvzPEMKMDpFUTnSZHDQn"].join("_");
export const revenueCatBaseUrl = "https://api.revenuecat.com/v2";
export const mortSupabaseProjectRef = "rakjydmgwwgtdislanbt";
export const mortSupabaseUrl = `https://${mortSupabaseProjectRef}.supabase.co`;
export const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

export const products = [
  product("mort_plus_monthly", "MORT Plus Monthly", "subscription", "$0.99/month", "P1M"),
  product("mort_plus_yearly", "MORT Plus Yearly", "subscription", "$7.99/year", "P1Y"),
  product("mort_plus_lifetime", "MORT Lifetime", "non_consumable", "$14.99 one-time"),
  product("mort_ad_free_lifetime", "Ad-Free Lifetime", "non_consumable", "$1.99 one-time"),
  product("mort_username_change_token_1", "Username Change Token", "consumable", "$1.99"),
  product("mort_profile_style_pack", "Profile Style Pack", "non_consumable", "$0.99"),
  product("mort_adult_pro_monthly", "Adult Pro Monthly", "subscription", "$2.99/month", "P1M"),
  product("mort_guardian_plus_monthly", "Guardian Plus Monthly", "subscription", "$1.99/month", "P1M"),
  product("mort_job_boost_1", "Job Boost", "consumable", "$1.99"),
];

export const entitlements = [
  entitlement("mort_plus", "MORT Plus"),
  entitlement("mort_ad_free", "Ad-Free"),
  entitlement("mort_adult_pro", "Adult Pro"),
  entitlement("mort_guardian_plus", "Guardian Plus"),
  entitlement("mort_lifetime", "MORT Lifetime"),
  entitlement("mort_profile_style_pack", "Profile Style Pack"),
  entitlement("mort_username_change_token", "Username Change Token"),
  entitlement("mort_job_boost", "Job Boost"),
];

export const entitlementProductMap = {
  mort_plus: ["mort_plus_monthly", "mort_plus_yearly", "mort_plus_lifetime"],
  mort_ad_free: ["mort_ad_free_lifetime", "mort_plus_monthly", "mort_plus_yearly", "mort_plus_lifetime"],
  mort_adult_pro: ["mort_adult_pro_monthly"],
  mort_guardian_plus: ["mort_guardian_plus_monthly"],
  mort_lifetime: ["mort_plus_lifetime"],
  mort_profile_style_pack: ["mort_profile_style_pack"],
  mort_username_change_token: ["mort_username_change_token_1"],
  mort_job_boost: ["mort_job_boost_1"],
};

export const offerings = [
  offering("default", "Default MORT Perks", true, [
    pkg("monthly", "MORT Plus Monthly", "mort_plus_monthly", 1),
    pkg("annual", "MORT Plus Yearly", "mort_plus_yearly", 2),
    pkg("lifetime", "MORT Lifetime", "mort_plus_lifetime", 3),
    pkg("ad_free", "Ad-Free Lifetime", "mort_ad_free_lifetime", 4),
  ]),
  offering("teen_perks", "Teen Perks", false, [
    pkg("monthly", "MORT Plus Monthly", "mort_plus_monthly", 1),
    pkg("annual", "MORT Plus Yearly", "mort_plus_yearly", 2),
    pkg("lifetime", "MORT Lifetime", "mort_plus_lifetime", 3),
    pkg("username_change", "Username Change Token", "mort_username_change_token_1", 4),
    pkg("profile_style", "Profile Style Pack", "mort_profile_style_pack", 5),
  ]),
  offering("adult_pro", "Adult Pro", false, [
    pkg("monthly", "Adult Pro Monthly", "mort_adult_pro_monthly", 1),
    pkg("job_boost", "Job Boost", "mort_job_boost_1", 2),
  ]),
  offering("guardian_plus", "Guardian Plus", false, [
    pkg("monthly", "Guardian Plus Monthly", "mort_guardian_plus_monthly", 1),
  ]),
  offering("ad_free", "Ad-Free", false, [
    pkg("lifetime", "Ad-Free Lifetime", "mort_ad_free_lifetime", 1),
  ]),
  offering("username_change", "Username Change", false, [
    pkg("token", "Username Change Token", "mort_username_change_token_1", 1),
  ]),
  offering("job_boost", "Job Boost", false, [
    pkg("boost", "Job Boost", "mort_job_boost_1", 1),
  ]),
];

export const paywallCopy = {
  default: {
    header: "Make MORT yours.",
    subheader: "Free stays useful. Plus just gives you extra style, control, and convenience.",
    primaryCta: "Upgrade if you want",
    secondaryCta: "Keep using free",
    perks: [
      "Ad-free browsing on safe screens",
      "1 extra username change per month",
      "Premium profile themes",
      "Premium badge",
      "Extra portfolio slots",
      "Saved job folders",
      "Advanced filters",
      "Goal analytics",
      "Profile insights",
      "Early access perks",
    ],
  },
  username_change: {
    header: "Need another name change?",
    subheader: "You get 3 free username changes. After that, grab a cheap token if you want another one.",
    primaryCta: "Get username token",
    secondaryCta: "Keep current username",
    perks: ["Optional username token", "Safety scanner still applies"],
  },
  adult_pro: {
    header: "Post smarter, not harder.",
    subheader: "Adult Pro gives you templates, applicant sorting, and job insights.",
    primaryCta: "Upgrade if you want",
    secondaryCta: "Keep using free",
    perks: ["Applicant sorting", "Job insights", "Posting templates"],
  },
  guardian_plus: {
    header: "More visibility, still optional.",
    subheader: "Basic Guardian Mode stays free. Plus adds deeper digests and extra organization.",
    primaryCta: "Upgrade if you want",
    secondaryCta: "Keep basic Guardian Mode",
    perks: ["Weekly digest", "Extra organization", "More visibility"],
  },
  ad_free: {
    header: "Keep the browsing quieter.",
    subheader: "Ad-free removes ads on safe screens. Safety tools stay free.",
    primaryCta: "Go ad-free",
    secondaryCta: "Keep using free",
    perks: ["Ad-free browsing on safe screens", "No safety feature is locked"],
  },
  job_boost: {
    header: "Boost this job.",
    subheader: "Give this job extra visibility. Boosts never bypass safety review.",
    primaryCta: "Boost job",
    secondaryCta: "Skip boost",
    perks: ["Extra visibility", "Still requires moderation", "No safety bypass"],
  },
  teen_perks: {
    header: "Make MORT yours.",
    subheader: "Free stays useful. Perks are optional.",
    primaryCta: "Upgrade if you want",
    secondaryCta: "Keep using free",
    perks: ["Premium themes", "Username token", "Ad-free on safe screens"],
  },
};

export const freeForeverFeatures = [
  "basic account",
  "basic job feed",
  "basic applying",
  "basic Guardian Mode",
  "report/block",
  "Safety Ping",
  "safe messaging scanner",
  "basic proof upload",
  "basic notifications",
];

export const webhookEventTypes = [
  "initial_purchase",
  "renewal",
  "product_change",
  "cancellation",
  "billing_issue",
  "non_renewing_purchase",
  "uncancellation",
  "transfer",
  "subscription_paused",
  "expiration",
  "subscription_extended",
  "invoice_issuance",
  "temporary_entitlement_grant",
  "refund_reversed",
];

function product(storeIdentifier, displayName, type, suggestedPrice, subscriptionDuration = null) {
  return { storeIdentifier, displayName, type, suggestedPrice, subscriptionDuration };
}

function entitlement(lookupKey, displayName) {
  return { lookupKey, displayName };
}

function offering(lookupKey, displayName, isCurrent, packages) {
  return { lookupKey, displayName, isCurrent, packages };
}

function pkg(lookupKey, displayName, productIdentifier, position) {
  return { lookupKey, displayName, productIdentifier, position };
}

export class RevenueCatApiError extends Error {
  constructor(status, body, path) {
    const type = body?.type ? `${body.type}: ` : "";
    super(`${status} ${type}${body?.message ?? "RevenueCat API request failed"} (${path})`);
    this.name = "RevenueCatApiError";
    this.status = status;
    this.body = body;
    this.path = path;
  }
}

export class RevenueCatApi {
  constructor(apiKey) {
    this.apiKey = apiKey;
  }

  async request(path, options = {}) {
    const method = options.method ?? "GET";
    const body = options.body;
    const response = await fetch(`${revenueCatBaseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        Accept: "application/json",
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    const text = await response.text();
    const parsed = text ? parseJson(text) : null;

    if (response.status === 429 && !options._retried) {
      const retryAfter = Number(response.headers.get("retry-after") ?? 1);
      await sleep(Math.min(Math.max(retryAfter, 1), 5) * 1000);
      return this.request(path, { ...options, _retried: true });
    }

    if (!response.ok) {
      throw new RevenueCatApiError(response.status, parsed, path);
    }

    return parsed;
  }

  async listAll(path) {
    const items = [];
    let nextPath = path.includes("?") ? `${path}&limit=100` : `${path}?limit=100`;
    while (nextPath) {
      const page = await this.request(nextPath);
      items.push(...(page?.items ?? []));
      nextPath = page?.next_page ?? null;
    }
    return items;
  }
}

export function envValue(name) {
  if (process.env[name]) return process.env[name];
  if (process.platform !== "win32") return "";
  try {
    return execFileSync(
      "powershell.exe",
      [
        "-NoProfile",
        "-Command",
        `[Environment]::GetEnvironmentVariable('${name.Replace ? name.Replace("'", "''") : name.replaceAll("'", "''")}','User')`,
      ],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).replace(/\r?\n$/, "");
  } catch {
    return "";
  }
}

export function requireEnvValue(name) {
  const value = envValue(name);
  if (!value) {
    throw new Error(`Set ${name}.`);
  }
  return value;
}

export function requireRevenueCatSecretKey() {
  const v1SecretKey = envValue("REVENUECAT_V1_SECRET_API_KEY");
  if (v1SecretKey) return { value: v1SecretKey, envName: "REVENUECAT_V1_SECRET_API_KEY" };

  const v2SecretKey = envValue("REVENUECAT_V2_SECRET_API_KEY");
  if (v2SecretKey) return { value: v2SecretKey, envName: "REVENUECAT_V2_SECRET_API_KEY" };

  throw new Error("Set REVENUECAT_V2_SECRET_API_KEY or REVENUECAT_V1_SECRET_API_KEY.");
}

export async function resolveRevenueCatContext() {
  const secretKey = requireRevenueCatSecretKey();
  const projectId = requireEnvValue("REVENUECAT_PROJECT_ID");
  const sdkKey = requireEnvValue("REVENUECAT_FLUTTER_IOS_SDK_KEY");

  if (sdkKey !== expectedFlutterSdkKey) {
    throw new Error("REVENUECAT_FLUTTER_IOS_SDK_KEY does not match the expected MORT public/test SDK key.");
  }

  const api = new RevenueCatApi(secretKey.value);
  let appId = envValue("REVENUECAT_APP_ID");
  const apps = await api.listAll(`/projects/${encodeURIComponent(projectId)}/apps`);
  let app = appId ? apps.find((item) => item.id === appId) : null;

  if (!app) {
    for (const candidate of apps) {
      const keys = await api.listAll(
        `/projects/${encodeURIComponent(projectId)}/apps/${encodeURIComponent(candidate.id)}/public_api_keys`,
      );
      if (keys.some((key) => key.key === sdkKey)) {
        app = candidate;
        appId = candidate.id;
        break;
      }
    }
  }

  if (!app || !appId) {
    throw new Error("REVENUECAT_APP_ID could not be discovered from the project apps and public SDK key.");
  }

  return { api, projectId, appId, app, sdkKey, secretEnvName: secretKey.envName };
}

export async function getRevenueCatInventory(api, projectId, appId) {
  const productItems = await api.listAll(`/projects/${encodeURIComponent(projectId)}/products?app_id=${encodeURIComponent(appId)}`);
  const entitlementItems = await api.listAll(`/projects/${encodeURIComponent(projectId)}/entitlements`);
  const offeringItems = await api.listAll(`/projects/${encodeURIComponent(projectId)}/offerings?expand=items.package&expand=items.package.product`);
  const paywallItems = await api.listAll(`/projects/${encodeURIComponent(projectId)}/paywalls`);
  const webhookItems = await api.listAll(`/projects/${encodeURIComponent(projectId)}/integrations/webhooks`);
  return { products: productItems, entitlements: entitlementItems, offerings: offeringItems, paywalls: paywallItems, webhooks: webhookItems };
}

export function findByLookup(items, lookupKey) {
  return items.find((item) => item.lookup_key === lookupKey);
}

export function findProductByStoreIdentifier(items, storeIdentifier) {
  return items.find((item) => item.store_identifier === storeIdentifier);
}

export function productCreateBody(catalogProduct, appId, appType) {
  const body = {
    store_identifier: catalogProduct.storeIdentifier,
    app_id: appId,
    type: catalogProduct.type,
    display_name: catalogProduct.displayName,
  };
  if (appType === "test_store") {
    body.title = catalogProduct.displayName;
    if (catalogProduct.type === "subscription" && catalogProduct.subscriptionDuration) {
      body.subscription = { duration: catalogProduct.subscriptionDuration };
    }
  }
  return body;
}

export function markdownTable(headers, rows) {
  const escape = (value) => String(value ?? "").replace(/\|/g, "\\|").replace(/\r?\n/g, "<br>");
  return [
    `| ${headers.map(escape).join(" | ")} |`,
    `| ${headers.map(() => "---").join(" | ")} |`,
    ...rows.map((row) => `| ${row.map(escape).join(" | ")} |`),
  ].join("\n");
}

export function listFiles(root, excludedFragments = []) {
  if (!existsSync(root)) return [];
  const entries = readdirSync(root);
  return entries.flatMap((entry) => {
    const full = join(root, entry);
    if (excludedFragments.some((fragment) => full.includes(fragment))) return [];
    const stats = statSync(full);
    if (stats.isDirectory()) return listFiles(full, excludedFragments);
    return [full];
  });
}

export function readEnvLocalPublicSupabaseUrl() {
  const envLocalPath = join(repoRoot, ".env.local");
  if (!existsSync(envLocalPath)) return "";
  const match = readFileSync(envLocalPath, "utf8").match(/^EXPO_PUBLIC_SUPABASE_URL=(.+)$/m);
  return match?.[1]?.trim() ?? "";
}

export function sanitizeRevenueCatError(error) {
  if (error instanceof RevenueCatApiError) {
    return `${error.status} ${error.body?.type ?? "error"} ${error.body?.message ?? ""}`.trim();
  }
  return error instanceof Error ? error.message : String(error);
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text.slice(0, 500) };
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
