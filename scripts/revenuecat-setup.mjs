import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  entitlementProductMap,
  entitlements,
  expectedFlutterSdkKey,
  findByLookup,
  findProductByStoreIdentifier,
  freeForeverFeatures,
  markdownTable,
  mortSupabaseUrl,
  offerings,
  paywallCopy,
  productCreateBody,
  products,
  readEnvLocalPublicSupabaseUrl,
  repoRoot,
  resolveRevenueCatContext,
  sanitizeRevenueCatError,
  webhookEventTypes,
  envValue,
} from "./revenuecat-common.mjs";

const verifyOnly = process.argv.includes("--verify-only");
const report = {
  startedAt: new Date().toISOString(),
  verifyOnly,
  context: {},
  products: [],
  entitlements: [],
  attachments: [],
  offerings: [],
  packages: [],
  packageAttachments: [],
  paywalls: [],
  webhook: [],
  manualActions: [],
  errors: [],
};

function log(message) {
  console.log(`[revenuecat-setup] ${message}`);
}

function statusLine(items, key = "status") {
  return items.reduce((counts, item) => {
    counts[item[key]] = (counts[item[key]] ?? 0) + 1;
    return counts;
  }, {});
}

try {
  const context = await resolveRevenueCatContext();
  const { api, projectId, appId, app } = context;
  const envLocalSupabaseUrl = readEnvLocalPublicSupabaseUrl();
  const webhookAuthHeader = envValue("REVENUECAT_WEBHOOK_AUTH_HEADER");

  report.context = {
    projectId,
    appId,
    appType: app.type,
    appName: app.name ?? "(unnamed)",
    flutterSdkKeyMatchesExpected: context.sdkKey === expectedFlutterSdkKey,
    secretEnvName: context.secretEnvName,
    envLocalSupabaseUrl,
    webhookAuthHeaderVisible: Boolean(webhookAuthHeader),
  };

  log(`RevenueCat project/app resolved: project=${projectId}, app=${appId}, type=${app.type}`);

  const inventory = await loadSetupInventory(api, projectId, appId);
  const productByStoreId = new Map(inventory.products.map((item) => [item.store_identifier, item]));
  const entitlementByLookup = new Map(inventory.entitlements.map((item) => [item.lookup_key, item]));
  const offeringByLookup = new Map(inventory.offerings.map((item) => [item.lookup_key, item]));

  if (inventory.permissions.products) {
    await ensureProducts(api, projectId, appId, app.type, productByStoreId);
  } else {
    markCatalogSkipped(report.products, products, "storeIdentifier", "permission_missing");
  }

  if (inventory.permissions.entitlements) {
    await ensureEntitlements(api, projectId, entitlementByLookup);
  } else {
    markCatalogSkipped(report.entitlements, entitlements, "lookupKey", "permission_missing");
  }

  if (inventory.permissions.products && inventory.permissions.entitlements) {
    await ensureEntitlementAttachments(api, projectId, productByStoreId, entitlementByLookup);
  } else {
    report.attachments.push({ entitlement: "all", status: "skipped_permission_missing" });
  }

  if (inventory.permissions.offerings && inventory.permissions.products) {
    await ensureOfferingsAndPackages(api, projectId, productByStoreId, offeringByLookup);
  } else {
    markCatalogSkipped(report.offerings, offerings, "lookupKey", "permission_missing");
    report.packages.push({ offering: "all", package: "all", status: "skipped_permission_missing" });
    report.packageAttachments.push({ offering: "all", package: "all", product: "all", status: "skipped_permission_missing" });
  }

  if (inventory.permissions.paywalls && inventory.permissions.offerings) {
    await ensurePaywalls(api, projectId, offeringByLookup);
  } else {
    markCatalogSkipped(report.paywalls, offerings, "lookupKey", "permission_missing", "offering");
  }

  await ensureWebhook(api, projectId, appId, webhookAuthHeader, envLocalSupabaseUrl);

  writeReports();
  log(`Products: ${JSON.stringify(statusLine(report.products))}`);
  log(`Entitlements: ${JSON.stringify(statusLine(report.entitlements))}`);
  log(`Offerings: ${JSON.stringify(statusLine(report.offerings))}`);
  log(`Packages: ${JSON.stringify(statusLine(report.packages))}`);
  log(`Paywalls: ${JSON.stringify(statusLine(report.paywalls))}`);
  log(`Webhook: ${JSON.stringify(statusLine(report.webhook))}`);
  if (report.errors.length > 0) {
    log(`Completed with ${report.errors.length} non-secret API/setup error(s). See docs/REVENUECAT_DASHBOARD_SETUP_REPORT.md.`);
    process.exitCode = 1;
  }
} catch (error) {
  report.errors.push({ scope: "fatal", message: sanitizeRevenueCatError(error) });
  writeReports();
  console.error(`[revenuecat-setup] ${sanitizeRevenueCatError(error)}`);
  process.exit(1);
}

