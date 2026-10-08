import { canonicalId, validPassword } from "./parser.ts";
type ProviderConfig = {
  mode: "local_fixture";
  authUrl: string;
  serviceKey: string;
};
type OperationStore = { reconcile(id: string): Promise<string> };
export async function createFixtureProvider(
  config: ProviderConfig,
  store: OperationStore,
  request = fetch,
) {
  if (
    config.mode !== "local_fixture" ||
    config.authUrl !== "http://127.0.0.1:55421"
  ) throw new Error("Fixture provider refused");
  try {
    const encoded = config.serviceKey.split(".")[1],
      claims = JSON.parse(
        atob(encoded.replaceAll("-", "+").replaceAll("_", "/")),
      );
    if (claims.role !== "service_role" || claims.iss !== "fixture") {
      throw new Error("Fixture provider refused");
    }
    const response = await request(config.authUrl + "/health", {
      signal: AbortSignal.timeout(2000),
    });
    if (!response.ok || (await response.json()).version !== "v2.197.0") {
      throw new Error("Fixture provider refused");
    }
  } catch {
    throw new Error("Fixture provider refused");
  }
  return {
    dispatch: async (
      operation: Record<string, unknown>,
      password: string,
      parent: AbortSignal,
    ): Promise<"committed" | "pending" | "fenced"> => {
      const operationId = canonicalId(operation.operationId),
        accountId = canonicalId(operation.accountId);
      if (
        !validPassword(password) ||
        !["confirmation", "recovery"].includes(String(operation.purpose)) ||
        typeof operation.expiresAt !== "string"
      ) return "fenced";
      const remaining = Date.parse(operation.expiresAt) - Date.now();
      if (!Number.isFinite(remaining) || remaining <= 0) return "fenced";
      const signal = AbortSignal.any([
        parent,
        AbortSignal.timeout(Math.max(1, Math.min(10000, remaining))),
      ]);
      try {
        signal.throwIfAborted();
        if (await store.reconcile(operationId) !== "pending") return "fenced";
        const update = async (body: Record<string, unknown>) => {
          signal.throwIfAborted();
          const response = await request(
            `${config.authUrl}/admin/users/${accountId}`,
            {
              method: "PUT",
              signal,
              headers: {
                "content-type": "application/json",
                authorization: `Bearer ${config.serviceKey}`,
              },
              body: JSON.stringify(body),
            },
          );
          // Provider status/body is not authority; private transactional state is.
          const ok = response.ok;
          await response.body?.cancel();
          return ok;
        };
        const app_metadata = { mort_email_operation_id: operationId };
        if (!await update({ app_metadata })) return await outcome();
        signal.throwIfAborted();
        await update({
          app_metadata,
          password,
          ...(operation.purpose === "confirmation"
            ? { email_confirm: true }
            : {}),
        });
      } catch {
        /* Preserve one-use pending authority; never reopen on transport failure. */
      }
      return await outcome();
      async function outcome(): Promise<"committed" | "pending" | "fenced"> {
        try {
          const state = await store.reconcile(operationId);
          return state === "committed"
            ? "committed"
            : state === "fenced"
            ? "fenced"
            : "pending";
        } catch {
          return "pending";
        }
      }
    },
  };
}
