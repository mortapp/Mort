// MORT password policy, enforced server-side by the password-guard Edge
// Function. Mirrors flutter_mort MortValidators.password (12+ characters,
// upper, lower, digit, symbol) and adds limits the client cannot be trusted
// with: bcrypt's 72-byte ceiling and "password must not contain the email".

export const PASSWORD_MIN_LENGTH = 12;
export const PASSWORD_MAX_BYTES = 72;

export type PasswordPolicyCode =
  | "password_required"
  | "password_too_short"
  | "password_too_long"
  | "password_invalid_characters"
  | "password_complexity_required"
  | "password_contains_email";

export function evaluatePasswordPolicy(
  password: unknown,
  email?: string | null,
): { ok: true } | { ok: false; code: PasswordPolicyCode } {
  if (typeof password !== "string" || password.length === 0) {
    return { ok: false, code: "password_required" };
  }
  // Control characters (incl. NUL) are rejected: they break bcrypt input
  // handling in some stacks and are never typed intentionally.
  // deno-lint-ignore no-control-regex
  if (/[\u0000-\u001f\u007f]/.test(password)) {
    return { ok: false, code: "password_invalid_characters" };
  }
  if ([...password].length < PASSWORD_MIN_LENGTH) {
    return { ok: false, code: "password_too_short" };
  }
  if (new TextEncoder().encode(password).byteLength > PASSWORD_MAX_BYTES) {
    return { ok: false, code: "password_too_long" };
  }
  if (
    !/[a-z]/.test(password) || !/[A-Z]/.test(password) ||
    !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)
  ) {
    return { ok: false, code: "password_complexity_required" };
  }
  const normalizedEmail = (email ?? "").trim().toLowerCase();
  if (normalizedEmail) {
    const lowered = password.toLowerCase();
    const local = normalizedEmail.split("@")[0] ?? "";
    if (lowered.includes(normalizedEmail) || (local.length >= 4 && lowered.includes(local))) {
      return { ok: false, code: "password_contains_email" };
    }
  }
  return { ok: true };
}
