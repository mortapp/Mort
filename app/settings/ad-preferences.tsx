import { Card } from "@/components/Card";
import { AppBadge, AppHeader, FeatureLockCard } from "@/components/DesignSystem";
import { AdBannerSlot, AdFreeBadge, MonetizationDisclaimer, TeenMonetizationSafetyNotice } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { ADS_ENABLED, USE_TEST_ADS } from "@/lib/env";
import { useAuth } from "@/providers/AuthProvider";

export default function AdPreferencesScreen() {
  const { profile } = useAuth();
  const teenOrUnknown = profile?.role === "teen" || !profile?.role;

  return (
    <Screen>
      <AppHeader title="Ad preferences" subtitle="Ad settings stay conservative until consent and legal review are complete." right={<AdFreeBadge />} />
      <Card>
        <AppBadge label={ADS_ENABLED ? "Ads enabled in build" : "Ads disabled in build"} tone={ADS_ENABLED ? "warning" : "success"} />
        <Text>Test ads: {USE_TEST_ADS ? "on" : "off"}</Text>
        <Text>Role treatment: {teenOrUnknown ? "teen/unknown conservative" : "adult/guardian/admin"}</Text>
      </Card>
      <TeenMonetizationSafetyNotice />
      <FeatureLockCard
        title="Consent controls coming after UMP/ATT setup"
        body="Personalized ad consent, privacy messaging, and ATT prompts must be configured in AdMob/App Store review before these controls are active."
        cta="Coming later"
      />
      <Card>
        <Text variant="subtitle">Safe diagnostic ad slot</Text>
        <AdBannerSlot placement="settings" showDiagnostics />
      </Card>
      <MonetizationDisclaimer />
    </Screen>
  );
}
