import { useEffect, useState, type PropsWithChildren } from "react";
import { router } from "expo-router";
import { Linking, Platform, StyleSheet, View } from "react-native";
import type { PurchasesPackage } from "react-native-purchases";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import {
  AppBadge,
  FeatureLockCard,
  GuardianModeBanner,
  PremiumBadge,
  SafetyBanner
} from "@/components/DesignSystem";
import { Text } from "@/components/Text";
import {
  evaluateAdEligibility,
  getAdUnitId,
  initializeAds,
  type AdPlacement
} from "@/lib/ads";
import { ADS_ENABLED, USE_TEST_ADS } from "@/lib/env";
import { NativeBannerAd } from "@/lib/mobileAdsBridge";
import { colors, spacing } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import { useMonetization } from "@/providers/MonetizationProvider";

export function MonetizationDisclaimer() {
  return (
    <SafetyBanner>
      RevenueCat purchases are for app premium features only. MORT does not process job payments, hold funds, provide
      escrow, split payouts, guarantee work, or store payment credentials.
    </SafetyBanner>
  );
}

export function TeenMonetizationSafetyNotice() {
  return (
    <Card>
      <AppBadge label="Teen-safe monetization" tone="success" />
      <Text>
        Teens can use core MORT for free. Safety, Guardian Mode, reporting, blocking, basic applications, proof basics,
        and message scanning stay free. Ask a guardian before buying subscriptions or add-ons.
      </Text>
    </Card>
  );
}

export function GuardianPurchaseNotice() {
  return (
    <Card>
      <AppBadge label="Guardian guidance" tone="info" />
      <Text>
        Purchases should be reviewed by a parent or guardian for teen users. Premium can improve convenience, but it
        never unlocks safety or the basic ability to find work.
      </Text>
    </Card>
  );
}

export function AdFreeBadge() {
  const { isAdFree } = useMonetization();
  return isAdFree ? <AppBadge label="Ad-free active" tone="success" /> : <AppBadge label="Ads may appear" tone="warning" />;
}

export function EntitlementBadge({ entitlement, active }: { entitlement: string; active: boolean }) {
  return <AppBadge label={`${entitlement}: ${active ? "active" : "inactive"}`} tone={active ? "success" : "default"} />;
}

export function PlanCard({
  aPackage,
  onPurchase,
  loading
}: {
  aPackage: PurchasesPackage;
  onPurchase: (aPackage: PurchasesPackage) => void;
  loading?: boolean;
}) {
  const { describePackage } = useMonetization();
  const description = aPackage.product.description || "RevenueCat product description is not configured.";
  const display = describePackage(aPackage);
  const priceMissing = display.price === "Price unavailable";

  return (
    <Card>
      <View style={styles.row}>
        <View style={styles.flex}>
          <Text variant="subtitle">{display.name}</Text>
          <Text>{description}</Text>
          <Text color={priceMissing ? colors.warning : colors.primary} variant="label">
            {display.price}
          </Text>
          {priceMissing ? <Text variant="caption">Check the product setup in RevenueCat and App Store Connect.</Text> : null}
        </View>
        <PremiumBadge />
      </View>
      <Button disabled={loading || priceMissing} title={loading ? "Working..." : "Upgrade if you want"} onPress={() => onPurchase(aPackage)} />
    </Card>
  );
}

export function PaywallCard() {
  const { loading, status, error, message, offerings, entitlements, purchasePackage, refresh } = useMonetization();
  const packages = offerings?.current?.availablePackages ?? [];

  return (
    <Card>
      <Text variant="subtitle">Make MORT yours.</Text>
      <Text>
        Free stays useful. Plus just gives you extra style, control, and convenience. Upgrade for perks like ad-free
        browsing, profile polish, advanced filters, portfolio extras, adult job tools, and guardian digests. Safety stays
        free.
      </Text>
      <View style={styles.badgeRow}>
        <EntitlementBadge active={entitlements.premium} entitlement="premium" />
        <EntitlementBadge active={entitlements.adFree} entitlement="ad-free" />
        <EntitlementBadge active={entitlements.adultPro} entitlement="adult pro" />
        <EntitlementBadge active={entitlements.guardianPlus} entitlement="guardian plus" />
      </View>
      {status !== "configured" ? (
        <FeatureLockCard
          title="RevenueCat setup required"
          body={message ?? "Add a platform public SDK key, products, entitlements, and offerings before purchases can run."}
          cta="Setup required"
        />
      ) : null}
      {packages.length === 0 && status === "configured" ? (
        <FeatureLockCard
          title="No offerings returned"
          body="RevenueCat is configured, but the dashboard has not returned an active Offering with packages for this user."
          cta="Dashboard setup"
        />
      ) : null}
      {packages.map((aPackage) => (
        <PlanCard key={aPackage.identifier} aPackage={aPackage} loading={loading} onPurchase={purchasePackage} />
      ))}
      {error ? <Text color={colors.danger}>{error}</Text> : null}
      {message ? <Text color={colors.muted}>{message}</Text> : null}
      <Button title={loading ? "Refreshing..." : "Refresh plans"} variant="secondary" disabled={loading} onPress={refresh} />
      <Button title="Keep using free" variant="secondary" onPress={() => router.back()} />
    </Card>
  );
}

