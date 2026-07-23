import { router } from "expo-router";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppHeader, AppBadge, ActionRow, StatCard } from "@/components/DesignSystem";
import { AdFreeBadge, MonetizationSafetyStack } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import { useMonetization } from "@/providers/MonetizationProvider";

export default function MonetizationHomeScreen() {
  const { profile } = useAuth();
  const { entitlements, status, offerings } = useMonetization();
  const activeCount = Object.values(entitlements).filter(Boolean).length;

  return (
    <Screen>
      <AppHeader
        title="MORT Premium"
        subtitle="Earn nearby. Move smart. Monetization stays teen-safe, transparent, and never paywalls safety."
        right={<AdFreeBadge />}
      />
      <MonetizationSafetyStack />
      <Card>
        <Text variant="subtitle">Your monetization status</Text>
        <AppBadge label={`RevenueCat: ${status}`} tone={status === "configured" ? "success" : "warning"} />
        <Text color={colors.muted}>Role: {profile?.role ?? "signed out"}</Text>
        <StatCard label="Active entitlements" value={activeCount} />
        <StatCard label="Current offering packages" value={offerings?.current?.availablePackages?.length ?? 0} />
      </Card>
      <Card>
        <Text variant="subtitle">Manage</Text>
        <ActionRow
          title="Subscription plans"
          body="Fetches RevenueCat offerings and shows setup-required state if none exist."
          action={<Button title="Open" onPress={() => router.push("/monetization/paywall" as never)} />}
        />
        <ActionRow
          title="Ad-free"
          body="Explains ad removal and teen-safe ad defaults."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/ad-free" as never)} />}
        />
        <ActionRow
          title="Restore purchases"
          body="Required for App Store subscription/IAP flows."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/restore" as never)} />}
        />
        <ActionRow
          title="Manage subscription"
          body="Links to Apple subscription management and setup notes."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/manage" as never)} />}
        />
        <ActionRow
          title="Username token"
          body="3 free lifetime changes, then optional token or Plus allowance."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/username-change" as never)} />}
        />
        <ActionRow
          title="Profile style pack"
          body="Cosmetic profile themes, borders, and accents."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/profile-style-pack" as never)} />}
        />
        <ActionRow
          title="Job boost"
          body="Adult/business visibility that never bypasses safety review."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/job-boost" as never)} />}
        />
      </Card>
      {profile?.role === "admin" ? (
        <Button title="RevenueCat debug" variant="secondary" onPress={() => router.push("/monetization/revenuecat-debug" as never)} />
      ) : null}
    </Screen>
  );
}
