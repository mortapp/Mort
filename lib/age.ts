import type { UserRole } from "@/types/domain";

export type AgeGateResult =
  | { allowed: true; age: number; allowedRoles: UserRole[] }
  | { allowed: false; age: number; reason: string };

export function calculateAge(dobIso: string, now = new Date()) {
  const dob = new Date(`${dobIso}T00:00:00`);
  if (Number.isNaN(dob.getTime())) {
    return -1;
  }

  let age = now.getFullYear() - dob.getFullYear();
  const monthDelta = now.getMonth() - dob.getMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getDate() < dob.getDate())) {
    age -= 1;
  }
  return age;
}

export function evaluateAgeGate(dobIso: string): AgeGateResult {
  const age = calculateAge(dobIso);

  if (age < 0) {
    return { allowed: false, age, reason: "Enter a valid date of birth." };
  }

  if (age < 13) {
    return {
      allowed: false,
      age,
      reason: "MORT is available only to users age 13 and older."
    };
  }

  if (age < 18) {
    return { allowed: true, age, allowedRoles: ["teen"] };
  }

  return { allowed: true, age, allowedRoles: ["adult", "guardian"] };
}

export function isTeenRoleAllowed(dobIso: string) {
  const gate = evaluateAgeGate(dobIso);
  return gate.allowed && gate.allowedRoles.includes("teen");
}
