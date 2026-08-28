import { StyleSheet, TextInput, type TextInputProps, View } from "react-native";

import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";

type FieldProps = TextInputProps & {
  label: string;
};

export function Field({ label, style, ...props }: FieldProps) {
  return (
    <View style={styles.wrap}>
      <Text variant="label">{label}</Text>
      <TextInput
        {...props}
        placeholderTextColor={colors.muted}
        style={[styles.input, props.multiline ? styles.multiline : null, style]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: spacing.sm
  },
  input: {
    minHeight: 48,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    backgroundColor: "#0b1220",
    color: colors.text,
    fontSize: 16,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm
  },
  multiline: {
    minHeight: 110,
    textAlignVertical: "top"
  }
});