async function ensureProducts(api, projectId, appId, appType, productByStoreId) {
  for (const catalogProduct of products) {
    const existing = productByStoreId.get(catalogProduct.storeIdentifier);
    if (existing) {
      report.products.push({ storeIdentifier: catalogProduct.storeIdentifier, status: "already_exists", id: existing.id, type: existing.type });
      continue;
    }

    if (verifyOnly) {
      report.products.push({ storeIdentifier: catalogProduct.storeIdentifier, status: "missing" });
      continue;
    }

    try {
      const created = await api.request(`/projects/${encodeURIComponent(projectId)}/products`, {
        method: "POST",
        body: productCreateBody(catalogProduct, appId, appType),
      });
      productByStoreId.set(catalogProduct.storeIdentifier, created);
      report.products.push({ storeIdentifier: catalogProduct.storeIdentifier, status: "created", id: created.id, type: created.type });
    } catch (error) {
      const message = sanitizeRevenueCatError(error);
      report.products.push({ storeIdentifier: catalogProduct.storeIdentifier, status: "manual_or_failed", error: message });
      report.manualActions.push(`Create or connect RevenueCat product ${catalogProduct.storeIdentifier}: ${message}`);
      report.errors.push({ scope: "product", id: catalogProduct.storeIdentifier, message });
    }
  }
}

async function loadSetupInventory(api, projectId, appId) {
  const permissions = {
    products: true,
    entitlements: true,
    offerings: true,
    paywalls: true,
  };
  const inventory = {
    products: [],
    entitlements: [],
    offerings: [],
    paywalls: [],
    permissions,
  };

  inventory.products = await safeList(
    "products",
    `/projects/${encodeURIComponent(projectId)}/products?app_id=${encodeURIComponent(appId)}`,
    "project_configuration:products:read",
    permissions,
  );
  inventory.entitlements = await safeList(
    "entitlements",
    `/projects/${encodeURIComponent(projectId)}/entitlements`,
    "project_configuration:entitlements:read",
    permissions,
  );
  inventory.offerings = await safeList(
    "offerings",
    `/projects/${encodeURIComponent(projectId)}/offerings`,
    "project_configuration:offerings:read",
    permissions,
  );
  inventory.paywalls = await safeList(
    "paywalls",
    `/projects/${encodeURIComponent(projectId)}/paywalls`,
    "project_configuration:offerings:read",
    permissions,
  );
  return inventory;
}

async function safeList(label, path, permission, permissions) {
  try {
    return await reportApiList(path);
  } catch (error) {
    const message = sanitizeRevenueCatError(error);
    permissions[label] = false;
    report.errors.push({ scope: label, message });
    report.manualActions.push(`RevenueCat API key needs ${permission} to verify/setup ${label}: ${message}`);
    return [];
  }
}

async function reportApiList(path) {
  const context = await resolveRevenueCatContext();
  return context.api.listAll(path);
}

