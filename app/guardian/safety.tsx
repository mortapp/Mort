import { useEffect, useState } from "react";

import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listSafetyPings } from "@/lib/data";
import { EMERGENCY_DISCLAIMER, SAFETY_DISCLAIMER } from "@/lib/disclaimers";
import { useAuth } from "@/providers/AuthProvider";
import type { SafetyPing } from "@/types/domain";

export default function GuardianSafetyScreen() {
  const { user } = useAuth();
  const [pings, setPings] = useState<SafetyPing[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadPings() {
      try {
        const rows = await listSafetyPings(userId, "guardian");
        if (!active) return;
        setPings(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load safety pings.");
      }
    }

    void loadPings();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Safety pings</Text>
      <Text>{SAFETY_DISCLAIMER}</Text>
      <Text>{EMERGENCY_DISCLAIMER}</Text>
      <ErrorBanner message={error} />
      {pings.length === 0 ? <EmptyState title="No safety pings" body="Connected teen check-ins will appear here." /> : null}
      {pings.map((ping) => (
        <Card key={ping.id}>
          <StatusPill label={ping.status} tone={ping.status === "ok" ? "success" : "danger"} />
          <Text>{ping.note || "No note"}</Text>
          <Text variant="caption">{new Date(ping.created_at).toLocaleString()}</Text>
        </Card>
      ))}
    </Screen>
  );
}
