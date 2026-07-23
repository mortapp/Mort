import { router } from "expo-router";
import { Fragment, useEffect, useMemo, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppBadge } from "@/components/DesignSystem";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { JobCard } from "@/components/JobCard";
import { AdBannerSlot } from "@/components/Monetization";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { listOpenJobs } from "@/lib/data";
import { colors } from "@/lib/theme";
import type { Job } from "@/types/domain";

export default function TeenFeedScreen() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [category, setCategory] = useState("all");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const categories = useMemo(() => ["all", ...Array.from(new Set(jobs.map((job) => job.category).filter(Boolean))).slice(0, 8)], [jobs]);
  const filteredJobs = useMemo(
    () => (category === "all" ? jobs : jobs.filter((job) => job.category === category)),
    [category, jobs]
  );

  useEffect(() => {
    let active = true;

    async function loadJobs() {
      try {
        const rows = await listOpenJobs();
        if (!active) return;
        setJobs(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load jobs.");
      } finally {
        if (active) setLoading(false);
      }
    }

    void loadJobs();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Local jobs</Text>
      <Text color={colors.muted}>Open jobs from verified adults and businesses. Keep applications, chat, and proof inside MORT.</Text>
      <Card>
        <Text variant="subtitle">Filters</Text>
        <Text color={colors.muted}>Filter locally by category. Advanced filters are premium-planned, but basic browsing stays free.</Text>
        {categories.map((item) => (
          <Button
            key={item}
            title={item === "all" ? "All jobs" : item}
            variant={category === item ? "primary" : "secondary"}
            onPress={() => setCategory(item)}
          />
        ))}
        <AppBadge label={`${filteredJobs.length} shown`} tone="info" />
      </Card>
      <ErrorBanner message={error} />
      {jobs.length === 0 && !loading ? <EmptyState title="No jobs yet" body="New local jobs will appear here after verified adults post them." /> : null}
      {filteredJobs.map((job, index) => (
        <Fragment key={job.id}>
          <JobCard job={job} onPress={() => router.push(`/job/${job.id}` as never)} />
          {index === 1 ? <AdBannerSlot key={`${job.id}-ad`} placement="teen-feed" showDiagnostics /> : null}
        </Fragment>
      ))}
    </Screen>
  );
}
