import { randomBytes } from "node:crypto";
import {
  RevenueCatApi,
  requireRevenueCatSecretKey,
  sanitizeRevenueCatError,
} from "./revenuecat-common.mjs";

const projectId = "projc545d148";
const paywallId = "pw823c05a67ee049a4";
const paywallPath = `/projects/${projectId}/paywalls/${paywallId}`;
const expectedPackages = ["$rc_weekly", "$rc_monthly", "$rc_annual", "$rc_lifetime"];
const apply = process.argv.includes("--apply");
const publish = process.argv.includes("--publish");
if (publish && !apply) throw new Error("--publish requires --apply");

const api = new RevenueCatApi(requireRevenueCatSecretKey().value);
const paywall = await api.request(`${paywallPath}?expand=components`);
if (paywall.offering_id !== "ofrng464218bd1d") throw new Error("Unexpected paywall offering.");
if (paywall.published_at && !process.argv.includes("--update-published")) {
  throw new Error("Paywall is already published; pass --update-published to edit its draft.");
}

const draft = paywall.components?.draft;
if (!draft?.components_config?.base?.sticky_footer?.stack) {
  throw new Error("RevenueCat paywall draft does not match the expected component layout.");
}
const config = structuredClone(draft.components_config);
const strings = { ...draft.components_localizations.en_US };
const base = config.base;
const title = base.stack.components.find((item) => item.name === "Title content");
const features = base.stack.components.find((item) => item.name === "Feature list");
const footer = base.sticky_footer.stack.components;
const packageStack = footer.find((item) => item.name === "Package stack");
if (!title || !features || !packageStack) throw new Error("Expected paywall sections are missing.");

// The generated shell uses Cat.io copy and artwork. Keep its native purchase,
// restore, legal and close controls while replacing its content with MORT copy.
title.components = title.components.filter((item) => item.type !== "image");
features.components = features.components.slice(0, 3);
const copy = {
  iuFGR2yPjh: "MORT Pro",
  tZ34z5szEZ: "Optional style and convenience. Core work and safety stay free.",
  pdF3swOZOC: "Ad-free eligible browsing",
  "1rbBizXZ6a": "Hide supported display ads while Pro is active.",
  Tb96zGkKSL: "Profile style",
  alkrIMXbE9: "Personalize your profile appearance.",
  wNFWVHWeDA: "Personal analytics",
  "2V3GETNpev": "See your own activity insights.",
  FB8Ij4dWgS: "Continue with selected plan",
  "8zj3qBRQrX": "Annual",
  hmS8R9Jw92: "Monthly",
  x4PDxteoED: "{{ product.price_per_period_abbreviated }}",
  "qINkEZb-Wo": "{{ product.price_per_period_abbreviated }}",
  rM0PH_FQw4: "Renews at {{ product.price_per_period_abbreviated }} until canceled.",
  "H-ro-nGg8k": "Renews at {{ product.price_per_period_abbreviated }} until canceled.",
  VFL_T8xgne: "https://mort-legal.vercel.app/terms/",
  "0B1RuOuUwn": "https://mort-legal.vercel.app/privacy/",
};
Object.assign(strings, copy);

function walk(value, visit) {
  if (!value || typeof value !== "object") return;
  visit(value);
  for (const child of Object.values(value)) walk(child, visit);
}

// Remove template trial/discount rules. Google Play Console has not supplied a
// verified introductory offer for this release.
walk(config, (node) => {
  if (Array.isArray(node.overrides)) {
    node.overrides = node.overrides.filter((rule) =>
      !rule.conditions?.some((condition) => condition.type === "intro_offer"));
  }
  if (node.type === "package" && node.stack) node.stack.badge = null;
});

const packages = new Map(packageStack.components.map((node) => [node.package_id, node]));
const monthly = packages.get("$rc_monthly");
const annual = packages.get("$rc_annual");
if (!monthly || !annual) throw new Error("Template monthly and annual packages are missing.");

function newId() {
  return randomBytes(8).toString("base64url").slice(0, 10);
}

