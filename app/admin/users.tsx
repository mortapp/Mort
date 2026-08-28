import { useEffect, useState } from "react";

import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listAdminProfiles } from "@/lib/data";
import type { Profile } from "@/types/domain";

export default function AdminUsersScreen() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadUsers() {
      try {
        const rows = await listAdminProfiles();
        if (!active) return;
        setProfiles(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load users.");
      }
    }

    void loadUsers();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">User moderation</Text>
      <ErrorBanner message={error} />
      {profiles.length === 0 ? <EmptyState title="No users" body="Profiles appear here when the app is connected to Supabase." /> : null}
      {profiles.map((profile) => (
        <Card key={profile.id}>
          <Text variant="subtitle">{profile.display_name ?? "Unnamed user"}</Text>
          <StatusPill label={profile.role ?? "no role"} tone={profile.role === "admin" ? "danger" : "info"} />
          <Text variant="caption">{profile.id}</Text>
          <Text>Verification: {profile.verification_status}</Text>
          <Text>City: {profile.city ?? "unknown"} {profile.state ?? ""}</Text>
        </Card>
      ))}
    </Screen>
  );
}
