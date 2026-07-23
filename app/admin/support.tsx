import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listAdminSupportTickets, updateSupportTicketStatus } from "@/lib/data";
import type { SupportTicket } from "@/types/domain";

export default function AdminSupportScreen() {
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function loadTickets() {
    setTickets(await listAdminSupportTickets());
  }

  async function resolve(ticket: SupportTicket) {
    setBusyId(ticket.id);
    setError(null);
    try {
      await updateSupportTicketStatus(ticket.id, "resolved");
      await loadTickets();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update support ticket.");
    } finally {
      setBusyId(null);
    }
  }

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const rows = await listAdminSupportTickets();
        if (active) setTickets(rows);
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : "Unable to load support tickets.");
      }
    }

    void load();
    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Support queue</Text>
      <ErrorBanner message={error} />
      {tickets.length === 0 ? <EmptyState title="No tickets" body="Support tickets will appear here." /> : null}
      {tickets.map((ticket) => (
        <Card key={ticket.id}>
          <StatusPill label={ticket.status} tone={ticket.status === "open" ? "warning" : "info"} />
          <Text variant="subtitle">{ticket.subject}</Text>
          <Text variant="caption">Requester: {ticket.requester_id}</Text>
          <Button disabled={busyId === ticket.id} title={busyId === ticket.id ? "Updating..." : "Resolve"} onPress={() => resolve(ticket)} />
        </Card>
      ))}
    </Screen>
  );
}
