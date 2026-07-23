import { router } from "expo-router";
import { useEffect } from "react";

import { isAccountRestricted } from "@/lib/account";
import { useAuth } from "@/providers/AuthProvider";
import type { UserRole } from "@/types/domain";

export function useRequireRole(...roles: UserRole[]) {
  const { configured, loading, session, profile } = useAuth();
  const roleAllowed = !!profile?.role && roles.includes(profile.role);
  const restricted = isAccountRestricted(profile);

  useEffect(() => {
    if (loading || !configured) return;

    if (!session) {
      router.replace("/auth/sign-in");
      return;
    }

    if (restricted) {
      router.replace("/account-status" as never);
      return;
    }

    if (!profile?.onboarding_completed || !profile.role) {
      router.replace("/onboarding");
      return;
    }

    if (!roleAllowed) {
      router.replace("/");
    }
  }, [configured, loading, profile?.onboarding_completed, profile?.role, restricted, roleAllowed, session]);

  return configured && !loading && !!session && !!profile?.onboarding_completed && roleAllowed && !restricted;
}
