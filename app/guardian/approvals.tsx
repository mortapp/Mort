import { useEffect, useState } from "react";
import { router } from "expo-router";

import { ApplicationCard } from "@/components/ApplicationCard";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listMyApplications, updateApplicationStatus } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { Application } from "@/types/domain";

export default function GuardianApprovalsScreen() {
  const { user } = useAuth();
  const [applications, setApplications] = useState<Application[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  async function decide(application: Application, approved: boolean) {
    if (!user) return;
    setBusyId(application.id);
    setError(null);
    try {
      await updateApplicationStatus(application.id, approved ? "adult_review" : "guardian_rejected");
      setApplications(await listMyApplications(user.id, "guardian"));
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update approval.");
    } finally {
      setBusyId(null);
    }
  }

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadApprovals() {
      try {
        const rows = await listMyApplications(userId, "guardian");
        if (!active) return;
        setApplications(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load approvals.");
      }
    }

    void loadApprovals();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Guardian approvals</Text>
      <ErrorBanner message={error} />
      {applications.length === 0 ? <EmptyState title="No approvals" body="Teen applications that need guardian review will appear here." /> : null}
      {applications.map((application) => (
        <ApplicationCard
          application={application}
          key={application.id}
          primaryAction={{
            title: busyId === application.id ? "Updating..." : "Approve",
            disabled: busyId === application.id || application.status !== "guardian_pending",
            onPress: () => decide(application, true)
          }}
          secondaryAction={{
            title: "Reject",
            disabled: busyId === application.id || application.status !== "guardian_pending",
            onPress: () => decide(application, false)
          }}
          tertiaryAction={{ title: "Review proof", disabled: busyId === application.id, onPress: () => router.push(`/proof/${application.id}` as never) }}
        />
      ))}
    </Screen>
  );
}
