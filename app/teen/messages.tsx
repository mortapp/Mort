import { router } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listThreadsForUser } from "@/lib/data";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import type { MessageThread } from "@/types/domain";

export default function TeenMessagesScreen() {
  const { user } = useAuth();
  const [threads, setThreads] = useState<MessageThread[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadThreads() {
      try {
        const rows = await listThreadsForUser(userId, "teen");
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
      <Text color={colors.muted}>Messages are scanned server-side before they are saved.</Text>
      <ErrorBanner message={error} />
      {threads.length === 0 ? <EmptyState title="No threads" body="Threads are created when you apply for jobs." /> : null}
      {threads.map((thread) => (
        <Card key={thread.id}>
          <Text variant="subtitle">Job thread</Text>
          <Text variant="caption">Application: {thread.application_id ?? "not attached"}</Text>
          <Button title="Open chat" onPress={() => router.push(`/messages/${thread.id}` as never)} />
        </Card>
      ))}
    </Screen>
  );
}
