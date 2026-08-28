import { ActivityIndicator } from "react-native";

import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { colors } from "@/lib/theme";

export function GuardedRouteFallback() {
  return (
    <Screen scroll={false}>
      <Text variant="title">Checking access</Text>
      <ActivityIndicator color={colors.primary} />
    </Screen>
  );
}