function markCatalogSkipped(target, catalog, key, status, outputKey = key) {
  for (const item of catalog) {
    target.push({ [outputKey]: item[key], status });
  }
}

async function ensureEntitlements(api, projectId, entitlementByLookup) {
  for (const catalogEntitlement of entitlements) {
    const existing = entitlementByLookup.get(catalogEntitlement.lookupKey);
    if (existing) {
      report.entitlements.push({ lookupKey: catalogEntitlement.lookupKey, status: "already_exists", id: existing.id });
      continue;
    }

    if (verifyOnly) {
      report.entitlements.push({ lookupKey: catalogEntitlement.lookupKey, status: "missing" });
      continue;
    }

    try {
      const created = await api.request(`/projects/${encodeURIComponent(projectId)}/entitlements`, {
        method: "POST",
        body: { lookup_key: catalogEntitlement.lookupKey, display_name: catalogEntitlement.displayName },
      });
      entitlementByLookup.set(catalogEntitlement.lookupKey, created);
      report.entitlements.push({ lookupKey: catalogEntitlement.lookupKey, status: "created", id: created.id });
    } catch (error) {
      const message = sanitizeRevenueCatError(error);
      report.entitlements.push({ lookupKey: catalogEntitlement.lookupKey, status: "manual_or_failed", error: message });
      report.errors.push({ scope: "entitlement", id: catalogEntitlement.lookupKey, message });
    }
  }
}

async function ensureEntitlementAttachments(api, projectId, productByStoreId, entitlementByLookup) {
  for (const [entitlementLookup, storeIdentifiers] of Object.entries(entitlementProductMap)) {
    const entitlement = entitlementByLookup.get(entitlementLookup);
    if (!entitlement) {
      report.attachments.push({ entitlement: entitlementLookup, status: "skipped_missing_entitlement" });
      continue;
    }

    const desiredProducts = storeIdentifiers
      .map((storeIdentifier) => productByStoreId.get(storeIdentifier))
      .filter(Boolean);
    const missingProducts = storeIdentifiers.filter((storeIdentifier) => !productByStoreId.get(storeIdentifier));
    if (missingProducts.length > 0) {
      report.attachments.push({ entitlement: entitlementLookup, status: "skipped_missing_products", missingProducts: missingProducts.join(", ") });
      continue;
    }

    const existing = await api.listAll(
      `/projects/${encodeURIComponent(projectId)}/entitlements/${encodeURIComponent(entitlement.id)}/products`,
    );
    const attachedIds = new Set(existing.map((item) => item.id));
    const missingIds = desiredProducts.filter((item) => !attachedIds.has(item.id)).map((item) => item.id);

    if (missingIds.length === 0) {
      report.attachments.push({ entitlement: entitlementLookup, status: "already_attached", count: desiredProducts.length });
      continue;
    }

    if (verifyOnly) {
      report.attachments.push({ entitlement: entitlementLookup, status: "missing_attachments", count: missingIds.length });
      continue;
    }

    try {
      await api.request(
        `/projects/${encodeURIComponent(projectId)}/entitlements/${encodeURIComponent(entitlement.id)}/actions/attach_products`,
        { method: "POST", body: { product_ids: missingIds } },
      );
      report.attachments.push({ entitlement: entitlementLookup, status: "attached", count: missingIds.length });
    } catch (error) {
      const message = sanitizeRevenueCatError(error);
      report.attachments.push({ entitlement: entitlementLookup, status: "manual_or_failed", error: message });
      report.errors.push({ scope: "entitlement_attachment", id: entitlementLookup, message });
    }
  }
}

