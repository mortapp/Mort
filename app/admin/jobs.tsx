import { router } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { JobCard } from "@/components/JobCard";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listAdminJobs, updateJobStatus } from "@/lib/data";
import type { Job } from "@/types/domain";

export default function AdminJobsScreen() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function fetchJobs() {
    return listAdminJobs();
  }

  async function loadFromAction() {
    try {
      setJobs(await fetchJobs());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load jobs.");
    }
  }

  async function remove(job: Job) {
    setError(null);
    try {
      await updateJobStatus(job.id, "removed");
      await loadFromAction();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update job.");
    }
  }

  useEffect(() => {
    let active = true;

    async function loadJobs() {
      try {
        const rows = await fetchJobs();
        if (!active) return;
        setJobs(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load jobs.");
      }
    }

    void loadJobs();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Job moderation</Text>
      <ErrorBanner message={error} />
      {jobs.length === 0 ? <EmptyState title="No jobs" body="Posted jobs will appear here for moderation." /> : null}
      {jobs.map((job) => (
        <JobCard key={job.id} job={job} onPress={() => router.push(`/job/${job.id}` as never)} />
      ))}
      {jobs.map((job) => (
        <Button key={`${job.id}-remove`} title={`Remove: ${job.title}`} variant="danger" onPress={() => remove(job)} />
      ))}
    </Screen>
  );
}
