import type { Profile } from "@/types/domain";

export function isAccountRestricted(profile: Profile | null) {
  if (!profile) return false;
  if (profile.account_status && profile.account_status !== "active") return true;
  if (!profile.blocked_until) return false;
  return new Date(profile.blocked_until).getTime() > Date.now();
}

export function accountStatusLabel(profile: Profile | null) {
  if (!profile) return "Account unavailable";
  if (profile.account_status === "banned") return "Account banned";
  if (profile.account_status === "suspended") return "Account suspended";
  if (profile.blocked_until && new Date(profile.blocked_until).getTime() > Date.now()) {
    return `Restricted until ${new Date(profile.blocked_until).toLocaleString()}`;
  }
  return "Account active";
}