async function ensureOfferingsAndPackages(api, projectId, productByStoreId, offeringByLookup) {
  for (const catalogOffering of offerings) {
    let offering = offeringByLookup.get(catalogOffering.lookupKey);
    if (!offering && !verifyOnly) {
      try {
        offering = await api.request(`/projects/${encodeURIComponent(projectId)}/offerings`, {
          method: "POST",
          body: {
            lookup_key: catalogOffering.lookupKey,
            display_name: catalogOffering.displayName,
            metadata: {
              mort_safety_copy: "Safety tools, basic applying, report, block, and Safety Ping stay free.",
            },
          },
        });
        offeringByLookup.set(catalogOffering.lookupKey, offering);
        report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "created", id: offering.id });
      } catch (error) {
        const message = sanitizeRevenueCatError(error);
        report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "manual_or_failed", error: message });
        report.errors.push({ scope: "offering", id: catalogOffering.lookupKey, message });
        continue;
      }
    } else if (offering) {
      report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "already_exists", id: offering.id, isCurrent: offering.is_current });
    } else {
      report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "missing" });
      continue;
    }

    if (!verifyOnly && catalogOffering.isCurrent && offering && !offering.is_current) {
      try {
        offering = await api.request(`/projects/${encodeURIComponent(projectId)}/offerings/${encodeURIComponent(offering.id)}`, {
          method: "POST",
          body: { is_current: true, display_name: catalogOffering.displayName },
        });
        offeringByLookup.set(catalogOffering.lookupKey, offering);
        report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "marked_current", id: offering.id });
      } catch (error) {
        const message = sanitizeRevenueCatError(error);
        report.offerings.push({ lookupKey: catalogOffering.lookupKey, status: "current_update_failed", error: message });
        report.errors.push({ scope: "offering_current", id: catalogOffering.lookupKey, message });
      }
    }

    await ensurePackagesForOffering(api, projectId, productByStoreId, catalogOffering, offering);
  }
}

async function ensurePackagesForOffering(api, projectId, productByStoreId, catalogOffering, offering) {
  const existingPackages = await api.listAll(
    `/projects/${encodeURIComponent(projectId)}/offerings/${encodeURIComponent(offering.id)}/packages`,
  );
  const packageByLookup = new Map(existingPackages.map((item) => [item.lookup_key, item]));

  for (const catalogPackage of catalogOffering.packages) {
    let revenueCatPackage = packageByLookup.get(catalogPackage.lookupKey);
    if (!revenueCatPackage && !verifyOnly) {
      try {
        revenueCatPackage = await api.request(
          `/projects/${encodeURIComponent(projectId)}/offerings/${encodeURIComponent(offering.id)}/packages`,
          {
            method: "POST",
            body: {
              lookup_key: catalogPackage.lookupKey,
              display_name: catalogPackage.displayName,
              position: catalogPackage.position,
            },
          },
        );
        report.packages.push({ offering: catalogOffering.lookupKey, package: catalogPackage.lookupKey, status: "created", id: revenueCatPackage.id });
      } catch (error) {
        const message = sanitizeRevenueCatError(error);
        report.packages.push({ offering: catalogOffering.lookupKey, package: catalogPackage.lookupKey, status: "manual_or_failed", error: message });
        report.errors.push({ scope: "package", id: `${catalogOffering.lookupKey}/${catalogPackage.lookupKey}`, message });
        continue;
      }
    } else if (revenueCatPackage) {
      report.packages.push({ offering: catalogOffering.lookupKey, package: catalogPackage.lookupKey, status: "already_exists", id: revenueCatPackage.id });
    } else {
      report.packages.push({ offering: catalogOffering.lookupKey, package: catalogPackage.lookupKey, status: "missing" });
      continue;
    }

    const product = productByStoreId.get(catalogPackage.productIdentifier);
    if (!product) {
      report.packageAttachments.push({
        offering: catalogOffering.lookupKey,
        package: catalogPackage.lookupKey,
        product: catalogPackage.productIdentifier,
        status: "skipped_missing_product",
      });
      continue;
    }

    const attached = await api.listAll(
      `/projects/${encodeURIComponent(projectId)}/packages/${encodeURIComponent(revenueCatPackage.id)}/products`,
    );
    if (attached.some((item) => item.product?.id === product.id)) {
      report.packageAttachments.push({
        offering: catalogOffering.lookupKey,
        package: catalogPackage.lookupKey,
        product: catalogPackage.productIdentifier,
        status: "already_attached",
      });
      continue;
    }

    if (verifyOnly) {
      report.packageAttachments.push({
        offering: catalogOffering.lookupKey,
        package: catalogPackage.lookupKey,
        product: catalogPackage.productIdentifier,
        status: "missing_attachment",
      });
      continue;
    }

    try {
      await api.request(
        `/projects/${encodeURIComponent(projectId)}/packages/${encodeURIComponent(revenueCatPackage.id)}/actions/attach_products`,
        { method: "POST", body: { products: [{ product_id: product.id, eligibility_criteria: "all" }] } },
      );
      report.packageAttachments.push({
        offering: catalogOffering.lookupKey,
        package: catalogPackage.lookupKey,
        product: catalogPackage.productIdentifier,
        status: "attached",
      });
    } catch (error) {
      const message = sanitizeRevenueCatError(error);
      report.packageAttachments.push({
        offering: catalogOffering.lookupKey,
        package: catalogPackage.lookupKey,
        product: catalogPackage.productIdentifier,
        status: "manual_or_failed",
        error: message,
      });
      report.errors.push({ scope: "package_attachment", id: `${catalogOffering.lookupKey}/${catalogPackage.lookupKey}`, message });
    }
  }
}

