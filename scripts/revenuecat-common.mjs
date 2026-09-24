import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const revenueCatBaseUrl = "https://api.revenuecat.com/v2";
export const mortSupabaseProjectRef = "rakjydmgwwgtdislanbt";
export const mortSupabaseUrl = `https://${mortSupabaseProjectRef}.supabase.co`;
export const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

export const products = [
  product("mort_pro:weekly", "MORT Pro Weekly", "subscription", "Store price", "P1W"),
  product("mort_pro:monthly", "MORT Pro Monthly", "subscription", "Store price", "P1M"),
  product("mort_pro:annual", "MORT Pro Annual", "subscription", "Store price", "P1Y"),
  product("lifetime", "MORT Pro Lifetime", "non_consumable", "Store price"),
];

export const entitlements = [
  entitlement("mort_pro", "MORT Pro"),
];

export const entitlementProductMap = {
  mort_pro: ["mort_pro:weekly", "mort_pro:monthly", "mort_pro:annual", "lifetime"],
};

export const offerings = [
  offering("default", "MORT Pro", true, [
    pkg("weekly", "MORT Pro Weekly", "mort_pro:weekly", 1),
    pkg("monthly", "MORT Pro Monthly", "mort_pro:monthly", 2),
    pkg("annual", "MORT Pro Annual", "mort_pro:annual", 3),
    pkg("lifetime", "MORT Pro Lifetime", "lifetime", 4),
  ]),
];

export const paywallCopy = {
  default: {
    header: "MORT Pro",
    subheader: "Optional style and convenience. Core work and safety remain free.",
    primaryCta: "Upgrade to MORT Pro",
    secondaryCta: "Keep using free",
    perks: [
      "Ad-free browsing on eligible screens",
      "Profile style",
      "Personal analytics",
    ],
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
  const v2SecretKey = envValue("REVENUECAT_V2_SECRET_API_KEY");
  if (v2SecretKey) return { value: v2SecretKey, envName: "REVENUECAT_V2_SECRET_API_KEY" };
  throw new Error("Set a RevenueCat V2 secret API key for the matching project.");
}

export async function resolveRevenueCatContext() {
  const secretKey = requireRevenueCatSecretKey();
  const projectId = requireEnvValue("REVENUECAT_PROJECT_ID");
  const targetStore = envValue("REVENUECAT_TARGET_STORE") || "test_store";
  if (targetStore !== "test_store" && targetStore !== "play_store") {
    throw new Error("REVENUECAT_TARGET_STORE must be test_store or play_store.");
  }
  const sdkKey = targetStore === "play_store"
    ? requireEnvValue("REVENUECAT_ANDROID_API_KEY")
    : requireEnvValue("REVENUECAT_TEST_STORE_API_KEY");
  if (!sdkKey.startsWith(targetStore === "play_store" ? "goog_" : "test_")) {
    throw new Error("RevenueCat public SDK key does not match target store.");
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

  if (!app || !appId || app.type !== targetStore) {
    throw new Error("REVENUECAT_APP_ID could not be discovered from the project apps and public SDK key.");
  }
  const publicKeys = await api.listAll(
    `/projects/${encodeURIComponent(projectId)}/apps/${encodeURIComponent(appId)}/public_api_keys`,
  );
  if (!publicKeys.some((key) => key.key === sdkKey)) {
    throw new Error("RevenueCat public SDK key does not belong to the selected app.");
  }
  if (targetStore === "play_store" &&
      (app.name !== "Mort (Play Store)" || app.custom_url_scheme !== "rc-8eaa6ee77f")) {
    throw new Error("RevenueCat Play app identity or custom URL scheme does not match MORT.");
  }

  return { api, projectId, appId, app, sdkKey, targetStore, secretEnvName: secretKey.envName };
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
