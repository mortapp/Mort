import { router } from "expo-router";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ActionRow, AppHeader } from "@/components/DesignSystem";
import { AdFreeBadge, MonetizationSafetyStack } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { useMonetization } from "@/providers/MonetizationProvider";

export default function SubscriptionSettingsScreen() {
  const { entitlements, status } = useMonetization();

  return (
    <Screen>
      <AppHeader title="Subscription" subtitle="Premium convenience controls, never safety paywalls." right={<AdFreeBadge />} />
      <Card>
        <Text variant="subtitle">Status</Text>
        <Text>RevenueCat: {status}</Text>
        <Text>Premium: {entitlements.premium ? "active" : "inactive"}</Text>
        <Text>Ad-free: {entitlements.adFree ? "active" : "inactive"}</Text>
        <Text>Adult Pro: {entitlements.adultPro ? "active" : "inactive"}</Text>
        <Text>Guardian Plus: {entitlements.guardianPlus ? "active" : "inactive"}</Text>
      </Card>
      <Card>
        <ActionRow title="View plans" action={<Button title="Open" onPress={() => router.push("/monetization/paywall" as never)} />} />
        <ActionRow
          title="Restore purchases"
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/restore" as never)} />}
        />
        <ActionRow
          title="Manage subscription"
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/manage" as never)} />}
        />
        <ActionRow
          title="Username settings"
          body="See free changes, credits, and username history."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/settings/username" as never)} />}
        />
        <ActionRow
          title="Profile style pack"
          body="Cosmetic-only profile upgrades."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/profile-style-pack" as never)} />}
        />
      </Card>
      <MonetizationSafetyStack />
    </Screen>
  );
}