async function ensurePaywalls(api, projectId, offeringByLookup) {
  const paywalls = await api.listAll(`/projects/${encodeURIComponent(projectId)}/paywalls`);
  const paywallOfferingIds = new Set(paywalls.map((item) => item.offering_id).filter(Boolean));

  for (const catalogOffering of offerings) {
    const offering = offeringByLookup.get(catalogOffering.lookupKey);
    if (!offering) {
      report.paywalls.push({ offering: catalogOffering.lookupKey, status: "skipped_missing_offering" });
      continue;
    }

    if (offering.paywall_id || paywallOfferingIds.has(offering.id)) {
      report.paywalls.push({ offering: catalogOffering.lookupKey, status: "already_exists", paywallId: offering.paywall_id ?? "listed" });
      continue;
    }

    if (verifyOnly) {
      report.paywalls.push({ offering: catalogOffering.lookupKey, status: "missing" });
      continue;
    }

    try {
      const created = await api.request(`/projects/${encodeURIComponent(projectId)}/paywalls`, {
        method: "POST",
        body: {
          offering_id: offering.id,
          automatically_scale_font_size: true,
        },
      });
      report.paywalls.push({ offering: catalogOffering.lookupKey, status: "created_shell", paywallId: created.id });
      report.manualActions.push(`Review and finish the ${catalogOffering.lookupKey} paywall design in RevenueCat Paywalls Builder using docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md.`);
    } catch (error) {
      const message = sanitizeRevenueCatError(error);
      report.paywalls.push({ offering: catalogOffering.lookupKey, status: "manual_or_failed", error: message });
      report.manualActions.push(`Create ${catalogOffering.lookupKey} paywall manually in RevenueCat Paywalls Builder: ${message}`);
      report.errors.push({ scope: "paywall", id: catalogOffering.lookupKey, message });
    }
  }
}

