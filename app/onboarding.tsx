import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { useAuth } from "@/providers/AuthProvider";

export default function OnboardingScreen() {
  const { signOut } = useAuth();

  return (
    <Screen>
      <Text variant="title">MORT reference client</Text>
      <Card>
        <Text variant="subtitle">Onboarding is unavailable here</Text>
        <Text>
          This Expo project is retained as a development reference. The supported
          MORT app completes onboarding through the server-authoritative Flutter
          flow.
        </Text>
      </Card>
      <Button title="Sign out" variant="secondary" onPress={signOut} />
    </Screen>
  );
}
