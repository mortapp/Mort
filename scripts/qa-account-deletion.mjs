import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-account-deletion";

await withQaUsers(
  scope,
  [
    { key: "requester", role: "guardian" },
    { key: "otherUser", role: "adult" },
  ],
  async ({ requester, otherUser }) => {
    let requestId;
    try {
      const request = await requester.client.rpc("request_account_deletion", {
        p_source: "in_app",
      });
      assertQa(
        !request.error &&
          request.data?.ok === true &&
          request.data.request.status === "requested",
        `Verified deletion request failed: ${request.error?.message ?? request.data?.code}`,
      );
      requestId = request.data.request.id;

      const { data: leaked, error: leakError } = await otherUser.client
        .from("account_deletion_requests")
        .select("id")
        .eq("id", requestId);
      assertQa(
        !leakError && leaked.length === 0,
        "Another user could read a deletion request.",
      );

      const cancel = await requester.client.rpc(
        "cancel_account_deletion_request",
      );
      assertQa(
        !cancel.error && cancel.data?.request?.status === "cancelled",
        "Pending deletion request could not be cancelled.",
      );
      qaLog(
        scope,
        "remote create/status/cancel passed and another account could not read the request",
      );
    } finally {
      if (requestId) {
        const cleanup = await serviceClient
          .from("account_deletion_requests")
          .delete()
          .eq("id", requestId);
        if (cleanup.error) {
          throw new Error(
            `Could not remove the disposable deletion request: ${cleanup.error.message}`,
          );
        }
      }
      await withDatabase((database) =>
        database.query(
          "delete from public.rate_limit_events where user_id = $1 and action = $2",
          [requester.id, "account_deletion_request"],
        ),
      );
    }
  },
);
