import type { PropsWithChildren } from "react";
import { StyleSheet, View } from "react-native";

import { colors, spacing } from "@/lib/theme";

export function Card({ children }: PropsWithChildren) {
  return <View style={styles.card}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    gap: spacing.md,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    backgroundColor: colors.surface,
    padding: spacing.lg
  }
});
