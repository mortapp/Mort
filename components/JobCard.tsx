import { Pressable, StyleSheet, View } from "react-native";

import { Card } from "@/components/Card";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { colors, spacing } from "@/lib/theme";
import type { Job } from "@/types/domain";

type JobCardProps = {
  job: Job;
  onPress?: () => void;
};

export function JobCard({ job, onPress }: JobCardProps) {
  const content = (
    <Card>
      <View style={styles.topRow}>
        <Text style={styles.title} variant="subtitle">
          {job.title}
        </Text>
        <StatusPill label={job.status} tone={job.status === "open" ? "success" : "default"} />
      </View>
      <Text color={colors.muted}>{job.location_text}</Text>
      <Text>{job.description}</Text>
      <View style={styles.metaRow}>
        <StatusPill label={job.category} tone="info" />
        <StatusPill label={job.pay_label ?? "Pay discussed in-app"} tone="warning" />
        <StatusPill label={`Ages ${job.teen_min_age}-${job.teen_max_age}`} />
      </View>
    </Card>
  );

  if (!onPress) return content;

  return (
    <Pressable accessibilityRole="button" onPress={onPress}>
      {content}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  topRow: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: spacing.md,
    justifyContent: "space-between"
  },
  title: {
    flex: 1
  },
  metaRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm
  }
});
