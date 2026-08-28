import { Card } from "@/components/Card";
import { AppHeader } from "@/components/DesignSystem";
import { RestorePurchasesButton } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { useMonetization } from "@/providers/MonetizationProvider";

export default function RestorePurchasesScreen() {
  const { error, message, entitlements } = useMonetization();

  return (
    <Screen>
      <AppHeader title="Restore purchases" subtitle="Use this if you bought with the same Apple ID or after reinstalling MORT." />
      <Card>
        <Text variant="subtitle">Restore from RevenueCat</Text>
        <Text>Restore does not create fake access. It asks RevenueCat and the store for real purchase history.</Text>
        <RestorePurchasesButton />
        {message ? <Text>{message}</Text> : null}
        {error ? <Text>{error}</Text> : null}
      </Card>
      <Card>
        <Text variant="subtitle">Current entitlements</Text>
        <Text>Premium: {entitlements.premium ? "active" : "inactive"}</Text>
        <Text>Ad-free: {entitlements.adFree ? "active" : "inactive"}</Text>
        <Text>Adult Pro: {entitlements.adultPro ? "active" : "inactive"}</Text>
        <Text>Guardian Plus: {entitlements.guardianPlus ? "active" : "inactive"}</Text>
      </Card>
    </Screen>
  );
}
