import { assertQa, qaLog, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-financial-kb-audience";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
  ],
  async ({ teen, adult }) => {
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
      `NO_REGRESSION: teen search for "${query}" returned no /financial* result at all (${JSON.stringify(teenRoutes)}) -- the fix must not have removed teen access`,
    );
    qaLog(scope, "NO_REGRESSION=PASS (teen still finds the financial-safety KB documents)");

    const adultResults = await adult.client.rpc("support_search_kb", {
      p_query: query,
      p_limit: 8,
    });
    assertQa(!adultResults.error, `adult support_search_kb failed: ${adultResults.error?.message}`);
    const adultRoutes = (adultResults.data ?? []).map((row) => row.navigation_route);
    assertQa(
      !adultRoutes.includes("/financial") &&
        !adultRoutes.includes("/financial/benefits") &&
        !adultRoutes.includes("/financial/expenses"),
      `ADULT_NO_DEAD_END: an adult's KB search still returned a teen-only /financial* route (${JSON.stringify(adultRoutes)}), which would dead-end at WrongRoleScreen`,
    );
    qaLog(scope, "ADULT_NO_DEAD_END=PASS (adult search no longer surfaces the teen-only /financial* routes)");
  },
);

qaLog(scope, "financial KB audience-vs-route mismatch fix verified end-to-end with synthetic QA fixtures only");
