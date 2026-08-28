import type { PropsWithChildren } from "react";
import { StyleSheet, Text as RNText, type TextProps } from "react-native";

import { colors } from "@/lib/theme";

type AppTextProps = PropsWithChildren<
  TextProps & {
    variant?: "title" | "subtitle" | "body" | "caption" | "label";
    color?: string;
  }
>;

export function Text({ children, variant = "body", color, style, ...props }: AppTextProps) {
  return (
    <RNText {...props} style={[styles.base, styles[variant], color ? { color } : null, style]}>
      {children}
    </RNText>
  );
}

const styles = StyleSheet.create({
  base: {
    color: colors.text
  },
  title: {
    fontSize: 28,
    fontWeight: "800",
    lineHeight: 34
  },
  subtitle: {
    fontSize: 20,
    fontWeight: "700",
    lineHeight: 26
  },
  body: {
    fontSize: 16,
    lineHeight: 23
  },
  caption: {
    color: colors.muted,
    fontSize: 13,
    lineHeight: 18
  },
  label: {
    fontSize: 14,
    fontWeight: "700",
    lineHeight: 18
  }
});
