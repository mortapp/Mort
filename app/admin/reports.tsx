import { useEffect, useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { EmptyState } from "@/components/EmptyState";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listAdminReports, updateReportStatus } from "@/lib/data";
import type { Report } from "@/types/domain";

export default function AdminReportsScreen() {
  const [reports, setReports] = useState<Report[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function fetchReports() {
    return listAdminReports();
  }

  async function loadFromAction() {
    try {
      setReports(await fetchReports());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load reports.");
    }
  }

  async function update(report: Report, status: Report["status"]) {
    setError(null);
    try {
      await updateReportStatus(report.id, status);
      await loadFromAction();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to update report.");
    }
  }

  useEffect(() => {
    let active = true;

    async function loadReports() {
      try {
        const rows = await fetchReports();
        if (!active) return;
        setReports(rows);
        setError(null);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load reports.");
      }
    }

    void loadReports();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Reports</Text>
      <ErrorBanner message={error} />
      {reports.length === 0 ? <EmptyState title="No reports" body="User, job, and message reports will appear here." /> : null}
      {reports.map((report) => (
        <Card key={report.id}>
          <StatusPill label={report.status} tone={report.status === "open" ? "danger" : "info"} />
          <Text variant="subtitle">{report.reason}</Text>
          <Text>{report.details || "No details"}</Text>
          <Text variant="caption">Reporter: {report.reporter_id}</Text>
          <Text variant="caption">Target user: {report.target_user_id ?? "none"}</Text>
          <Button title="Mark reviewing" variant="secondary" onPress={() => update(report, "reviewing")} />
          <Button title="Resolve" onPress={() => update(report, "resolved")} />
        </Card>
      ))}
    </Screen>
  );
}
