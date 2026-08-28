import { StyleSheet, View } from "react-native";

import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";

type Tone = "default" | "success" | "warning" | "danger" | "info";

const tones: Record<Tone, { bg: string; fg: string }> = {
  default: { bg: "#1f2937", fg: colors.text },
  success: { bg: "#0b2a1a", fg: colors.success },
  warning: { bg: "#2d1f0b", fg: colors.warning },
  danger: { bg: "#2a0f18", fg: colors.danger },
  info: { bg: "#0d2033", fg: colors.info }
};

export function StatusPill({ label, tone = "default" }: { label: string; tone?: Tone }) {
  return (
    <View style={[styles.pill, { backgroundColor: tones[tone].bg }]}>
      <Text color={tones[tone].fg} variant="caption">
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    alignSelf: "flex-start",
    borderRadius: 999,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs
  }
});
