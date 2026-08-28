import { router, useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { JobCard } from "@/components/JobCard";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { calculateAge } from "@/lib/age";
import { applyToJob, getActiveGuardianForTeen, getJob } from "@/lib/data";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import type { GuardianConnection, Job } from "@/types/domain";

export default function JobDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { profile, user } = useAuth();
  const [job, setJob] = useState<Job | null>(null);
  const [guardian, setGuardian] = useState<GuardianConnection | null>(null);
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const age = profile?.dob ? calculateAge(profile.dob) : null;
  const canApply =
    profile?.role === "teen" &&
    job?.status === "open" &&
    age !== null &&
    age >= (job?.teen_min_age ?? 99) &&
    age <= (job?.teen_max_age ?? 0);

  async function apply() {
    if (!user || !job || !canApply) return;
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      if (job.requires_guardian_approval && !guardian) {
        throw new Error("This job requires an active guardian connection before applying.");
      }
      const application = await applyToJob({
        job,
        teenId: user.id,
        note,
        guardianId: guardian?.guardian_id ?? null,
        guardianRequired: job.requires_guardian_approval
      });
      setMessage(`Application created with status ${application.status}.`);
      setNote("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to apply.");
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    const jobId = id;
    if (!jobId) return;
    let active = true;

    async function loadJob() {
      try {
        const nextJob = await getJob(jobId);
        const nextGuardian = user?.id && profile?.role === "teen" ? await getActiveGuardianForTeen(user.id) : null;
        if (!active) return;
        setJob(nextJob);
        setGuardian(nextGuardian);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load job.");
      }
    }

    void loadJob();

    return () => {
      active = false;
    };
  }, [id, profile?.role, user?.id]);

  return (
    <Screen>
      <Text variant="title">Job detail</Text>
      <ErrorBanner message={error} />
      {job ? <JobCard job={job} /> : null}
      {job ? (
        <Card>
          <Text variant="subtitle">Safety</Text>
          <StatusPill label={job.requires_guardian_approval ? "Guardian approval required" : "Guardian approval not required"} tone="warning" />
          <Text>Keep messages, scheduling, and proof inside MORT. Report anything that feels unsafe.</Text>
          <Button title="Report this job/poster" variant="secondary" onPress={() => router.push(`/report/${job.poster_id}?jobId=${job.id}` as never)} />
        </Card>
      ) : null}
      {profile?.role === "teen" && job ? (
        <Card>
          <Text variant="subtitle">Apply</Text>
          {age !== null ? <Text variant="caption">Your age gate age: {age}</Text> : null}
          {guardian ? <StatusPill label="Guardian connected" tone="success" /> : <StatusPill label="No active guardian" tone="warning" />}
          <Field label="Application note" multiline onChangeText={setNote} value={note} />
          {message ? <Text color={colors.success}>{message}</Text> : null}
          <Button disabled={!canApply || busy || !note.trim()} title={busy ? "Applying..." : "Apply"} onPress={apply} />
        </Card>
      ) : null}
    </Screen>
  );
}
