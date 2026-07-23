import { useMemo } from "react";

import { evaluateAdEligibility, getAdUnitId, type AdFormat, type AdPlacement } from "@/lib/ads";
import { useAuth } from "@/providers/AuthProvider";
import { useMonetization } from "@/providers/MonetizationProvider";

export function useAds({
  placement,
  format,
  consentReady = false
}: {
  placement: AdPlacement;
  format: AdFormat;
  consentReady?: boolean;
}) {
  const { profile } = useAuth();
  const { isAdFree } = useMonetization();

  return useMemo(() => {
    const eligibility = evaluateAdEligibility({
      placement,
      format,
      role: profile?.role,
      hasAdFreeEntitlement: isAdFree,
      consentReady
    });

    return {
      eligibility,
      unitId: eligibility.allowed ? getAdUnitId(format) : ""
    };
  }, [consentReady, format, isAdFree, placement, profile?.role]);
}
