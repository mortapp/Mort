type AuthAdmin = {
  getUserById(id: string): Promise<unknown>;
  deleteUser(id: string, soft: false): Promise<unknown>;
};

function object(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function lookup(response: unknown, id: string): "absent" | "present" {
  const result = object(response);
  const error = object(result?.error);
  const data = object(result?.data);
  if (
    error?.status === 404 && error.code === "user_not_found" &&
    data?.user === null
  ) return "absent";
  if (result?.error === null && object(data?.user)?.id === id) return "present";
  throw new Error("AuthIdentityLookupUnconfirmed");
}

export async function removeAndConfirmAuthIdentity(
  admin: AuthAdmin,
  id: string,
  assertLease: () => Promise<void>,
): Promise<void> {
  await assertLease();
  if (lookup(await admin.getUserById(id), id) === "absent") return;
  await assertLease();
  const result = object(await admin.deleteUser(id, false));
  const error = object(result?.error);
  // A racing deletion can legitimately return a typed 404. It is still not
  // proof: only a new, correctly classified lookup can confirm absence.
  if (
    result?.error !== null &&
    !(error?.status === 404 && error.code === "user_not_found")
  ) {
    throw new Error("AuthIdentityDeleteUnconfirmed");
  }
  if (lookup(await admin.getUserById(id), id) !== "absent") {
    throw new Error("AuthIdentityStillPresent");
  }
}
