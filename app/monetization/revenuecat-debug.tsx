import { Card } from "@/components/Card";
import { AppHeader, AppBadge, FeatureLockCard } from "@/components/DesignSystem";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { APP_ENV } from "@/lib/env";
import { useAuth } from "@/providers/AuthProvider";
import { useMonetization } from "@/providers/MonetizationProvider";

export default function RevenueCatDebugScreen() {
  const { profile } = useAuth();
  const { status, offerings, customerInfo, entitlements, error, message } = useMonetization();
  const allowed = profile?.role === "admin" || APP_ENV !== "production";

  if (!allowed) {
    return (
      <Screen>
        <FeatureLockCard title="Debug unavailable" body="RevenueCat debug is limited to admins or non-production builds." />
      </Screen>
    );
  }

  return (
    <Screen>
      <AppHeader title="RevenueCat debug" subtitle="Admin/dev-only view. No secrets are shown." />
      <Card>
        <AppBadge label={`status: ${status}`} tone={status === "configured" ? "success" : "warning"} />
        <Text>Current offering: {offerings?.current?.identifier ?? "none"}</Text>
        <Text>Package count: {offerings?.current?.availablePackages?.length ?? 0}</Text>
        <Text>Customer app user id: {customerInfo?.originalAppUserId ?? "none"}</Text>
        <Text>Premium: {entitlements.premium ? "active" : "inactive"}</Text>
        <Text>Ad-free: {entitlements.adFree ? "active" : "inactive"}</Text>
        <Text>Adult Pro: {entitlements.adultPro ? "active" : "inactive"}</Text>
        <Text>Business Boost: {entitlements.businessBoost ? "active" : "inactive"}</Text>
        <Text>Guardian Plus: {entitlements.guardianPlus ? "active" : "inactive"}</Text>
        {message ? <Text>{message}</Text> : null}
        {error ? <Text>{error}</Text> : null}
      </Card>
    </Screen>
  );
}
