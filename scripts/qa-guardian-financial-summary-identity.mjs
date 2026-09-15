import { randomUUID } from "node:crypto";

import { assertQa, qaLog, serviceClient, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-guardian-financial-summary-identity";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "linkedGuardian", role: "guardian" },
    { key: "unlinkedGuardian", role: "guardian" },
  ],
  async ({ teen, linkedGuardian, unlinkedGuardian }) => {
    const year = new Date().getUTCFullYear();
    const targetLabel = `qa-identity-check-${randomUUID()}`;

    // Fixture setup: financial_preferences/financial_personal_targets have no
    // direct service_role table grant (confirmed via has_table_privilege) --
    // by design, all access goes through the "my"-scoped self-service RPCs,
    // called here as the teen would call them themselves. guardian_connections
    // does grant service_role INSERT directly, used below only to establish
    // the link (there is no self-service "accept an invite" RPC exercised by
    // this narrow regression).
    const prefs = await teen.client.rpc("set_my_financial_preferences", {
      p_guardian_financial_visibility: true,
    });
    assertQa(!prefs.error && prefs.data?.ok === true, `fixture: set_my_financial_preferences failed: ${prefs.error?.message ?? JSON.stringify(prefs.data)}`);

    const target = await teen.client.rpc("upsert_my_financial_target", {
      p_year: year,
      p_amount_cents: 123456,
      p_label: targetLabel,
    });
    assertQa(!target.error && target.data?.ok === true, `fixture: upsert_my_financial_target failed: ${target.error?.message ?? JSON.stringify(target.data)}`);

    const link = await serviceClient.from("guardian_connections").insert({
      teen_id: teen.id,
      guardian_id: linkedGuardian.id,
      status: "active",
    });
    assertQa(!link.error, `fixture: guardian_connections insert failed: ${link.error?.message}`);

    // AUTHORIZATION_GATE: self-target and invalid year are rejected before any data is touched.
    const selfTarget = await teen.client.rpc("get_linked_teen_financial_summary", {
      p_teen_id: teen.id,
      p_year: year,
    });
    assertQa(
      !selfTarget.error && selfTarget.data?.code === "invalid_request",
      `AUTHORIZATION_GATE: self-target call was not rejected as invalid_request (${JSON.stringify(selfTarget.data)})`,
    );

    const badYear = await linkedGuardian.client.rpc("get_linked_teen_financial_summary", {
      p_teen_id: teen.id,
      p_year: 1899,
    });
    assertQa(
      !badYear.error && badYear.data?.code === "invalid_year",
      `AUTHORIZATION_GATE: out-of-range year was not rejected as invalid_year (${JSON.stringify(badYear.data)})`,
    );
    qaLog(scope, "AUTHORIZATION_GATE=PASS (self-target and invalid-year both fail closed)");

    // UNLINKED_GUARDIAN_DENIED: a real, unconnected guardian must be denied even
    // though the teen has opted in.
    const unlinkedAttempt = await unlinkedGuardian.client.rpc("get_linked_teen_financial_summary", {
      p_teen_id: teen.id,
      p_year: year,
    });
    assertQa(
      !unlinkedAttempt.error && unlinkedAttempt.data?.code === "not_linked_guardian",
      `UNLINKED_GUARDIAN_DENIED: unlinked guardian was not rejected as not_linked_guardian (${JSON.stringify(unlinkedAttempt.data)})`,
    );
    qaLog(scope, "UNLINKED_GUARDIAN_DENIED=PASS");

    // VISIBILITY_OPT_IN_REQUIRED: turn visibility off and confirm the linked
    // guardian is now denied purely on that basis.
    const optOut = await teen.client.rpc("set_my_financial_preferences", {
      p_guardian_financial_visibility: false,
    });
    assertQa(!optOut.error && optOut.data?.ok === true, `fixture: opt-out failed: ${optOut.error?.message ?? JSON.stringify(optOut.data)}`);

    const deniedByOptOut = await linkedGuardian.client.rpc("get_linked_teen_financial_summary", {
      p_teen_id: teen.id,
      p_year: year,
    });
    assertQa(
      !deniedByOptOut.error && deniedByOptOut.data?.code === "guardian_access_disabled",
      `VISIBILITY_OPT_IN_REQUIRED: linked guardian was not rejected as guardian_access_disabled while opted out (${JSON.stringify(deniedByOptOut.data)})`,
    );
    qaLog(scope, "VISIBILITY_OPT_IN_REQUIRED=PASS");

    const optIn = await teen.client.rpc("set_my_financial_preferences", {
      p_guardian_financial_visibility: true,
    });
    assertQa(!optIn.error && optIn.data?.ok === true, `fixture: opt-in failed: ${optIn.error?.message ?? JSON.stringify(optIn.data)}`);

    // LINKED_TEEN_IDENTITY: the one authorized, linked, opted-in guardian must
    // receive the TEEN's own data (the exact personal target inserted above),
    // proving the summary is scoped by p_teen_id and not by the caller's own
    // (guardian) identity -- the original bug this migration fixes.
    const authorized = await linkedGuardian.client.rpc("get_linked_teen_financial_summary", {
      p_teen_id: teen.id,
      p_year: year,
    });
    assertQa(
      !authorized.error && authorized.data?.ok === true,
      `LINKED_TEEN_IDENTITY: authorized call did not succeed (${JSON.stringify(authorized.data)})`,
    );
    const targets = authorized.data?.personal_targets ?? [];
    assertQa(
      Array.isArray(targets) && targets.some((t) => t.label === targetLabel && t.amount_cents === 123456),
      `LINKED_TEEN_IDENTITY: response did not contain the teen's own personal target (got ${JSON.stringify(targets)}) -- this is exactly the guardian-sees-own-empty-summary regression`,
    );
    assertQa(
      authorized.data?.benefit_programs === null,
      "LINKED_TEEN_IDENTITY: benefit_programs must remain null (never shared with guardians)",
    );
    qaLog(scope, "LINKED_TEEN_IDENTITY=PASS (guardian received the linked teen's own data, not their own)");
  },
);

qaLog(scope, "guardian financial-summary identity fix verified end-to-end with synthetic QA fixtures only");
