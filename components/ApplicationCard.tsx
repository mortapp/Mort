import { StyleSheet, View } from "react-native";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";
import type { Application } from "@/types/domain";

type ApplicationCardProps = {
  application: Application;
  primaryAction?: {
    title: string;
    onPress: () => void;
    disabled?: boolean;
  };
  secondaryAction?: {
    title: string;
    onPress: () => void;
    disabled?: boolean;
  };
  tertiaryAction?: {
    title: string;
    onPress: () => void;
    disabled?: boolean;
  };
};

export function ApplicationCard({ application, primaryAction, secondaryAction, tertiaryAction }: ApplicationCardProps) {
  return (
    <Card>
      <View style={styles.row}>
        <Text style={styles.title} variant="subtitle">
          {application.jobs?.title ?? "Application"}
        </Text>
        <StatusPill label={application.status} tone={toneForStatus(application.status)} />
      </View>
      <Text color={colors.muted}>{application.jobs?.location_text ?? "Location hidden"}</Text>
      {application.profiles?.display_name ? <Text>Teen: {application.profiles.display_name}</Text> : null}
      {application.note ? <Text>{application.note}</Text> : null}
      <View style={styles.actions}>
        {tertiaryAction ? <Button disabled={tertiaryAction.disabled} title={tertiaryAction.title} variant="secondary" onPress={tertiaryAction.onPress} /> : null}
        {secondaryAction ? <Button disabled={secondaryAction.disabled} title={secondaryAction.title} variant="secondary" onPress={secondaryAction.onPress} /> : null}
        {primaryAction ? <Button disabled={primaryAction.disabled} title={primaryAction.title} onPress={primaryAction.onPress} /> : null}
      </View>
    </Card>
  );
}

function toneForStatus(status: Application["status"]) {
  if (status === "accepted" || status === "completed") return "success";
  if (status.includes("rejected") || status === "disputed") return "danger";
  if (status.includes("pending") || status === "adult_review") return "warning";
  return "info";
}

const styles = StyleSheet.create({
  row: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: spacing.md,
    justifyContent: "space-between"
  },
  title: {
    flex: 1
  },
  actions: {
    gap: spacing.sm
  }
});
