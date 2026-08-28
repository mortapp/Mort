import { router } from "expo-router";
import { useState } from "react";

import { Button } from "@/components/Button";
import { ErrorBanner } from "@/components/ErrorBanner";
import { PaymentPreferenceEditor } from "@/components/PaymentPreferenceEditor";
import { ProfileSummary } from "@/components/ProfileSummary";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { registerForPushNotificationsAsync } from "@/lib/notifications";
import { useAuth } from "@/providers/AuthProvider";

export default function AdultProfileScreen() {
  const { profile, user, refreshProfile, signOut } = useAuth();
  const [error, setError] = useState<string | null>(null);

  async function enablePush() {
    if (!user) return;
    setError(null);
    try {
      await registerForPushNotificationsAsync(user.id);
      await refreshProfile();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to register notifications.");
    }
  }

  return (
    <Screen>
      <Text variant="title">Adult profile</Text>
      {profile ? <ProfileSummary profile={profile} /> : null}
      <ErrorBanner message={error} />
      <PaymentPreferenceEditor profile={profile} userId={user?.id ?? null} onSaved={refreshProfile} />
      <Button title="Enable push notifications" variant="secondary" onPress={enablePush} />
      <Button title="Username" variant="secondary" onPress={() => router.push("/settings/username" as never)} />
      <Button title="Subscription and business tools" variant="secondary" onPress={() => router.push("/settings/subscription" as never)} />
      <Button title="Ad preferences" variant="secondary" onPress={() => router.push("/settings/ad-preferences" as never)} />
      <Button title="View notifications" variant="secondary" onPress={() => router.push("/notifications" as never)} />
      <Button title="Support" variant="secondary" onPress={() => router.push("/support" as never)} />
      <Button title="Rules and safety" variant="secondary" onPress={() => router.push("/legal" as never)} />
      <Button title="Sign out" variant="danger" onPress={signOut} />
    </Screen>
  );
}
