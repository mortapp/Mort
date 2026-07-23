import { useMemo } from "react";

import { getFeatureAccess } from "@/lib/featureAccess";
import { useAuth } from "@/providers/AuthProvider";
import { useMonetization } from "@/providers/MonetizationProvider";

export function useFeatureAccess() {
  const { profile } = useAuth();
  const { entitlements, isAdFree, isPremium } = useMonetization();

  return useMemo(
    () =>
      getFeatureAccess({
        role: profile?.role ?? null,
        entitlements,
        isAdFree,
        isPremium
      }),
    [entitlements, isAdFree, isPremium, profile?.role]
  );
}
