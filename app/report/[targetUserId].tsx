import { router, useLocalSearchParams } from "expo-router";
import { useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { blockUser, createReport } from "@/lib/data";
import { EMERGENCY_DISCLAIMER, SAFETY_DISCLAIMER } from "@/lib/disclaimers";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";

export default function ReportScreen() {
  const { targetUserId, jobId, messageId } = useLocalSearchParams<{
    targetUserId: string;
    jobId?: string;
    messageId?: string;
  }>();
  const { user } = useAuth();
  const [reason, setReason] = useState("");
  const [details, setDetails] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function submit() {
    if (!user) return;
    setError(null);
    setMessage(null);
    try {
      await createReport({
        reporterId: user.id,
        targetUserId,
        targetJobId: jobId ?? null,
        targetMessageId: messageId ?? null,
        reason,
        details
      });
      setMessage("Report submitted for admin moderation.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to submit report.");
    }
  }

  async function block() {
    if (!user || !targetUserId) return;
    setError(null);
    try {
      await blockUser(user.id, targetUserId);
      setMessage("User blocked.");
      router.back();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to block user.");
    }
  }

  return (
    <Screen>
      <Text variant="title">Report or block</Text>
      <Text>{SAFETY_DISCLAIMER}</Text>
      <Text>{EMERGENCY_DISCLAIMER}</Text>
      <Card>
        <Text variant="caption">Target user: {targetUserId}</Text>
        {jobId ? <Text variant="caption">Job: {jobId}</Text> : null}
        {messageId ? <Text variant="caption">Message: {messageId}</Text> : null}
        <Field label="Reason" onChangeText={setReason} value={reason} />
        <Field label="Details" multiline onChangeText={setDetails} value={details} />
        <ErrorBanner message={error} />
        {message ? <Text color={colors.success}>{message}</Text> : null}
        <Button disabled={!reason} title="Submit report" onPress={submit} />
        <Button title="Block user" variant="danger" onPress={block} />
      </Card>
    </Screen>
  );
}
