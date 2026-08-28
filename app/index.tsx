import { router } from "expo-router";
import { useEffect } from "react";
import { ActivityIndicator } from "react-native";

import { ConfigNotice } from "@/components/ConfigNotice";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { isAccountRestricted } from "@/lib/account";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";

export default function IndexScreen() {
  const { configured, loading, session, profile } = useAuth();

  useEffect(() => {
    if (loading || !configured) return;

    if (!session) {
      router.replace("/auth/sign-in");
      return;
    }

    if (!profile?.onboarding_completed || !profile.role) {
      router.replace("/onboarding");
      return;
    }

    if (isAccountRestricted(profile)) {
      router.replace("/account-status" as never);
      return;
    }

    if (profile.role === "teen") router.replace("/teen/feed");
    if (profile.role === "adult") router.replace("/adult/dashboard");
    if (profile.role === "guardian") router.replace("/guardian/approvals");
    if (profile.role === "admin") router.replace("/admin");
  }, [configured, loading, profile, session]);

  return (
    <Screen>
      <Text variant="title">MORT</Text>
      {!configured ? <ConfigNotice /> : null}
      {loading || configured ? <ActivityIndicator color={colors.primary} /> : null}
    </Screen>
  );
}
