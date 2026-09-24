import {
  entitlementProductMap,
  entitlements,
  findByLookup,
  findProductByStoreIdentifier,
  getRevenueCatInventory,
  offerings,
  products,
  resolveRevenueCatContext,
  sanitizeRevenueCatError,
} from "./revenuecat-common.mjs";

function fail(message) {
  console.error(`[qa-revenuecat-api] FAIL: ${message}`);
  process.exit(1);
}

function pass(message) {
  console.log(`[qa-revenuecat-api] PASS: ${message}`);
}

const { api, projectId, appId, app, targetStore } = await resolveRevenueCatContext();
pass("RevenueCat API key works and app was resolved.");
pass(`Target store: ${targetStore}`);
pass(`Project resolved: ${projectId}`);
pass(`App resolved: ${appId} (${app.type})`);

let inventory;
try {
  inventory = await getRevenueCatInventory(api, projectId, appId);
} catch (error) {
  fail(`RevenueCat catalog QA blocked: ${sanitizeRevenueCatError(error)}`);
}
const productByStoreId = new Map(inventory.products.map((item) => [item.store_identifier, item]));
const entitlementByLookup = new Map(inventory.entitlements.map((item) => [item.lookup_key, item]));
const offeringByLookup = new Map(inventory.offerings.map((item) => [item.lookup_key, item]));

for (const item of products) {
  const found = findProductByStoreIdentifier(inventory.products, item.storeIdentifier);
  if (!found) fail(`Missing RevenueCat product ${item.storeIdentifier}.`);
  pass(`Product exists: ${item.storeIdentifier}`);
}

for (const item of entitlements) {
  const found = findByLookup(inventory.entitlements, item.lookupKey);
  if (!found) fail(`Missing RevenueCat entitlement ${item.lookupKey}.`);
  pass(`Entitlement exists: ${item.lookupKey}`);
}

for (const [entitlementKey, productKeys] of Object.entries(entitlementProductMap)) {
  const entitlement = entitlementByLookup.get(entitlementKey);
  if (!entitlement) fail(`Missing entitlement for attachment check: ${entitlementKey}.`);
  const attached = await api.listAll(
    `/projects/${encodeURIComponent(projectId)}/entitlements/${encodeURIComponent(entitlement.id)}/products`,
  );
  const attachedIds = new Set(attached.map((item) => item.id));
  for (const productKey of productKeys) {
    const product = productByStoreId.get(productKey);
    if (!product) fail(`Missing product for attachment check: ${productKey}.`);
    if (!attachedIds.has(product.id)) fail(`Product ${productKey} is not attached to entitlement ${entitlementKey}.`);
  }
  pass(`Entitlement attachments verified: ${entitlementKey}`);
}

for (const item of offerings) {
  const offering = offeringByLookup.get(item.lookupKey);
  if (!offering) fail(`Missing offering ${item.lookupKey}.`);
  pass(`Offering exists: ${item.lookupKey}`);
  const packageItems = await api.listAll(
    `/projects/${encodeURIComponent(projectId)}/offerings/${encodeURIComponent(offering.id)}/packages`,
  );
  const packageByLookup = new Map(packageItems.map((pkg) => [pkg.lookup_key, pkg]));
  if (item.lookupKey === "default") {
    const expected = new Set(["$rc_weekly", "$rc_monthly", "$rc_annual", "$rc_lifetime"]);
    if (packageItems.length !== expected.size ||
      packageItems.some((pkg) => !expected.has(pkg.lookup_key))) {
      fail("Default Offering must contain only weekly, monthly, annual, and lifetime package types.");
    }
    if (!offering.is_current) fail("MORT Pro default Offering is not current.");
  }
  for (const expectedPackage of item.packages) {
    const foundPackage = packageByLookup.get(expectedPackage.lookupKey);
    if (!foundPackage) fail(`Missing package ${item.lookupKey}/${expectedPackage.lookupKey}.`);
    const product = productByStoreId.get(expectedPackage.productIdentifier);
    if (!product) fail(`Missing package product ${expectedPackage.productIdentifier}.`);
    const attachedProducts = await api.listAll(
      `/projects/${encodeURIComponent(projectId)}/packages/${encodeURIComponent(foundPackage.id)}/products`,
    );
    if (!attachedProducts.some((attached) => attached.product?.id === product.id)) {
      fail(`Package ${item.lookupKey}/${expectedPackage.lookupKey} is not attached to ${expectedPackage.productIdentifier}.`);
    }
  }
  pass(`Packages verified: ${item.lookupKey}`);
}

for (const item of offerings) {
  const offering = offeringByLookup.get(item.lookupKey);
  if (!offering) continue;
  const paywallSummary = inventory.paywalls.find((candidate) =>
    candidate.id === offering.paywall_id || candidate.offering_id === offering.id);
  if (!paywallSummary) {
    fail(`Missing published paywall for offering ${item.lookupKey}.`);
  }
  const paywall = await api.request(
    `/projects/${encodeURIComponent(projectId)}/paywalls/${encodeURIComponent(paywallSummary.id)}?expand=components`,
  );
  if (!paywall.published_at || !paywall.components?.published) {
    fail(`Paywall for ${item.lookupKey} is not published.`);
  }
  const published = paywall.components.published;
  const config = published.components_config?.base;
  const packageStack = config?.sticky_footer?.stack?.components?.find((component) =>
    component.name === "Package stack");
  const selectedPackages = packageStack?.components?.map((component) => component.package_id);
  const requiredPackages = ["$rc_weekly", "$rc_monthly", "$rc_annual", "$rc_lifetime"];
  if (JSON.stringify(selectedPackages) !== JSON.stringify(requiredPackages)) {
    fail(`Published paywall for ${item.lookupKey} does not show all four MORT plans.`);
  }
  const publishedStrings = JSON.stringify(published.components_localizations ?? {});
  if (!publishedStrings.includes("MORT Pro") ||
      !publishedStrings.includes("Core work and safety stay free") ||
      /Cat\.io|feline|purrroduct|free trial|revenuecat\.com\/terms/i.test(publishedStrings)) {
    fail(`Published paywall for ${item.lookupKey} has incorrect MORT copy or template content.`);
  }
  pass(`Published MORT paywall verified: ${item.lookupKey} (${requiredPackages.join(", ")})`);
}

const webhook = inventory.webhooks.find((item) =>
  item.url?.includes("/functions/v1/revenuecat-webhook") && item.app_id === appId);
if (!webhook) fail("RevenueCat webhook integration for Supabase function is missing.");
pass("RevenueCat webhook integration exists.");

console.log("[qa-revenuecat-api] RevenueCat API QA passed.");