async function ensureWebhook(api, projectId, appId, webhookAuthHeader, envLocalSupabaseUrl) {
  const functionUrl = `${mortSupabaseUrl}/functions/v1/revenuecat-webhook`;
  if (!webhookAuthHeader) {
    report.webhook.push({ status: "manual_secret_missing", url: functionUrl });
    report.manualActions.push("Set REVENUECAT_WEBHOOK_AUTH_HEADER as a Supabase Edge Function secret and pass it to this setup script only when creating/updating the RevenueCat webhook integration.");
    return;
  }

  if (envLocalSupabaseUrl && envLocalSupabaseUrl !== mortSupabaseUrl) {
    report.webhook.push({ status: "skipped_wrong_supabase_url", url: envLocalSupabaseUrl });
    report.errors.push({ scope: "webhook", message: `.env.local points to ${envLocalSupabaseUrl}, expected ${mortSupabaseUrl}` });
    return;
  }

  const webhooks = await api.listAll(`/projects/${encodeURIComponent(projectId)}/integrations/webhooks`);
  const existing = webhooks.find((item) => item.url === functionUrl || item.name === "MORT Supabase RevenueCat Webhook");
  const body = {
    name: "MORT Supabase RevenueCat Webhook",
    url: functionUrl,
    authorization_header: webhookAuthHeader,
    environment: null,
    event_types: webhookEventTypes,
    app_id: appId,
  };

  if (verifyOnly) {
    report.webhook.push({ status: existing ? "already_exists" : "missing", url: functionUrl, id: existing?.id ?? "" });
    return;
  }

  try {
    if (existing) {
      const updated = await api.request(
        `/projects/${encodeURIComponent(projectId)}/integrations/webhooks/${encodeURIComponent(existing.id)}`,
        { method: "POST", body },
      );
      report.webhook.push({ status: "updated", id: updated.id, url: functionUrl, eventCount: webhookEventTypes.length });
    } else {
      const created = await api.request(`/projects/${encodeURIComponent(projectId)}/integrations/webhooks`, {
        method: "POST",
        body,
      });
      report.webhook.push({ status: "created", id: created.id, url: functionUrl, eventCount: webhookEventTypes.length });
    }
  } catch (error) {
    const message = sanitizeRevenueCatError(error);
    report.webhook.push({ status: "manual_or_failed", url: functionUrl, error: message });
    report.errors.push({ scope: "webhook", message });
    report.manualActions.push(`Create or update the RevenueCat webhook manually for ${functionUrl}: ${message}`);
  }
}

function writeReports() {
  const docsDir = join(repoRoot, "docs");
  mkdirSync(docsDir, { recursive: true });
  writeFileSync(join(docsDir, "REVENUECAT_DASHBOARD_SETUP_REPORT.md"), dashboardReport(), "utf8");
  writeFileSync(join(docsDir, "REVENUECAT_PRODUCTS_AND_ENTITLEMENTS.md"), productsReport(), "utf8");
  writeFileSync(join(docsDir, "REVENUECAT_OFFERINGS_AND_PAYWALLS.md"), offeringsReport(), "utf8");
  writeFileSync(join(docsDir, "REVENUECAT_PAYWALL_BUILDER_PROMPTS.md"), paywallPromptReport(), "utf8");
  writeFileSync(join(docsDir, "REVENUECAT_MANUAL_ACTIONS_LEFT.md"), manualActionsReport(), "utf8");
  writeFileSync(join(docsDir, "REVENUECAT_TESTING_PLAN.md"), testingPlanReport(), "utf8");
}

