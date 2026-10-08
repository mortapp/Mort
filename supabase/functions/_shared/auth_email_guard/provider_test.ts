import { createFixtureProvider } from "./provider.ts";
const check = (v: unknown, m: string) => {
  if (!v) throw new Error(m);
};
const serviceKey = [
  "eyJhbGciOiJIUzI1NiJ9",
  btoa(JSON.stringify({ role: "service_role", iss: "fixture" })),
  "fixture-signature",
].join(".");
Deno.test("fixture provider uses supported Admin marker plus bounded password operation and private reconciliation only", async () => {
  const operation = {
    operationId: crypto.randomUUID(),
    accountId: crypto.randomUUID(),
    purpose: "confirmation",
    expiresAt: new Date(Date.now() + 300000).toISOString(),
  };
  let reads = 0, calls = 0;
  const store = {
    reconcile: async (_id: string) => {
      reads++;
      return reads === 1 ? "pending" : "committed";
    },
  };
  const fakeFetch: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.endsWith("/health")) return Response.json({ version: "v2.197.0" });
    check(
      url === `http://127.0.0.1:55421/admin/users/${operation.accountId}` &&
        init?.method === "PUT",
      "Fixed owned Admin route only",
    );
    const value = JSON.parse(String(init?.body));
    check(
      value.app_metadata.mort_email_operation_id === operation.operationId &&
        !value.email && !value.role && !value.user_metadata,
      "Metadata correlator is explicit, no arbitrary authority",
    );
    if (calls++ === 0) {
      check(
        !value.password && !value.email_confirm,
        "Marker preparation has no credential mutation",
      );
    } else {check(
        value.password === "Good!Password7" && value.email_confirm === true,
        "Supported Admin update confirms and replaces for confirmation only",
      );}
    return Response.json({});
  };
  const provider = await createFixtureProvider(
    { mode: "local_fixture", authUrl: "http://127.0.0.1:55421", serviceKey },
    store,
    fakeFetch,
  );
  check(
    await provider.dispatch(
          operation,
          "Good!Password7",
          new AbortController().signal,
        ) === "committed" && calls === 2 && reads === 2,
    "Only private committed evidence is success",
  );
});
Deno.test("provider rejects hosted/disabled targets and unknown outcome never becomes success", async () => {
  let denied = false;
  try {
    await createFixtureProvider({
      mode: "local_fixture",
      authUrl: "https://rakjydmgwwgtdislanbt.supabase.co",
      serviceKey,
    }, { reconcile: async () => "pending" });
  } catch {
    denied = true;
  }
  check(denied, "No hosted provider constructor");
  const provider = await createFixtureProvider(
    { mode: "local_fixture", authUrl: "http://127.0.0.1:55421", serviceKey },
    {
      reconcile: async () => "pending",
    },
    async () => Response.json({ version: "v2.197.0" }),
  );
  const operation = {
    operationId: crypto.randomUUID(),
    accountId: crypto.randomUUID(),
    purpose: "recovery",
    expiresAt: new Date(Date.now() + 300000).toISOString(),
  };
  check(
    await provider.dispatch(
      operation,
      "Good!Password7",
      new AbortController().signal,
    ) === "pending",
    "Ambiguous operation remains consumed/reserved and pending",
  );
});
