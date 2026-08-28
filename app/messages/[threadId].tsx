import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listMessages, sendMessage } from "@/lib/data";
import { scanMessageBody } from "@/lib/safety";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import type { Message } from "@/types/domain";

export default function MessageThreadScreen() {
  const { threadId } = useLocalSearchParams<{ threadId: string }>();
  const { user } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [body, setBody] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    if (!threadId) return;
    const scan = scanMessageBody(body);
    if (scan.status === "blocked") {
      setError(scan.reason ?? "Message was blocked by safety scanner.");
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await sendMessage(threadId, body);
      setBody("");
      setMessages(await listMessages(threadId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to send message.");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    if (!threadId) return;
    let active = true;

    async function loadMessages() {
      try {
        const rows = await listMessages(threadId);
        if (!active) return;
        setMessages(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load messages.");
      }
    }

    void loadMessages();

    return () => {
      active = false;
    };
  }, [threadId]);

  return (
    <Screen>
      <Text variant="title">Safe chat</Text>
      <Text color={colors.muted}>Keep communication on MORT. Do not share phone numbers, social media, exact home addresses, or payment details in chat.</Text>
      <ErrorBanner message={error} />
      {messages.map((message) => (
        <Card key={message.id}>
          <StatusPill label={message.sender_id === user?.id ? "You" : "Other user"} tone={message.sender_id === user?.id ? "success" : "info"} />
          <Text>{message.body}</Text>
          <Text variant="caption">{new Date(message.created_at).toLocaleString()}</Text>
          {message.sender_id !== user?.id ? (
            <Button
              title="Report message"
              variant="secondary"
              onPress={() => router.push(`/report/${message.sender_id}?messageId=${message.id}` as never)}
            />
          ) : null}
        </Card>
      ))}
      <Card>
        <Field label="Message" multiline onChangeText={setBody} value={body} />
        <Button disabled={busy || !body.trim()} title={busy ? "Sending..." : "Send safely"} onPress={submit} />
      </Card>
    </Screen>
  );
}
