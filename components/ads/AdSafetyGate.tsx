import type { PropsWithChildren } from "react";

import { FeatureLockCard } from "@/components/DesignSystem";
import { evaluateAdEligibility, type AdFormat, type AdPlacement } from "@/lib/ads";
import { useAuth } from "@/providers/AuthProvider";

export function AdSafetyGate({
  children,
  placement,
  format = "banner"
}: PropsWithChildren<{ placement: AdPlacement; format?: AdFormat }>) {
  const { profile } = useAuth();
  const eligibility = evaluateAdEligibility({ placement, format, role: profile?.role, consentReady: false });

  if (!eligibility.allowed) {
    return <FeatureLockCard title="Ad hidden" body={eligibility.reason} cta="Safety gate" />;
  }

  return <>{children}</>;
}
