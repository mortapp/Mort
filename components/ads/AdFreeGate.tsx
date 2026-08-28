import type { PropsWithChildren } from "react";

import { FeatureLockCard } from "@/components/DesignSystem";
import { useMonetization } from "@/providers/MonetizationProvider";

export function AdFreeGate({ children }: PropsWithChildren) {
  const { isAdFree } = useMonetization();

  if (isAdFree) {
    return <FeatureLockCard title="Ad-free active" body="This slot is hidden because ad-free is active." cta="Ad-free" />;
  }

  return <>{children}</>;
}
