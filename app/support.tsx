import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { createSupportTicket, listMySupportTickets } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { SupportTicket } from "@/types/domain";

export default function SupportScreen() {
  const { user } = useAuth();
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function loadTickets(userId: string) {
    setTickets(await listMySupportTickets(userId));
  }

  async function submit() {
    if (!user) return;
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      await createSupportTicket({ requesterId: user.id, subject, body });
      setSubject("");
      setBody("");
      await loadTickets(user.id);
      setMessage("Support ticket created.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create support ticket.");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function load() {
      try {
        const rows = await listMySupportTickets(userId);
        if (active) setTickets(rows);
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : "Unable to load support tickets.");
      }
    }

    void load();
    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Support</Text>
      <Card>
        <Field label="Subject" onChangeText={setSubject} value={subject} />
        <Field label="What happened?" multiline onChangeText={setBody} value={body} />
        <ErrorBanner message={error} />
        {message ? <Text>{message}</Text> : null}
        <Button disabled={busy || !subject.trim() || !body.trim()} title={busy ? "Creating..." : "Create support ticket"} onPress={submit} />
      </Card>
      {tickets.length === 0 ? <EmptyState title="No support tickets" body="Your support tickets will appear here." /> : null}
      {tickets.map((ticket) => (
        <Card key={ticket.id}>
          <StatusPill label={ticket.status} tone={ticket.status === "open" ? "warning" : "info"} />
          <Text variant="subtitle">{ticket.subject}</Text>
          <Text variant="caption">{new Date(ticket.created_at).toLocaleString()}</Text>
        </Card>
      ))}
    </Screen>
  );
}
