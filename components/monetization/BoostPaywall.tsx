import { router } from "expo-router";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppBadge } from "@/components/DesignSystem";
import { Text } from "@/components/Text";

export function BoostPaywall() {
  return (
    <Card>
      <AppBadge label="Adult/business optional" tone="warning" />
      <Text variant="subtitle">Give this job extra visibility.</Text>
      <Text>Boosting never bypasses safety review, verification, or moderation. Unsafe jobs cannot be boosted.</Text>
      <Button title="Review job boost" onPress={() => router.push("/monetization/job-boost" as never)} />
      <Button title="Keep posting normally" variant="secondary" onPress={() => router.back()} />
    </Card>
  );
}
