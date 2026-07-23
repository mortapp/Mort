import { useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { submitBusinessVerification } from "@/lib/data";
import { VERIFICATION_DISCLAIMER } from "@/lib/disclaimers";
import { colors } from "@/lib/theme";
import { pickAndUploadImage } from "@/lib/uploads";
import { useAuth } from "@/providers/AuthProvider";

export default function AdultVerificationScreen() {
  const { user, profile, refreshProfile } = useAuth();
  const [businessName, setBusinessName] = useState("");
  const [businessType, setBusinessType] = useState("");
  const [notes, setNotes] = useState("");
  const [storagePath, setStoragePath] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function upload() {
    if (!user) return;
    setError(null);
    try {
      const uploadResult = await pickAndUploadImage("verification-uploads", user.id);
      if (uploadResult) {
        setStoragePath(uploadResult.storagePath);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to upload verification image.");
    }
  }

  async function submit() {
    if (!user) return;
    setError(null);
    setMessage(null);
    try {
      await submitBusinessVerification({
        adultId: user.id,
        businessName,
        businessType,
        documentStoragePath: storagePath,
        notes
      });
      await refreshProfile();
      setMessage("Verification submitted for admin review.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to submit verification.");
    }
  }

  return (
    <Screen>
      <Text variant="title">Internal verification</Text>
      <StatusPill label={profile?.verification_status ?? "not_started"} tone={profile?.verification_status === "approved" ? "success" : "warning"} />
      <Card>
        <Text>{VERIFICATION_DISCLAIMER}</Text>
        <Field label="Business or adult display name" onChangeText={setBusinessName} value={businessName} />
        <Field label="Business type" onChangeText={setBusinessType} value={businessType} />
        <Field label="Notes for moderators" multiline onChangeText={setNotes} value={notes} />
        <Button title={storagePath ? "Replace verification image" : "Upload verification image"} variant="secondary" onPress={upload} />
        {storagePath ? <Text variant="caption">Uploaded: {storagePath}</Text> : null}
        <ErrorBanner message={error} />
        {message ? <Text color={colors.success}>{message}</Text> : null}
        <Button disabled={!businessName.trim() || !businessType.trim()} title="Submit for review" onPress={submit} />
      </Card>
    </Screen>
  );
}
