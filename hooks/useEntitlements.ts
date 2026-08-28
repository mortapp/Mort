import { useMonetization } from "@/providers/MonetizationProvider";

export function useEntitlements() {
  const monetization = useMonetization();

  return {
    entitlements: monetization.entitlements,
    isPremium: monetization.isPremium,
    isAdFree: monetization.isAdFree,
    loading: monetization.loading,
    status: monetization.status
  };
}
