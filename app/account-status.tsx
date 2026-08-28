import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { accountStatusLabel } from "@/lib/account";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";

export default function AccountStatusScreen() {
  const { profile, signOut } = useAuth();

  return (
    <Screen>
      <Text variant="title">Account status</Text>
      <Card>
        <StatusPill label={accountStatusLabel(profile)} tone="danger" />
        <Text>
          MORT may restrict accounts for safety, moderation, or policy reasons. If this looks wrong, contact MORT support from
          the email address on your account.
        </Text>
        <Text color={colors.muted}>
          If you are in immediate danger, contact local emergency services.
        </Text>
        <Button title="Sign out" variant="secondary" onPress={signOut} />
      </Card>
    </Screen>
  );
}
