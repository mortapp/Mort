import { router } from "expo-router";
import { useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { createJob } from "@/lib/data";
import { PAYMENT_DISCLAIMER, SAFETY_DISCLAIMER, VERIFICATION_DISCLAIMER } from "@/lib/disclaimers";
import { useAuth } from "@/providers/AuthProvider";

export default function PostJobScreen() {
  const { user, profile } = useAuth();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("yard work");
  const [locationText, setLocationText] = useState("");
  const [city, setCity] = useState(profile?.city ?? "");
  const [stateCode, setStateCode] = useState(profile?.state ?? "");
  const [payLabel, setPayLabel] = useState("");
  const [minAge, setMinAge] = useState("13");
  const [maxAge, setMaxAge] = useState("17");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const verified = profile?.verification_status === "approved";

  async function submit() {
    if (!user || !verified) return;
    setBusy(true);
    setError(null);
    try {
      const job = await createJob({
        posterId: user.id,
        title,
        description,
        category,
        locationText,
        city,
        state: stateCode,
        payLabel,
        teenMinAge: Number(minAge),
        teenMaxAge: Number(maxAge),
        requiresGuardianApproval: true
      });
      router.push(`/job/${job.id}` as never);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to post job.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="title">Post a teen-safe job</Text>
      <StatusPill label={verified ? "Verified to post" : "Verification required"} tone={verified ? "success" : "warning"} />
      <Text>{VERIFICATION_DISCLAIMER}</Text>
      <Card>
        <Field label="Title" onChangeText={setTitle} value={title} />
        <Field label="Description" multiline onChangeText={setDescription} value={description} />
        <Field label="Category" onChangeText={setCategory} value={category} />
        <Field label="Public location text" onChangeText={setLocationText} placeholder="Near Main St, Carmel" value={locationText} />
        <Field label="City" onChangeText={setCity} value={city} />
        <Field autoCapitalize="characters" label="State" maxLength={2} onChangeText={setStateCode} value={stateCode} />
        <Field label="Pay label" onChangeText={setPayLabel} placeholder="$40 after completion" value={payLabel} />
        <Text variant="caption">{PAYMENT_DISCLAIMER}</Text>
        <Field keyboardType="number-pad" label="Minimum teen age" onChangeText={setMinAge} value={minAge} />
        <Field keyboardType="number-pad" label="Maximum teen age" onChangeText={setMaxAge} value={maxAge} />
        <Text variant="caption">Guardian approval is required by default for teen applications. {SAFETY_DISCLAIMER}</Text>
        <ErrorBanner message={error} />
        <Button
          disabled={busy || !verified || !title.trim() || !description.trim() || !locationText.trim() || !payLabel.trim()}
          title={busy ? "Posting..." : "Post job"}
          onPress={submit}
        />
      </Card>
    </Screen>
  );
}