export function RestorePurchasesButton() {
  const { loading, restore } = useMonetization();
  return <Button disabled={loading} title={loading ? "Restoring..." : "Restore purchases"} variant="secondary" onPress={restore} />;
}

export function ManageSubscriptionButton() {
  return (
    <Button
      title="Open Apple subscription settings"
      variant="secondary"
      onPress={() => {
        void Linking.openURL("https://apps.apple.com/account/subscriptions");
      }}
    />
  );
}

export function NativeAdCard({ placement = "profile" }: { placement?: AdPlacement }) {
  const { profile } = useAuth();
  const { isAdFree } = useMonetization();
  const eligibility = evaluateAdEligibility({
    placement,
    format: "native",
    role: profile?.role,
    hasAdFreeEntitlement: isAdFree,
    consentReady: false
  });

  return (
    <FeatureLockCard
      title="Native ad placeholder"
      body={`Native ads are not rendered until consent, ad unit setup, and native iPhone/EAS testing are complete. Current status: ${eligibility.reason}`}
      cta="Ads guarded"
    />
  );
}

export function AdBannerSlot({
  placement,
  showDiagnostics = false
}: {
  placement: AdPlacement;
  showDiagnostics?: boolean;
}) {
  const { profile } = useAuth();
  const { isAdFree } = useMonetization();
  const [nativeReady, setNativeReady] = useState(false);
  const eligibility = evaluateAdEligibility({
    placement,
    format: "banner",
    role: profile?.role,
    hasAdFreeEntitlement: isAdFree,
    consentReady: false
  });
  const unitId = eligibility.allowed ? getAdUnitId("banner") : "";

  useEffect(() => {
    let active = true;
    async function load() {
      if (!eligibility.allowed || Platform.OS === "web") return;
      await initializeAds(profile?.role, null);
      if (active) setNativeReady(true);
    }
    void load();
    return () => {
      active = false;
    };
  }, [eligibility.allowed, profile?.role]);

  if (!eligibility.allowed || !unitId) {
    return showDiagnostics ? <AdDiagnostic reason={eligibility.reason} /> : null;
  }

  if (!nativeReady) {
    return showDiagnostics ? <AdDiagnostic reason="Ad slot eligible; waiting for native ad module." /> : null;
  }

  return (
    <View style={styles.adSlot}>
      {USE_TEST_ADS ? <Text variant="caption">Test ad mode</Text> : null}
      <NativeBannerAd unitId={unitId} requestNonPersonalizedAdsOnly={eligibility.requestNonPersonalizedAdsOnly} />
    </View>
  );
}

export function RewardedAdButton({ placement = "hustle-academy" }: { placement?: AdPlacement }) {
  const { profile } = useAuth();
  const { isAdFree } = useMonetization();
  const eligibility = evaluateAdEligibility({
    placement,
    format: "rewarded",
    role: profile?.role,
    hasAdFreeEntitlement: isAdFree,
    consentReady: false
  });

  return (
    <Button
      disabled
      title={eligibility.allowed ? "Rewarded ad requires EAS testing" : "Rewarded ads unavailable"}
      variant="secondary"
      onPress={() => undefined}
    />
  );
}

export function InterstitialGate({ children, placement }: PropsWithChildren<{ placement: AdPlacement }>) {
  const { profile } = useAuth();
  const { isAdFree } = useMonetization();
  const eligibility = evaluateAdEligibility({
    placement,
    format: "interstitial",
    role: profile?.role,
    hasAdFreeEntitlement: isAdFree,
    consentReady: false
  });

  return (
    <View style={styles.gate}>
      {children}
      {ADS_ENABLED && !eligibility.allowed ? <Text variant="caption">Interstitial skipped: {eligibility.reason}</Text> : null}
    </View>
  );
}

function AdDiagnostic({ reason }: { reason: string }) {
  return (
    <View style={styles.adDiagnostic}>
      <Text variant="caption">Ad slot hidden: {reason}</Text>
    </View>
  );
}

export function MonetizationSafetyStack() {
  return (
    <>
      <GuardianModeBanner />
      <TeenMonetizationSafetyNotice />
      <GuardianPurchaseNotice />
      <MonetizationDisclaimer />
    </>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: spacing.md
  },
  flex: {
    flex: 1,
    gap: spacing.sm
  },
  badgeRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm
  },
  adSlot: {
    alignItems: "center",
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.sm
  },
  adDiagnostic: {
    borderColor: colors.border,
    borderRadius: 8,
    borderStyle: "dashed",
    borderWidth: 1,
    padding: spacing.sm
  },
  gate: {
    gap: spacing.sm
  }
});
