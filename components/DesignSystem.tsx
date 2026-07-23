import type { PropsWithChildren, ReactNode } from "react";
import { Modal, Pressable, StyleSheet, TextInput, View, type TextInputProps } from "react-native";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { PAYMENT_DISCLAIMER, VERIFICATION_DISCLAIMER } from "@/lib/disclaimers";
import { colors, spacing } from "@/lib/theme";

export const AppScreen = Screen;
export const AppCard = Card;
export const AppButton = Button;

export function AppHeader({ title, subtitle, right }: { title: string; subtitle?: string; right?: ReactNode }) {
  return (
    <View style={styles.header}>
      <View style={styles.headerText}>
        <Text variant="title">{title}</Text>
        {subtitle ? <Text color={colors.muted}>{subtitle}</Text> : null}
      </View>
      {right ? <View style={styles.headerRight}>{right}</View> : null}
    </View>
  );
}

export function AppInput({ label, ...props }: TextInputProps & { label: string }) {
  return (
    <View style={styles.field}>
      <Text variant="label">{label}</Text>
      <TextInput
        {...props}
        placeholderTextColor={colors.muted}
        style={[styles.input, props.multiline ? styles.multiline : null, props.style]}
      />
    </View>
  );
}

export function AppTextArea(props: TextInputProps & { label: string }) {
  return <AppInput {...props} multiline textAlignVertical="top" />;
}

