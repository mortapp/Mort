import { Card } from "@/components/Card";
import { AppHeader, AppBadge } from "@/components/DesignSystem";
import { AdBannerSlot, AdFreeBadge, GuardianPurchaseNotice, MonetizationDisclaimer } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";

export default function AdFreeScreen() {
  return (
    <Screen>
      <AppHeader title="Ad-free" subtitle="Ads are disabled by default until consent, EAS testing, and ad units are ready." right={<AdFreeBadge />} />
      <Card>
        <AppBadge label="Fair gating" tone="success" />
        <Text>Ad-free removes ads. It does not unlock safety, basic applications, Guardian Mode, reports, proof basics, or message scanning.</Text>
      </Card>
      <Card>
        <Text variant="subtitle">Allowed ad preview slot</Text>
        <Text>This diagnostic slot is on a non-sensitive screen. With current defaults it stays hidden until ads and consent are enabled.</Text>
        <AdBannerSlot placement="settings" showDiagnostics />
      </Card>
      <GuardianPurchaseNotice />
      <MonetizationDisclaimer />
    </Screen>
  );
}
