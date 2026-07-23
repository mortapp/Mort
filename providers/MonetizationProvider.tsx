import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";

import {
  configureRevenueCat,
  extractEntitlements,
  packageDisplayName,
  packagePrice,
  purchaseRevenueCatPackage,
  refreshRevenueCatSnapshot,
  restoreRevenueCatPurchases,
  statusMessage,
  type RevenueCatEntitlements,
  type RevenueCatStatus
} from "@/lib/revenuecat";
import { useAuth } from "@/providers/AuthProvider";
import type { CustomerInfo, PurchasesOfferings, PurchasesPackage } from "react-native-purchases";

type MonetizationContextValue = {
  loading: boolean;
  status: RevenueCatStatus;
  error: string | null;
  message: string | null;
  customerInfo: CustomerInfo | null;
  offerings: PurchasesOfferings | null;
  entitlements: RevenueCatEntitlements;
  isPremium: boolean;
  isAdFree: boolean;
  refresh: () => Promise<void>;
  restore: () => Promise<void>;
  purchasePackage: (aPackage: PurchasesPackage) => Promise<void>;
  describePackage: (aPackage: PurchasesPackage) => { name: string; price: string };
};

const emptyEntitlements: RevenueCatEntitlements = {
  premium: false,
  plus: false,
  adFree: false,
  adultPro: false,
  businessBoost: false,
  guardianPlus: false,
  lifetime: false,
  profileStylePack: false,
  usernameChangeToken: false,
  jobBoost: false
};

const MonetizationContext = createContext<MonetizationContextValue | null>(null);

export function MonetizationProvider({ children }: PropsWithChildren) {
  const { user } = useAuth();
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<RevenueCatStatus>("disabled");
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [customerInfo, setCustomerInfo] = useState<CustomerInfo | null>(null);
  const [offerings, setOfferings] = useState<PurchasesOfferings | null>(null);
  const [entitlements, setEntitlements] = useState<RevenueCatEntitlements>(emptyEntitlements);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const snapshot = await refreshRevenueCatSnapshot(user?.id ?? null);
      setStatus(snapshot.status);
      setCustomerInfo(snapshot.customerInfo);
      setOfferings(snapshot.offerings);
      setEntitlements(snapshot.entitlements);
      setMessage(snapshot.message ?? null);
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Unable to refresh purchase status.");
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    let mounted = true;

    async function configure() {
      try {
        const nextStatus = await configureRevenueCat(user?.id ?? null);
        if (!mounted) return;
        setStatus(nextStatus);
        setMessage(statusMessage(nextStatus));
        if (nextStatus === "configured") {
          await refresh();
        }
      } catch (err) {
        if (!mounted) return;
        setStatus("error");
        setError(err instanceof Error ? err.message : "Unable to configure RevenueCat.");
      }
    }

    void configure();

    return () => {
      mounted = false;
    };
  }, [refresh, user?.id]);

  const restore = useCallback(async () => {
    setLoading(true);
    setError(null);
    setMessage(null);
    try {
      const info = await restoreRevenueCatPurchases(user?.id ?? null);
      setCustomerInfo(info);
      setEntitlements(extractEntitlements(info));
      setMessage("Restore finished. Active entitlements are shown below.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to restore purchases.");
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  const purchasePackage = useCallback(
    async (aPackage: PurchasesPackage) => {
      setLoading(true);
      setError(null);
      setMessage(null);
      try {
        const result = await purchaseRevenueCatPackage(aPackage, user?.id ?? null);
        setCustomerInfo(result.customerInfo);
        setEntitlements(extractEntitlements(result.customerInfo));
        setMessage("Purchase flow finished. RevenueCat entitlements were refreshed.");
      } catch (err) {
        const anyError = err as { userCancelled?: boolean; message?: string };
        if (anyError.userCancelled) {
          setMessage("Purchase cancelled.");
        } else {
          setError(anyError.message ?? "Unable to complete purchase.");
        }
      } finally {
        setLoading(false);
      }
    },
    [user?.id]
  );

  const value = useMemo<MonetizationContextValue>(
    () => ({
      loading,
      status,
      error,
      message,
      customerInfo,
      offerings,
      entitlements,
      isPremium: entitlements.premium,
      isAdFree: entitlements.adFree || entitlements.premium,
      refresh,
      restore,
      purchasePackage,
      describePackage: (aPackage) => ({
        name: packageDisplayName(aPackage),
        price: packagePrice(aPackage)
      })
    }),
    [customerInfo, entitlements, error, loading, message, offerings, purchasePackage, refresh, restore, status]
  );

  return <MonetizationContext.Provider value={value}>{children}</MonetizationContext.Provider>;
}

export function useMonetization() {
  const value = useContext(MonetizationContext);
  if (!value) {
    throw new Error("useMonetization must be used inside MonetizationProvider");
  }
  return value;
}
