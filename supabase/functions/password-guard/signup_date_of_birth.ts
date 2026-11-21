export type SignupDateOfBirthError = "dob_invalid" | "dob_under_minimum_age";

/** Use the server's UTC calendar day, not a date provided by the caller. */
export function signupDateOfBirthError(
  value: string,
  today = new Date(),
): SignupDateOfBirthError | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value.startsWith("0000-")) {
    return "dob_invalid";
  }
  const birth = new Date(`${value}T00:00:00.000Z`);
  // Date can normalize impossible dates such as February 30 rather than
  // rejecting them. Require a round trip to the same calendar date.
  if (
    !Number.isFinite(birth.getTime()) ||
    birth.toISOString().slice(0, 10) !== value || birth > today
  ) {
    return "dob_invalid";
  }
  let age = today.getUTCFullYear() - birth.getUTCFullYear();
  if (
    today.getUTCMonth() < birth.getUTCMonth() ||
    (today.getUTCMonth() === birth.getUTCMonth() &&
      today.getUTCDate() < birth.getUTCDate())
  ) {
    age--;
  }
  if (age > 120) return "dob_invalid";
  return age < 13 ? "dob_under_minimum_age" : null;
}
