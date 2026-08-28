import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listAdminVerifications, reviewVerification } from "@/lib/data";
import type { BusinessVerification } from "@/types/domain";

export default function AdminVerificationScreen() {
  const [verifications, setVerifications] = useState<BusinessVerification[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function fetchVerifications() {
    return listAdminVerifications();
  }

  async function loadFromAction() {
    try {
      setVerifications(await fetchVerifications());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load verifications.");
    }
  }

  async function review(verification: BusinessVerification, status: "approved" | "rejected") {
    setError(null);
    try {
      await reviewVerification(verification.id, status);
      await loadFromAction();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to review verification.");
    }
  }

  useEffect(() => {
    let active = true;

    async function loadVerifications() {
      try {
        const rows = await fetchVerifications();
        if (!active) return;
        setVerifications(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load verifications.");
      }
    }

    void loadVerifications();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Verification queue</Text>
      <ErrorBanner message={error} />
      {verifications.length === 0 ? <EmptyState title="No submissions" body="Adult/business verification requests will appear here." /> : null}
      {verifications.map((verification) => (
        <Card key={verification.id}>
          <StatusPill label={verification.status} tone={verification.status === "pending" ? "warning" : "success"} />
          <Text variant="subtitle">{verification.business_name}</Text>
          <Text>{verification.business_type}</Text>
          <Text>{verification.notes || "No notes"}</Text>
          <Text variant="caption">Adult id: {verification.adult_id}</Text>
          <Text variant="caption">Document: {verification.document_storage_path ?? "none"}</Text>
          <Button title="Approve" onPress={() => review(verification, "approved")} />
          <Button title="Reject" variant="danger" onPress={() => review(verification, "rejected")} />
        </Card>
      ))}
    </Screen>
  );
}
