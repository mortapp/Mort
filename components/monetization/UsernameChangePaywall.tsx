import { router } from "expo-router";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppBadge } from "@/components/DesignSystem";
import { Text } from "@/components/Text";

export function UsernameChangePaywall() {
  return (
    <Card>
      <AppBadge label="Optional perk" tone="info" />
      <Text variant="subtitle">You used your 3 free username changes.</Text>
      <Text>Need another one? Grab a cheap username change token.</Text>
      <Text>Changing your name is optional. Your account still works.</Text>
      <Button title="View username token" onPress={() => router.push("/monetization/username-change" as never)} />
      <Button title="Keep using free" variant="secondary" onPress={() => router.back()} />
    </Card>
  );
}