function clonePackage(source, packageId, label, description) {
  const result = structuredClone(source);
  const sourceLids = new Map();
  walk(result, (node) => {
    if (typeof node.id === "string") node.id = newId();
    if (typeof node.text_lid === "string") {
      if (!sourceLids.has(node.text_lid)) sourceLids.set(node.text_lid, newId());
      node.text_lid = sourceLids.get(node.text_lid);
    }
  });
  result.package_id = packageId;
  result.is_selected_by_default = false;
  result.stack.badge = null;
  const details = result.stack.components[0].components[0].components;
  const descriptionText = result.stack.components[1].components[0];
  strings[details[0].text_lid] = label;
  strings[details[1].text_lid] = "{{ product.price_per_period_abbreviated }}";
  strings[descriptionText.text_lid] = description;
  return result;
}

if (!packages.has("$rc_weekly")) {
  packages.set("$rc_weekly", clonePackage(monthly, "$rc_weekly", "Weekly",
    "Renews at {{ product.price_per_period_abbreviated }} until canceled."));
}
if (!packages.has("$rc_lifetime")) {
  packages.set("$rc_lifetime", clonePackage(monthly, "$rc_lifetime", "Lifetime",
    "One-time purchase. No renewal."));
}
packageStack.components = expectedPackages.map((id) => packages.get(id));
packageStack.dimension = { ...packageStack.dimension, type: "vertical", alignment: "leading", distribution: "start" };

const dark = "#0B0D14FF";
const card = "#171B24FF";
const silver = "#E7EBF1FF";
const muted = "#AEB7C4FF";
const accent = "#B7CBE7FF";
const border = "#5E697AFF";
walk(config, (node) => {
  if (node.type !== "hex" || typeof node.value !== "string") return;
  const original = node.value.toLowerCase();
  const palette = {
    "#ffffffff": silver,
    "#ffffff": silver,
    "#000000": silver,
    "#f2f2f7ff": card,
    "#af52deff": accent,
    "#af52de": accent,
    "#bc4ae6ff": accent,
    "#bd4be526": "#B7CBE726",
    "#c6c6c8ff": border,
    "#3c334399": muted,
    "#8e8e93ff": muted,
    "#e5e5eaff": card,
    "#78788014": "#5E697A14",
  };
  if (palette[original]) node.value = palette[original];
});
base.background = { type: "color", value: { light: { type: "hex", value: dark } } };
const button = footer.find((item) => item.type === "purchase_button");
if (!button) throw new Error("Purchase button is missing.");
button.stack.background.value.light.value = accent;
button.stack.components[0].color.light.value = dark;

const usedLids = new Set();
walk(config, (node) => {
  if (typeof node.text_lid === "string") usedLids.add(node.text_lid);
  if (typeof node.url_lid === "string") usedLids.add(node.url_lid);
});
const localizations = { en_US: Object.fromEntries(Object.entries(strings).filter(([lid]) => usedLids.has(lid))) };
for (const lid of usedLids) {
  if (!localizations.en_US[lid]) throw new Error(`Missing paywall localization ${lid}.`);
}
const serialized = JSON.stringify({ config, localizations });
if (/cat\.io|feline|purrroduct|free trial|revenuecat\.com\/privacy/i.test(serialized)) {
  throw new Error("Template copy remains in paywall draft.");
}
const packageIds = packageStack.components.map((node) => node.package_id);
if (JSON.stringify(packageIds) !== JSON.stringify(expectedPackages)) {
  throw new Error("Paywall package selector is incomplete.");
}
console.log(`[configure-mort-paywall] Draft verified: ${packageIds.join(", ")}; ${usedLids.size} localized values.`);
if (!apply) {
  console.log("[configure-mort-paywall] Dry run only. Use --apply --publish to update and serve the paywall.");
}

if (apply) try {
  const updated = await api.request(paywallPath, {
    method: "PATCH",
    body: {
      revision: paywall.revision,
      name: "MORT Pro",
      components_config: config,
      components_localizations: localizations,
      default_locale: "en_US",
    },
  });
  console.log(`[configure-mort-paywall] Draft saved at revision ${updated.revision}.`);
  if (publish) {
    const published = await api.request(`${paywallPath}/actions/publish`, { method: "POST", body: {} });
    if (!published.published_at) throw new Error("RevenueCat did not confirm a published timestamp.");
    console.log(`[configure-mort-paywall] Published at ${new Date(published.published_at).toISOString()}.`);
  }
} catch (error) {
  throw new Error(sanitizeRevenueCatError(error));
}
