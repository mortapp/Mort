import { useEffect, useState } from "react";
import { router } from "expo-router";

import { ApplicationCard } from "@/components/ApplicationCard";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listApplicationsForPoster, updateApplicationStatus } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { Application } from "@/types/domain";

export default function AdultApplicationsScreen() {
  const { user } = useAuth();
  const [applications, setApplications] = useState<Application[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function review(application: Application, status: "accepted" | "rejected" | "completed" | "disputed") {
    if (!user) return;
    setBusyId(application.id);
    setError(null);
    try {
      await updateApplicationStatus(application.id, status);
      setApplications(await listApplicationsForPoster(user.id));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update application.");
    } finally {
      setBusyId(null);
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadApplications() {
      try {
        const rows = await listApplicationsForPoster(userId);
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
      <Text variant="title">Application review</Text>
      <ErrorBanner message={error} />
      {applications.length === 0 ? <EmptyState title="No applications" body="Applications for your posted jobs will appear here." /> : null}
      {applications.map((application) => {
        const busy = busyId === application.id;
        const reviewState = application.status === "adult_review" || application.status === "submitted";
        const accepted = application.status === "accepted";
        return (
          <ApplicationCard
            application={application}
            key={application.id}
            primaryAction={
              accepted
                ? { title: busy ? "Updating..." : "Mark complete", disabled: busy, onPress: () => review(application, "completed") }
                : reviewState
                  ? { title: busy ? "Updating..." : "Accept", disabled: busy, onPress: () => review(application, "accepted") }
                  : undefined
            }
            secondaryAction={
              accepted
                ? { title: "Dispute proof", disabled: busy, onPress: () => review(application, "disputed") }
                : reviewState
                  ? { title: "Reject", disabled: busy, onPress: () => review(application, "rejected") }
                  : undefined
            }
            tertiaryAction={{ title: "Review proof", disabled: busy, onPress: () => router.push(`/proof/${application.id}` as never) }}
          />
        );
      })}
    </Screen>
  );
}
