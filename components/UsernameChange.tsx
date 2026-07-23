import { useState } from "react";
import { View, StyleSheet } from "react-native";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppBadge, AppInput, ProgressBar } from "@/components/DesignSystem";
import { Text } from "@/components/Text";
import type { UsernameChangeStatus } from "@/lib/data";
import { colors, spacing } from "@/lib/theme";

export function UsernameChangeMeter({ status }: { status: UsernameChangeStatus | null }) {
  const used = status?.free_changes_used ?? 0;
  const remaining = status?.free_changes_remaining ?? 3;

  return (
    <Card>
      <AppBadge label="3 free lifetime changes" tone={remaining > 0 ? "success" : "warning"} />
      <Text variant="subtitle">Username changes</Text>
      <Text>{remaining} free changes remaining.</Text>
      <ProgressBar label="Free allowance used" value={Math.round((used / 3) * 100)} />
      <Text variant="caption">Plus can include 1 extra monthly change. Tokens can add one more optional change.</Text>
    </Card>
  );
}

export function UsernameChangeForm({
  busy,
  onSubmit
}: {
  busy: boolean;
  onSubmit: (username: string) => Promise<void>;
}) {
  const [username, setUsername] = useState("");

  return (
    <Card>
      <Text variant="subtitle">Choose a new username</Text>
      <AppInput
        autoCapitalize="none"
        autoCorrect={false}
        label="Username"
        onChangeText={setUsername}
        placeholder="nearby_hustler"
        value={username}
      />
      <Text variant="caption">
        Usernames cannot include contact info, payment handles, offensive words, or impersonation terms like admin or
        support.
      </Text>
      <Button disabled={busy || username.trim().length < 3} title={busy ? "Saving..." : "Save username"} onPress={() => onSubmit(username)} />
    </Card>
  );
}

export function UsernameChangeHistory({
  events
}: {
  events: { id: string; new_username: string; old_username: string | null; source: string; created_at: string }[];
}) {
  return (
    <Card>
      <Text variant="subtitle">Username history</Text>
      {events.length === 0 ? <Text color={colors.muted}>No username changes yet.</Text> : null}
      <View style={styles.stack}>
        {events.map((event) => (
          <View key={event.id} style={styles.historyRow}>
            <Text variant="label">@{event.new_username}</Text>
            <Text variant="caption">
              {event.source.replace("_", " ")} - {new Date(event.created_at).toLocaleDateString()}
            </Text>
          </View>
        ))}
      </View>
    </Card>
  );
}

export function UsernameChangeLimitCard({ status }: { status: UsernameChangeStatus | null }) {
  const hasAvailable =
    (status?.free_changes_remaining ?? 3) > 0 ||
    (status?.token_credits ?? 0) > 0 ||
    (status?.admin_credits ?? 0) > 0 ||
    Boolean(status?.plus_allowance_available);

  if (hasAvailable) return null;

  return (
    <Card>
      <AppBadge label="Optional token" tone="warning" />
      <Text variant="subtitle">You used your 3 free username changes.</Text>
      <Text>Need another one? Use Plus monthly allowance, an admin-approved credit, or a username token.</Text>
    </Card>
  );
}

export function UsernameTokenPurchaseCard() {
  return (
    <Card>
      <AppBadge label="Suggested $1.99 setup" tone="info" />
      <Text variant="subtitle">Username Change Token</Text>
      <Text>One optional extra username change. Actual checkout price must come from RevenueCat/App Store Connect.</Text>
      <Button disabled title="Buy token after RevenueCat setup" onPress={() => undefined} />
    </Card>
  );
}

const styles = StyleSheet.create({
  stack: {
    gap: spacing.sm
  },
  historyRow: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.xs,
    padding: spacing.md
  }
});
