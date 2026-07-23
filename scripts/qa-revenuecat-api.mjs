import {
  existsSync,
  readFileSync,
} from "node:fs";
import {
  entitlementProductMap,
  entitlements,
  expectedFlutterSdkKey,
  findByLookup,
  findProductByStoreIdentifier,
  getRevenueCatInventory,
  offerings,
  products,
  repoRoot,
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

const { api, projectId, appId, app, sdkKey } = await resolveRevenueCatContext();
if (sdkKey !== expectedFlutterSdkKey) fail("Flutter SDK key does not match expected public/test key.");
pass("RevenueCat API key works and app was resolved.");
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

const paywallOfferingIds = new Set(inventory.paywalls.map((item) => item.offering_id).filter(Boolean));
const manualPaywallDocPath = `${repoRoot}\\docs\\REVENUECAT_PAYWALL_BUILDER_PROMPTS.md`;
const manualPaywallDoc = existsSync(manualPaywallDocPath) ? readFileSync(manualPaywallDocPath, "utf8") : "";
for (const item of offerings) {
  const offering = offeringByLookup.get(item.lookupKey);
  if (!offering) continue;
  if (!offering.paywall_id && !paywallOfferingIds.has(offering.id)) {
    if (!manualPaywallDoc.includes(`## ${item.lookupKey}`)) {
      fail(`Missing paywall shell for offering ${item.lookupKey}, and manual dashboard steps are not documented.`);
    }
    pass(`Paywall manual dashboard steps documented: ${item.lookupKey}`);
    continue;
  }
  pass(`Paywall exists or is attached: ${item.lookupKey}`);
}

const webhook = inventory.webhooks.find((item) => item.url?.includes("/functions/v1/revenuecat-webhook"));
if (!webhook) fail("RevenueCat webhook integration for Supabase function is missing.");
pass("RevenueCat webhook integration exists.");

console.log("[qa-revenuecat-api] RevenueCat API QA passed.");