export function AppSelect<T extends string>({
  label,
  options,
  value,
  onChange
}: {
  label: string;
  options: { label: string; value: T }[];
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <View style={styles.field}>
      <Text variant="label">{label}</Text>
      <View style={styles.optionWrap}>
        {options.map((option) => (
          <Pressable
            key={option.value}
            accessibilityRole="button"
            onPress={() => onChange(option.value)}
            style={[styles.option, option.value === value ? styles.optionSelected : null]}
          >
            <Text variant="label">{option.label}</Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

export function AppBadge({ label, tone = "default" }: { label: string; tone?: "default" | "success" | "warning" | "danger" | "info" }) {
  return (
    <View style={[styles.badge, styles[`${tone}Badge`]]}>
      <Text variant="caption">{label}</Text>
    </View>
  );
}

export function AppAvatar({ label }: { label: string }) {
  const initials = label
    .split(/\s+/)
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <View style={styles.avatar}>
      <Text variant="label">{initials || "M"}</Text>
    </View>
  );
}

export function AppToast({ message, tone = "info" }: { message: string; tone?: "info" | "success" | "warning" | "danger" }) {
  return (
    <View style={[styles.toast, styles[`${tone}Toast`]]}>
      <Text variant="label">{message}</Text>
    </View>
  );
}

export function LoadingState({ title = "Loading" }: { title?: string }) {
  return (
    <Card>
      <Text variant="subtitle">{title}</Text>
      <Text color={colors.muted}>Checking the latest MORT data.</Text>
    </Card>
  );
}

export function ErrorState({ title = "Something went wrong", body }: { title?: string; body: string }) {
  return (
    <Card>
      <AppBadge label="Error" tone="danger" />
      <Text variant="subtitle">{title}</Text>
      <Text>{body}</Text>
    </Card>
  );
}

export function EmptyState({ title = "Nothing here yet", body }: { title?: string; body: string }) {
  return (
    <Card>
      <AppBadge label="Empty" tone="info" />
      <Text variant="subtitle">{title}</Text>
      <Text>{body}</Text>
    </Card>
  );
}

export function SkeletonCard() {
  return (
    <Card>
      <View style={styles.skeletonWide} />
      <View style={styles.skeletonNarrow} />
    </Card>
  );
}

export function SafetyBanner({ children }: PropsWithChildren) {
  return (
    <View style={styles.safetyBanner}>
      <Text variant="label">Safety stays free</Text>
      <Text>{children}</Text>
    </View>
  );
}

export function PaymentDisclaimer() {
  return (
    <Card>
      <Text variant="subtitle">Payment preference only</Text>
      <Text>{PAYMENT_DISCLAIMER}</Text>
    </Card>
  );
}

export function VerificationDisclaimer() {
  return (
    <Card>
      <Text variant="subtitle">Verification note</Text>
      <Text>{VERIFICATION_DISCLAIMER}</Text>
    </Card>
  );
}

export function GuardianModeBanner() {
  return (
    <SafetyBanner>
      Guardian Mode, Safety Ping, reporting, blocking, proof basics, and message scanning are never paywalled.
    </SafetyBanner>
  );
}

export function FeatureLockCard({ title, body, cta = "Coming later" }: { title: string; body: string; cta?: string }) {
  return (
    <Card>
      <AppBadge label={cta} tone="warning" />
      <Text variant="subtitle">{title}</Text>
      <Text>{body}</Text>
      <Button disabled title={cta} onPress={() => undefined} />
    </Card>
  );
}

export function PremiumBadge() {
  return <AppBadge label="Premium" tone="success" />;
}

export function JobStatusBadge({ status }: { status: string }) {
  const tone = status === "open" ? "success" : status === "removed" ? "danger" : "warning";
  return <AppBadge label={status} tone={tone} />;
}

export function UserTrustBadge({ label = "MORT trust checked" }: { label?: string }) {
  return <AppBadge label={label} tone="info" />;
}

export function CategoryPill({ label }: { label: string }) {
  return <AppBadge label={label} />;
}

export function ProfileCompletionMeter({ percent }: { percent: number }) {
  const clamped = Math.max(0, Math.min(100, percent));
  return (
    <View style={styles.field}>
      <Text variant="label">Profile strength {clamped}%</Text>
      <View style={styles.meterTrack}>
        <View style={[styles.meterFill, { width: `${clamped}%` }]} />
      </View>
    </View>
  );
}

export function ProgressBar({ label, value }: { label: string; value: number }) {
  const clamped = Math.max(0, Math.min(100, value));
  return (
    <View style={styles.field}>
      <Text variant="label">
        {label} {clamped}%
      </Text>
      <View style={styles.meterTrack}>
        <View style={[styles.meterFill, { width: `${clamped}%` }]} />
      </View>
    </View>
  );
}

export function Stepper({
  label,
  value,
  min = 0,
  max = 99,
  onChange
}: {
  label: string;
  value: number;
  min?: number;
  max?: number;
  onChange: (value: number) => void;
}) {
  return (
    <View style={styles.stepper}>
      <Text variant="label">{label}</Text>
      <View style={styles.stepperControls}>
        <Button disabled={value <= min} title="-" variant="secondary" onPress={() => onChange(Math.max(min, value - 1))} />
        <Text variant="subtitle">{value}</Text>
        <Button disabled={value >= max} title="+" variant="secondary" onPress={() => onChange(Math.min(max, value + 1))} />
      </View>
    </View>
  );
}

export function ConfirmationModal({
  visible,
  title,
  body,
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  onConfirm,
  onCancel
}: {
  visible: boolean;
  title: string;
  body: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Modal animationType="fade" transparent visible={visible} onRequestClose={onCancel}>
      <View style={styles.modalBackdrop}>
        <View style={styles.modalCard}>
          <Text variant="subtitle">{title}</Text>
          <Text>{body}</Text>
          <View style={styles.modalActions}>
            <Button title={cancelLabel} variant="secondary" onPress={onCancel} />
            <Button title={confirmLabel} onPress={onConfirm} />
          </View>
        </View>
      </View>
    </Modal>
  );
}

export function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <Card>
      <Text variant="caption">{label}</Text>
      <Text variant="subtitle">{value}</Text>
    </Card>
  );
}

export function ActionRow({ title, body, action }: { title: string; body?: string; action?: ReactNode }) {
  return (
    <View style={styles.actionRow}>
      <View style={styles.actionText}>
        <Text variant="label">{title}</Text>
        {body ? <Text variant="caption">{body}</Text> : null}
      </View>
      {action}
    </View>
  );
}

export function NotificationBell({ unreadCount = 0 }: { unreadCount?: number }) {
  return (
    <View style={styles.bell}>
      <Text variant="label">Alerts</Text>
      {unreadCount > 0 ? <AppBadge label={String(unreadCount)} tone="info" /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: spacing.md,
    justifyContent: "space-between"
  },
  headerText: {
    flex: 1,
    gap: spacing.sm
  },
  headerRight: {
    alignItems: "flex-end"
  },
  field: {
    gap: spacing.sm
  },
  input: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    color: colors.text,
    minHeight: 48,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm
  },
  multiline: {
    minHeight: 110
  },
  optionWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm
  },
  option: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm
  },
  optionSelected: {
    borderColor: colors.primary,
    backgroundColor: "#10251d"
  },
  badge: {
    alignSelf: "flex-start",
    borderColor: colors.border,
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs
  },
  defaultBadge: {
    backgroundColor: colors.surfaceElevated
  },
  successBadge: {
    borderColor: colors.success,
    backgroundColor: "#10351f"
  },
  warningBadge: {
    borderColor: colors.warning,
    backgroundColor: "#32250f"
  },
  dangerBadge: {
    borderColor: colors.danger,
    backgroundColor: "#35131b"
  },
  infoBadge: {
    borderColor: colors.info,
    backgroundColor: "#102a36"
  },
  avatar: {
    alignItems: "center",
    borderColor: colors.primary,
    borderRadius: 28,
    borderWidth: 1,
    height: 56,
    justifyContent: "center",
    width: 56
  },
  toast: {
    borderRadius: 8,
    padding: spacing.md
  },
  infoToast: {
    backgroundColor: "#102a36"
  },
  successToast: {
    backgroundColor: "#10351f"
  },
  warningToast: {
    backgroundColor: "#32250f"
  },
  dangerToast: {
    backgroundColor: "#35131b"
  },
  skeletonWide: {
    height: 18,
    borderRadius: 8,
    backgroundColor: colors.surfaceElevated,
    width: "84%"
  },
  skeletonNarrow: {
    height: 18,
    borderRadius: 8,
    backgroundColor: colors.surfaceElevated,
    width: "54%"
  },
  safetyBanner: {
    borderColor: colors.success,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.sm,
    backgroundColor: "#10351f",
    padding: spacing.lg
  },
  meterTrack: {
    height: 10,
    borderRadius: 999,
    backgroundColor: colors.surfaceElevated,
    overflow: "hidden"
  },
  meterFill: {
    height: "100%",
    backgroundColor: colors.primary
  },
  actionRow: {
    alignItems: "center",
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    flexDirection: "row",
    gap: spacing.md,
    justifyContent: "space-between",
    padding: spacing.md
  },
  actionText: {
    flex: 1,
    gap: spacing.xs
  },
  bell: {
    alignItems: "center",
    flexDirection: "row",
    gap: spacing.sm
  },
  stepper: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.md
  },
  stepperControls: {
    alignItems: "center",
    flexDirection: "row",
    gap: spacing.md
  },
  modalBackdrop: {
    alignItems: "center",
    backgroundColor: "rgba(0,0,0,0.72)",
    flex: 1,
    justifyContent: "center",
    padding: spacing.lg
  },
  modalCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.md,
    maxWidth: 420,
    padding: spacing.lg,
    width: "100%"
  },
  modalActions: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
    justifyContent: "flex-end"
  }
});
