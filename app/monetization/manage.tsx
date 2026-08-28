import { Card } from "@/components/Card";
import { AppHeader } from "@/components/DesignSystem";
import { ManageSubscriptionButton } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";

export default function ManageSubscriptionScreen() {
  return (
    <Screen>
      <AppHeader title="Manage subscription" subtitle="Manage billing in Apple subscription settings after real products exist." />
      <Card>
        <Text variant="subtitle">Apple subscription settings</Text>
        <Text>
          On iPhone, subscriptions are managed through Apple. This button opens Apple subscription settings in the
          browser/app context when available.
        </Text>
        <ManageSubscriptionButton />
      </Card>
      <Card>
        <Text variant="subtitle">RevenueCat Customer Center</Text>
        <Text>
          RevenueCat Customer Center can be added after the dashboard, products, entitlements, and paywalls are
          configured and tested in an EAS development/preview build.
        </Text>
      </Card>
    </Screen>
  );
}
