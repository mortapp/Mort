import { useEffect, useState } from "react";

import { ErrorBanner } from "@/components/ErrorBanner";
import { AppHeader, AppToast } from "@/components/DesignSystem";
import { Screen } from "@/components/Screen";
import {
  UsernameChangeForm,
  UsernameChangeHistory,
  UsernameChangeLimitCard,
  UsernameChangeMeter,
  UsernameTokenPurchaseCard
} from "@/components/UsernameChange";
import {
  getUsernameChangeStatus,
  listUsernameChangeEvents,
  requestUsernameChange,
  type UsernameChangeStatus
} from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";

type UsernameEvent = { id: string; new_username: string; old_username: string | null; source: string; created_at: string };

export default function UsernameSettingsScreen() {
  const { refreshProfile } = useAuth();
  const [status, setStatus] = useState<UsernameChangeStatus | null>(null);
  const [events, setEvents] = useState<UsernameEvent[]>([]);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function fetchUsernameData() {
    return Promise.all([getUsernameChangeStatus(), listUsernameChangeEvents()]);
  }

  async function load() {
    setError(null);
    try {
      const [nextStatus, nextEvents] = await fetchUsernameData();
      setStatus(nextStatus);
      setEvents(nextEvents as UsernameEvent[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load username status.");
    }
  }

  useEffect(() => {
    let active = true;

    void fetchUsernameData()
      .then(([nextStatus, nextEvents]) => {
        if (!active) return;
        setStatus(nextStatus);
        setEvents(nextEvents as UsernameEvent[]);
      })
      .catch((err) => {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load username status.");
      });

    return () => {
      active = false;
    };
  }, []);

  async function save(username: string) {
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const result = await requestUsernameChange(username);
      await refreshProfile();
      await load();
      setMessage(result ? `Username saved as @${result.username} using ${result.source.replace("_", " ")}.` : "Username saved.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save username.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <AppHeader title="Username" subtitle="3 free lifetime changes. Extra changes are optional and must pass safety checks." />
      {message ? <AppToast message={message} tone="success" /> : null}
      <ErrorBanner message={error} />
      <UsernameChangeMeter status={status} />
      <UsernameChangeLimitCard status={status} />
      <UsernameChangeForm busy={busy} onSubmit={save} />
      <UsernameTokenPurchaseCard />
      <UsernameChangeHistory events={events} />
    </Screen>
  );
}
