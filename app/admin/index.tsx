import { useEffect, useState } from "react";
import { router } from "expo-router";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { AppBadge, ActionRow } from "@/components/DesignSystem";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { listAdminReports, listAdminVerifications } from "@/lib/data";
import { useAuth } from "@/providers/AuthProvider";

export default function AdminHomeScreen() {
  const { profile } = useAuth();
  const [reports, setReports] = useState(0);
  const [verifications, setVerifications] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadDashboard() {
      try {
        const [reportRows, verificationRows] = await Promise.all([listAdminReports(), listAdminVerifications()]);
        if (!active) return;
        setError(null);
        setReports(reportRows.filter((report) => report.status === "open").length);
        setVerifications(verificationRows.filter((verification) => verification.status === "pending").length);
      } catch (err) {
        if (!active) return;
        setError(err instanceof Error ? err.message : "Unable to load admin dashboard.");
      }
    }

    void loadDashboard();

    return () => {
      active = false;
    };
  }, []);

  return (
    <Screen>
      <Text variant="title">Admin dashboard</Text>
      <StatusPill label={profile?.role === "admin" ? "Admin role active" : "Admin role required"} tone={profile?.role === "admin" ? "danger" : "warning"} />
      <ErrorBanner message={error} />
      <Card>
        <Text variant="subtitle">Moderation queue</Text>
        <Text>{reports} open reports</Text>
        <Text>{verifications} pending verifications</Text>
      </Card>
      <Card>
        <Text variant="subtitle">Safety posture</Text>
        <Text>Use these queues to review reports, verification submissions, jobs, and user records protected by Supabase RLS.</Text>
        <Button title="View notifications" variant="secondary" onPress={() => router.push("/notifications" as never)} />
        <Button title="Support queue" variant="secondary" onPress={() => router.push("/admin/support" as never)} />
        <Button title="Rules and safety" variant="secondary" onPress={() => router.push("/legal" as never)} />
      </Card>
      <Card>
        <Text variant="subtitle">Monetization controls</Text>
        <AppBadge label="Admin review required" tone="danger" />
        <Text>Review subscriptions, ads, boosts, and purchase audit docs before any real-user monetization launch.</Text>
        <ActionRow
          title="RevenueCat debug"
          body="Admin/dev-only state view. Does not show secrets."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization/revenuecat-debug" as never)} />}
        />
        <ActionRow
          title="Monetization hub"
          body="Paywall, restore, ad-free, and safety rules."
          action={<Button title="Open" variant="secondary" onPress={() => router.push("/monetization" as never)} />}
        />
      </Card>
    </Screen>
  );
}
