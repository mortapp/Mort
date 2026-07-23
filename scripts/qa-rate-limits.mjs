import {
  assertQa,
  qaLog,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-rate-limits";

await withQaUsers(
  scope,
  [{ key: "teen", role: "teen" }],
  async ({ teen }) => {
    const allowed = await teen.client.rpc("is_action_allowed", {
      p_action: "support_conversation_create",
    });
    assertQa(!allowed.error && allowed.data === true, "authenticated rate-limit status RPC failed");
    qaLog(scope, "authenticated user can check their own action allowance");

    const lowLevelCheck = await teen.client.rpc("check_rate_limit", {
      p_action: "support_conversation_create",
      p_limit: 8,
      p_window_seconds: 86400,
    });
    assertQa(lowLevelCheck.error, "client directly invoked internal check_rate_limit helper");
    const lowLevelWrite = await teen.client.rpc("record_rate_limit_event", {
      p_action: "support_conversation_create",
      p_ip_address: null,
    });
    assertQa(lowLevelWrite.error, "client directly invoked internal rate-limit mutation helper");
    const adminOverview = await teen.client.rpc("admin_rate_limit_overview");
    assertQa(adminOverview.error, "non-admin read the admin rate-limit overview");
    qaLog(scope, "low-level mutation helpers and admin overview reject normal users");

    for (let index = 0; index < 8; index += 1) {
      const created = await teen.client.rpc("create_support_ticket", {
        p_subject: `QA rate limit ${index + 1}`,
        p_message: "This isolated support ticket verifies the server-side daily action counter.",
      });
      assertQa(!created.error && created.data?.ok === true, `allowed support action ${index + 1} failed`);
    }
    const blocked = await teen.client.rpc("create_support_ticket", {
      p_subject: "QA rate limit blocked",
      p_message: "This ninth isolated support action must be rejected by the database rate limit.",
    });
    assertQa(!blocked.error && blocked.data?.ok === false, "ninth daily support action was not blocked");
    assertQa(blocked.data.code === "support_ticket_limit_reached", `rate limit returned ${blocked.data.code}`);
    qaLog(scope, "server allows eight support tickets and returns a structured code for the ninth");
  },
);
