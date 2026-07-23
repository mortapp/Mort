import { router } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ActionRow, AppBadge } from "@/components/DesignSystem";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { JobCard } from "@/components/JobCard";
import { AdBannerSlot, AdFreeBadge } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listJobsForPoster } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";
import type { Job } from "@/types/domain";

export default function AdultDashboardScreen() {
  const { user, profile } = useAuth();
  const [jobs, setJobs] = useState<Job[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const userId = user?.id ?? "";
    if (!userId) return;
    let active = true;

    async function loadJobs() {
      try {
        const rows = await listJobsForPoster(userId);
        if (!active) return;
        setJobs(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load your jobs.");
      }
    }

    void loadJobs();

    return () => {
      active = false;
    };
  }, [user?.id]);

  return (
    <Screen>
      <Text variant="title">Business dashboard</Text>
      <StatusPill label={`Verification: ${profile?.verification_status ?? "unknown"}`} tone={profile?.verification_status === "approved" ? "success" : "warning"} />
      <ErrorBanner message={error} />
      <Card>
        <Text variant="subtitle">Business growth</Text>
        <AppBadge label="Adult Pro planned" tone="info" />
        <AdFreeBadge />
        <ActionRow
          title="Post a teen-safe job"
          body="Core posting stays free for verified adults."
          action={<Button title="Post" onPress={() => router.push("/adult/post-job" as never)} />}
        />
        <ActionRow
          title="Review applicants"
          body="Sort/filter upgrades are premium-planned; basic review stays free."
          action={<Button title="Review" variant="secondary" onPress={() => router.push("/adult/applications" as never)} />}
        />
        <ActionRow
          title="Subscription tools"
          body="View Adult Pro, boosts, ad-free, and restore flows."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/settings/subscription" as never)} />}
        />
      </Card>
      {jobs.length === 0 ? <EmptyState title="No posted jobs" body="Verified adults and businesses can post teen-safe local jobs." /> : null}
      {jobs.map((job) => (
        <JobCard key={job.id} job={job} onPress={() => router.push(`/job/${job.id}` as never)} />
      ))}
      <AdBannerSlot placement="adult-dashboard" showDiagnostics />
    </Screen>
  );
}
