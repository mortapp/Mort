import { router } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ActionRow, AppBadge } from "@/components/DesignSystem";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { acceptGuardianInvite, listGuardianConnections, setTeenPause } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { GuardianConnection } from "@/types/domain";

export default function GuardianTeensScreen() {
  const { user } = useAuth();
  const [inviteCode, setInviteCode] = useState("");
  const [pauseReason, setPauseReason] = useState("");
  const [connections, setConnections] = useState<GuardianConnection[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyTeenId, setBusyTeenId] = useState<string | null>(null);

  async function acceptInvite() {
    if (!user) return;
    try {
      await acceptGuardianInvite(inviteCode);
      setInviteCode("");
      setConnections(await listGuardianConnections(user.id, "guardian"));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to accept invite.");
    }
  }

  async function togglePause(connection: GuardianConnection, paused: boolean) {
    setBusyTeenId(connection.teen_id);
    setError(null);
    try {
      await setTeenPause(connection.teen_id, paused, paused ? pauseReason : "");
      if (user) {
        setConnections(await listGuardianConnections(user.id, "guardian"));
      }
      if (!paused) setPauseReason("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update teen activity.");
    } finally {
      setBusyTeenId(null);
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadConnections() {
      try {
        const rows = await listGuardianConnections(userId, "guardian");
        if (!active) return;
        setConnections(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load teen connections.");
      }
    }

    void loadConnections();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Supervised teens</Text>
      <Card>
        <Text variant="subtitle">Accept invite</Text>
        <Field autoCapitalize="characters" label="Teen invite code" onChangeText={setInviteCode} value={inviteCode} />
        <Button disabled={!inviteCode} title="Connect teen" onPress={acceptInvite} />
      </Card>
      <Card>
        <Text variant="subtitle">Guardian Mode controls</Text>
        <Text>Pause teen activity if something feels unsafe. Paused teens cannot apply or send messages until resumed.</Text>
        <Field label="Pause reason" maxLength={240} onChangeText={setPauseReason} value={pauseReason} />
      </Card>
      <Card>
        <Text variant="subtitle">Guardian Plus preview</Text>
        <AppBadge label="Safety basics stay free" tone="success" />
        <Text>Weekly digests, multi-teen summaries, and richer timelines are premium-planned convenience features.</Text>
        <ActionRow
          title="Subscription settings"
          body="Review Guardian Plus without paywalling approvals or Safety Ping."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/settings/subscription" as never)} />}
        />
      </Card>
      <ErrorBanner message={error} />
      {connections.length === 0 ? <EmptyState title="No connected teens" body="Ask a teen to create a guardian invite from their Safety tab." /> : null}
      {connections.map((connection) => (
        <Card key={connection.id}>
          <Text variant="subtitle">Teen connection</Text>
          <StatusPill label={connection.status} tone={connection.status === "active" ? "success" : "warning"} />
          <StatusPill
            label={connection.teen_profiles?.paused_by_guardian ? "Activity paused" : "Activity active"}
            tone={connection.teen_profiles?.paused_by_guardian ? "danger" : "success"}
          />
          <Text variant="caption">Teen id: {connection.teen_id}</Text>
          {connection.teen_profiles?.pause_reason ? <Text variant="caption">Pause reason: {connection.teen_profiles.pause_reason}</Text> : null}
          {connection.teen_profiles?.paused_by_guardian ? (
            <Button
              disabled={busyTeenId === connection.teen_id}
              title={busyTeenId === connection.teen_id ? "Updating..." : "Resume teen activity"}
              onPress={() => togglePause(connection, false)}
            />
          ) : (
            <Button
              disabled={busyTeenId === connection.teen_id || !pauseReason.trim()}
              title={busyTeenId === connection.teen_id ? "Updating..." : "Pause teen activity"}
              variant="danger"
              onPress={() => togglePause(connection, true)}
            />
          )}
        </Card>
      ))}
    </Screen>
  );
}