function dashboardReport() {
  return `# RevenueCat Dashboard Setup Report

Generated: ${new Date().toISOString()}

## Context

- RevenueCat project ID: ${report.context.projectId ?? "not resolved"}
- RevenueCat app ID: ${report.context.appId ?? "not resolved"}
- RevenueCat app type: ${report.context.appType ?? "not resolved"}
- Flutter public/test SDK key matched expected value: ${report.context.flutterSdkKeyMatchesExpected ? "yes" : "no"}
- Public SDK key is not used as the RevenueCat secret API key.
- RevenueCat secret API key env source: ${report.context.secretEnvName ?? "not resolved"}.
- RevenueCat secret API key was read from environment only and was not printed or written.
- Webhook authorization header visible to setup script: ${report.context.webhookAuthHeaderVisible ? "yes" : "no"}

## API Result Summary

- Products: ${JSON.stringify(statusLine(report.products))}
- Entitlements: ${JSON.stringify(statusLine(report.entitlements))}
- Product-entitlement attachments: ${JSON.stringify(statusLine(report.attachments))}
- Offerings: ${JSON.stringify(statusLine(report.offerings))}
- Packages: ${JSON.stringify(statusLine(report.packages))}
- Package-product attachments: ${JSON.stringify(statusLine(report.packageAttachments))}
- Paywalls: ${JSON.stringify(statusLine(report.paywalls))}
- Webhook: ${JSON.stringify(statusLine(report.webhook))}

## Errors

${report.errors.length ? report.errors.map((error) => `- ${error.scope}: ${error.id ? `${error.id}: ` : ""}${error.message}`).join("\n") : "- None recorded."}

## Manual Actions

${report.manualActions.length ? report.manualActions.map((item) => `- ${item}`).join("\n") : "- None recorded by the setup script."}

## Notes

- The setup is idempotent and never deletes RevenueCat objects.
- App Store Connect approval, sandbox purchase testing, TestFlight, and legal/privacy/teen-safety review are not completed by this script.
- Paywall shells can be created by API, but final visual/content review remains a RevenueCat dashboard task.
`;
}

function productsReport() {
  return `# RevenueCat Products And Entitlements

Products use RevenueCat/App Store price strings at runtime. Suggested prices below are planning targets only.

${markdownTable(["Product", "Type", "Suggested docs price", "Setup status"], products.map((item) => {
  const status = report.products.find((row) => row.storeIdentifier === item.storeIdentifier)?.status ?? "not run";
  return [item.storeIdentifier, item.type, item.suggestedPrice, status];
}))}

## Entitlements

${markdownTable(["Entitlement", "Display name", "Setup status"], entitlements.map((item) => {
  const status = report.entitlements.find((row) => row.lookupKey === item.lookupKey)?.status ?? "not run";
  return [item.lookupKey, item.displayName, status];
}))}

## Product Attachments

${Object.entries(entitlementProductMap).map(([entitlement, productIds]) => `- ${entitlement}: ${productIds.join(", ")}`).join("\n")}

## Free Forever

${freeForeverFeatures.map((feature) => `- ${feature}`).join("\n")}
`;
}

function offeringsReport() {
  return `# RevenueCat Offerings And Paywalls

## Offerings

${offerings.map((item) => {
  const status = report.offerings.find((row) => row.lookupKey === item.lookupKey)?.status ?? "not run";
  return `### ${item.lookupKey}

- Display name: ${item.displayName}
- Current offering target: ${item.isCurrent ? "yes" : "no"}
- Setup status: ${status}
- Packages: ${item.packages.map((packageItem) => `${packageItem.lookupKey} -> ${packageItem.productIdentifier}`).join(", ")}
`;
}).join("\n")}

## Paywalls

${markdownTable(["Offering", "Status"], offerings.map((item) => {
  const status = report.paywalls.find((row) => row.offering === item.lookupKey)?.status ?? "not run";
  return [item.lookupKey, status];
}))}

RevenueCat paywalls must avoid dark patterns, fake urgency, fake discounts, and any "pay to be safe" copy.

## Manual Paywall Setup

The RevenueCat API returned \`422 parameter_error Paywall validation failed\` for the visual paywall creation attempts. Finish paywall design in the Dashboard:

1. Open RevenueCat Dashboard.
2. Select project \`${report.context.projectId ?? "b2454250"}\`.
3. Open **Paywalls**.
4. Click **Create paywall**.
5. Choose a template, start from scratch, or use AI Editor.
6. Attach the paywall to the matching offering: \`default\`, \`teen_perks\`, \`adult_pro\`, \`guardian_plus\`, \`ad_free\`, \`username_change\`, or \`job_boost\`.
7. Use the matching copy from \`docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md\`.
8. Use RevenueCat/App Store returned package price strings; the pricing numbers in docs are targets, not final app truth.
9. Confirm the copy says free remains useful and safety tools stay free.
10. Save and publish the paywall, then rerun \`node scripts/qa-revenuecat-api.mjs\`.
`;
}

