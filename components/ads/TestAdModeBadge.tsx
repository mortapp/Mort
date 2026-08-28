import { AppBadge } from "@/components/DesignSystem";
import { USE_TEST_ADS } from "@/lib/env";

export function TestAdModeBadge() {
  return <AppBadge label={USE_TEST_ADS ? "AdMob test ads" : "AdMob live mode"} tone={USE_TEST_ADS ? "info" : "warning"} />;
}
