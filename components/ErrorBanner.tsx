import { StyleSheet, View } from "react-native";

import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";

export function ErrorBanner({ message }: { message: string | null }) {
  if (!message) return null;

  return (
    <View style={styles.banner}>
      <Text color={colors.danger}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: {
    borderColor: "#7f1d1d",
    borderRadius: 8,
    borderWidth: 1,
    backgroundColor: "#2a0f18",
    padding: spacing.md
  }
});