function paywallPromptReport() {
  return `# RevenueCat Paywall Builder Prompts

Use these prompts in RevenueCat Paywalls Builder. Hosted visual paywall creation still needs Dashboard work if the API returns \`422 parameter_error Paywall validation failed\`.

${offerings.map((item) => {
  const copy = paywallCopy[item.lookupKey] ?? paywallCopy.default;
  return `## ${item.lookupKey}

Create a calm, teen-safe MORT paywall for the ${item.lookupKey} offering.

Header: ${copy.header}

Subheader: ${copy.subheader}

Primary CTA: ${copy.primaryCta}

Secondary CTA: ${copy.secondaryCta}

Perks:
${copy.perks.map((perk) => `- ${perk}`).join("\n")}

Required safety copy:
- Safety tools stay free.
- Basic job applying stays free.
- Guardian Mode basics stay free.
- Report, block, and Safety Ping stay free.
- Boosts never bypass safety review.

Rules: no dark patterns, no fake urgency, no fake discounts, no pressure copy, and no "pay to be safe" framing.
`;
}).join("\n")}
`;
}

function manualActionsReport() {
  return `# RevenueCat Manual Actions Left

${report.manualActions.length ? report.manualActions.map((item) => `- ${item}`).join("\n") : "- No manual action was detected by the latest setup script run."}

## Always Manual Before Real Users

- Create/approve matching App Store Connect IAP products for real iOS builds.
- Connect the real App Store app instead of relying only on the RevenueCat Test Store.
- Run sandbox purchases on a real iPhone or TestFlight build.
- Review App Store privacy, legal, teen-safety, and monetization copy.

## Exact Paywall Dashboard Steps

Repeat these steps for each offering listed above:

1. Open RevenueCat Dashboard.
2. Select project \`${report.context.projectId ?? "b2454250"}\`.
3. Open **Paywalls**.
4. Click **Create paywall**.
5. Choose **Use a template**, **Create from scratch**, or **AI Editor**.
6. Select the target offering: \`default\`, \`teen_perks\`, \`adult_pro\`, \`guardian_plus\`, \`ad_free\`, \`username_change\`, or \`job_boost\`.
7. Paste or adapt the matching prompt from \`docs/REVENUECAT_PAYWALL_BUILDER_PROMPTS.md\`.
8. Verify the package selector uses the offering's packages.
9. Use RevenueCat/App Store price strings; do not hardcode target prices as final truth.
10. Confirm no safety feature, basic applying, basic Guardian Mode, report/block, or Safety Ping is paywalled.
11. Save, publish, then rerun \`node scripts/qa-revenuecat-api.mjs\`.
`;
}

function testingPlanReport() {
  return `# RevenueCat Testing Plan

## Automated

- Run \`node scripts/qa-revenuecat-api.mjs\` to verify API access, app discovery, products, entitlements, offerings, packages, paywalls, and webhook config.
- Run \`node scripts/qa-revenuecat-config.mjs\` to verify Flutter uses public SDK keys and no server secrets are committed.
- Run \`node scripts/qa-revenuecat-webhook.mjs\` only with the webhook authorization header available in the current shell.
- Run \`node scripts/qa-monetization-rls.mjs\` after the additive Supabase migration is applied.
- Run \`node scripts/qa-username-credits.mjs\` to verify username and job boost credit RLS.

## Manual

- Test RevenueCat purchase, cancellation, restore, and Customer Center on a real iPhone/TestFlight sandbox build.
- Confirm RevenueCat CustomerInfo updates after sandbox purchases.
- Confirm webhook event delivery from the RevenueCat dashboard after manual webhook configuration.
- Confirm App Store Connect products and prices match the app review submission.
`;
}
