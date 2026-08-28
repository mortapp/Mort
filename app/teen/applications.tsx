import { router } from "expo-router";
import { useEffect, useState } from "react";

import { ApplicationCard } from "@/components/ApplicationCard";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listMyApplications } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { Application } from "@/types/domain";

export default function TeenApplicationsScreen() {
  const { user } = useAuth();
  const [applications, setApplications] = useState<Application[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadApplications() {
      try {
        const rows = await listMyApplications(userId, "teen");
        if (!active) return;
        setApplications(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load applications.");
      }
    }

    void loadApplications();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Applications</Text>
      <ErrorBanner message={error} />
      {applications.length === 0 ? <EmptyState title="No applications" body="Apply to an open job to start a guarded application thread." /> : null}
      {applications.map((application) => (
        <ApplicationCard
          application={application}
          key={application.id}
          primaryAction={{
            title: application.status === "accepted" ? "Upload proof" : "Proof after acceptance",
            disabled: application.status !== "accepted",
            onPress: () => router.push(`/proof/${application.id}` as never)
          }}
        />
      ))}
    </Screen>
  );
}
