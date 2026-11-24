import { removeAndConfirmAuthIdentity } from "../account-deletion-processor/auth_identity.ts";

const id = "01234567-0123-4123-8123-0123456789ab";
const present = { data: { user: { id } }, error: null };
const absent = {
  data: { user: null },
  error: { status: 404, code: "user_not_found" },
};
const ok = { data: { user: null }, error: null };
const lease = () => Promise.resolve();

async function run(
  steps: unknown[],
  deletion: unknown = ok,
  assertLease = lease,
) {
  let deletes = 0;
  let lookups = 0;
  try {
    await removeAndConfirmAuthIdentity(
      {
        getUserById() {
          const v = steps[lookups++];
          return v instanceof Error ? Promise.reject(v) : Promise.resolve(v);
        },
        deleteUser(actual, soft) {
          if (actual !== id || soft !== false) {
            throw new Error("Wrong target or soft delete");
          }
          deletes++;
          return deletion instanceof Error
            ? Promise.reject(deletion)
            : Promise.resolve(deletion);
        },
      },
      id,
      assertLease,
    );
    return { completed: true, deletes, lookups };
  } catch {
    return { completed: false, deletes, lookups };
  }
}

Deno.test("Auth hard-delete requires an independent typed not-found and is idempotent", async () => {
  const fresh = await run([present, absent]);
  const retry = await run([absent]);
  const raced = await run([present, absent], absent);
  if (
    !fresh.completed || fresh.deletes !== 1 || fresh.lookups !== 2 ||
    !retry.completed || retry.deletes !== 0 || !raced.completed
  ) {
    throw new Error("Expected explicitly confirmed identity absence");
  }
});

Deno.test("malformed and uncertain lookups never authorize deletion or completion", async () => {
  for (
    const response of [
      undefined,
      null,
      {},
      ok,
      new Error("timeout"),
      new Error("network"),
      { data: { user: null }, error: { status: 404 } },
      { data: { user: null }, error: { status: 403, code: "user_not_found" } },
      { data: { user: null }, error: { status: 500, code: "server_error" } },
      { data: { user: { id } }, error: absent.error },
      { data: { user: { id: "not-the-target" } }, error: null },
    ]
  ) {
    const initial = await run([response]);
    const final = await run([present, response]);
    if (initial.completed || initial.deletes || final.completed) {
      throw new Error("Indeterminate Auth response was treated as absence");
    }
  }
});

Deno.test("still-present identity, failed delete and stale lease fail closed", async () => {
  for (
    const failure of [null, {}, { error: { status: 500 } }, new Error("abort")]
  ) {
    if ((await run([present, absent], failure)).completed) {
      throw new Error("Delete error accepted");
    }
  }
  if ((await run([present, present])).completed) {
    throw new Error("Existing identity accepted");
  }
  let checks = 0;
  const stale = await run([present, absent], ok, async () => {
    if (++checks === 2) throw new Error("stale lease");
  });
  if (stale.completed || stale.deletes) {
    throw new Error("Expired lease deleted identity");
  }
});
