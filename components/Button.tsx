import { Pressable, StyleSheet } from "react-native";

import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";

type ButtonProps = {
  title: string;
  onPress: () => void;
  disabled?: boolean;
  variant?: "primary" | "secondary" | "danger";
};

export function Button({ title, onPress, disabled = false, variant = "primary" }: ButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        styles[variant],
        disabled ? styles.disabled : null,
        pressed && !disabled ? styles.pressed : null
      ]}
    >
      <Text color={variant === "secondary" ? colors.primaryDark : "#ffffff"} style={styles.text} variant="label">
        {title}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: "center",
    borderRadius: 8,
    justifyContent: "center",
    minHeight: 48,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md
  },
  primary: {
    backgroundColor: colors.primary
  },
  secondary: {
    borderColor: colors.primary,
    borderWidth: 1,
    backgroundColor: "#10251d"
  },
  danger: {
    backgroundColor: colors.danger
  },
  disabled: {
    opacity: 0.5
  },
  pressed: {
    opacity: 0.82
  },
  text: {
    textAlign: "center"
  }
});
