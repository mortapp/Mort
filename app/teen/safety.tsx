import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { createGuardianInvite, createSafetyPing, getActiveGuardianForTeen, listSafetyPings } from "@/lib/data";
import { EMERGENCY_DISCLAIMER, SAFETY_DISCLAIMER } from "@/lib/disclaimers";
import { scheduleSafetyReminder } from "@/lib/notifications";
import { useAuth } from "@/providers/AuthProvider";
import type { GuardianConnection, SafetyPing } from "@/types/domain";

export default function TeenSafetyScreen() {
  const { user } = useAuth();
  const [note, setNote] = useState("");
  const [inviteCode, setInviteCode] = useState<string | null>(null);
  const [guardian, setGuardian] = useState<GuardianConnection | null>(null);
  const [pings, setPings] = useState<SafetyPing[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    if (!user) return;
    try {
      const [nextGuardian, nextPings] = await Promise.all([getActiveGuardianForTeen(user.id), listSafetyPings(user.id, "teen")]);
      setGuardian(nextGuardian);
      setPings(nextPings);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load safety data.");
    }
  }

  async function ping(status: SafetyPing["status"]) {
    if (!user) return;
    setError(null);
    try {
      await createSafetyPing({
        teenId: user.id,
        guardianId: guardian?.guardian_id ?? null,
        status,
        note
      });
      await scheduleSafetyReminder();
      setNote("");
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create safety ping.");
    }
  }

  async function invite() {
    setError(null);
    try {
      setInviteCode(await createGuardianInvite());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create guardian invite.");
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadSafetyData() {
      try {
        const [nextGuardian, nextPings] = await Promise.all([getActiveGuardianForTeen(userId), listSafetyPings(userId, "teen")]);
        if (!active) return;
        setGuardian(nextGuardian);
        setPings(nextPings);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load safety data.");
      }
    }

    void loadSafetyData();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Safety</Text>
      <Text>{SAFETY_DISCLAIMER}</Text>
      <Text>{EMERGENCY_DISCLAIMER}</Text>
      <ErrorBanner message={error} />
      <Card>
        <Text variant="subtitle">Guardian</Text>
        {guardian ? <StatusPill label="Guardian connected" tone="success" /> : <StatusPill label="No active guardian" tone="warning" />}
        {inviteCode ? <Text variant="subtitle">Invite code: {inviteCode}</Text> : null}
        <Button title="Create guardian invite" variant="secondary" onPress={invite} />
      </Card>
      <Card>
        <Text variant="subtitle">Safety ping</Text>
        <Field label="Optional note" multiline onChangeText={setNote} value={note} />
        <Button title="I'm OK" onPress={() => ping("ok")} />
        <Button title="I need help" variant="danger" onPress={() => ping("needs_help")} />
      </Card>
      {pings.length === 0 ? <EmptyState title="No pings yet" body="Use a safety ping when a job starts, ends, or anything feels uncomfortable." /> : null}
      {pings.map((item) => (
        <Card key={item.id}>
          <StatusPill label={item.status} tone={item.status === "ok" ? "success" : "danger"} />
          <Text>{item.note || "No note"}</Text>
          <Text variant="caption">{new Date(item.created_at).toLocaleString()}</Text>
        </Card>
      ))}
    </Screen>
  );
}
