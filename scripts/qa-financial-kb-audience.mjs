import { assertQa, qaLog, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-financial-kb-audience";

function assertNoFinancialRoute(routes, label) {
  assertQa(
    !routes.includes("/financial") &&
      !routes.includes("/financial/benefits") &&
      !routes.includes("/financial/expenses"),
    `${label}: search still returned a teen-only /financial* route (${JSON.stringify(routes)}), which would dead-end at WrongRoleScreen`,
  );
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "guardian", role: "guardian" },
  ],
  async ({ teen, adult, guardian }) => {
    const query = "earnings safety expenses receipts benefits";

    const teenResults = await teen.client.rpc("support_search_kb", {
      p_query: query,
      p_limit: 8,
    });
    assertQa(!teenResults.error, `fixture: teen support_search_kb failed: ${teenResults.error?.message}`);
    const teenRoutes = (teenResults.data ?? []).map((row) => row.navigation_route);
    assertQa(
      teenRoutes.includes("/financial") ||
        teenRoutes.includes("/financial/benefits") ||
        teenRoutes.includes("/financial/expenses"),
      `TEEN_FINANCIAL_KB_VISIBLE: teen search for "${query}" returned no /financial* result at all (${JSON.stringify(teenRoutes)}) -- the fix must not have removed teen access`,
    );
    qaLog(scope, "TEEN_FINANCIAL_KB_VISIBLE=PASS (teen still finds the financial-safety KB documents)");

    const adultResults = await adult.client.rpc("support_search_kb", {
      p_query: query,
      p_limit: 8,
    });
    assertQa(!adultResults.error, `adult support_search_kb failed: ${adultResults.error?.message}`);
    const adultRoutes = (adultResults.data ?? []).map((row) => row.navigation_route);
    assertNoFinancialRoute(adultRoutes, "ADULT_TEEN_FINANCIAL_ROUTE_EXPOSURE");
    qaLog(scope, "ADULT_TEEN_FINANCIAL_ROUTE_EXPOSURE=0 (adult search no longer surfaces the teen-only /financial* routes)");

    const guardianResults = await guardian.client.rpc("support_search_kb", {
      p_query: query,
      p_limit: 8,
    });
    assertQa(!guardianResults.error, `guardian support_search_kb failed: ${guardianResults.error?.message}`);
    const guardianRoutes = (guardianResults.data ?? []).map((row) => row.navigation_route);
    assertNoFinancialRoute(guardianRoutes, "GUARDIAN_TEEN_FINANCIAL_ROUTE_EXPOSURE");
    qaLog(scope, "GUARDIAN_TEEN_FINANCIAL_ROUTE_EXPOSURE=0 (guardian search no longer surfaces the teen-only /financial* routes)");
  },
);

qaLog(scope, "financial KB audience-vs-route mismatch fix verified end-to-end with synthetic QA fixtures only");
