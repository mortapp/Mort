import { router } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listThreadsForUser } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { MessageThread } from "@/types/domain";

export default function AdultMessagesScreen() {
  const { user } = useAuth();
  const [threads, setThreads] = useState<MessageThread[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadThreads() {
      try {
        const rows = await listThreadsForUser(userId, "adult");
        if (!active) return;
        setThreads(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load message threads.");
      }
    }

    void loadThreads();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Safe chat</Text>
      <ErrorBanner message={error} />
      {threads.length === 0 ? <EmptyState title="No threads" body="Threads are created when teens apply to your jobs." /> : null}
      {threads.map((thread) => (
        <Card key={thread.id}>
          <Text variant="subtitle">Application thread</Text>
          <Text variant="caption">{thread.application_id}</Text>
          <Button title="Open chat" onPress={() => router.push(`/messages/${thread.id}` as never)} />
        </Card>
      ))}
    </Screen>
  );
}
