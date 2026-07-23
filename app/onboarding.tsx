import { router } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, View } from "react-native";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { StatusPill } from "@/components/StatusPill";
import { Text } from "@/components/Text";
import { evaluateAgeGate } from "@/lib/age";
import { completeOnboarding } from "@/lib/data";
import { registerForPushNotificationsAsync } from "@/lib/notifications";
import { colors, spacing } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";
import type { UserRole } from "@/types/domain";

const roleCopy: Record<Exclude<UserRole, "admin">, string> = {
  teen: "Find local jobs with safety controls and guardian support.",
  adult: "Post jobs for teens after internal business verification.",
  guardian: "Supervise teen applications, approvals, and safety pings."
};

export default function OnboardingScreen() {
  const { user, refreshProfile, signOut } = useAuth();
  const [displayName, setDisplayName] = useState("");
  const [dob, setDob] = useState("");
  const [city, setCity] = useState("");
  const [stateCode, setStateCode] = useState("");
  const [role, setRole] = useState<Exclude<UserRole, "admin"> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const gate = useMemo(() => (dob ? evaluateAgeGate(dob) : null), [dob]);
  const allowedRoles = gate?.allowed ? gate.allowedRoles.filter((candidate) => candidate !== "admin") : [];

  async function submit() {
    if (!user || !role || !gate?.allowed) return;
    if (!gate.allowedRoles.includes(role)) {
      setError("That role is not available for this age.");
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await completeOnboarding({
        userId: user.id,
        role,
        displayName,
        dob,
        city,
        state: stateCode
      });
      await registerForPushNotificationsAsync(user.id);
      await refreshProfile();
      router.replace("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to finish onboarding.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="title">Set up MORT safely</Text>
      <Card>
        <Field label="Display name" onChangeText={setDisplayName} value={displayName} />
        <Field label="Date of birth (YYYY-MM-DD)" onChangeText={setDob} placeholder="2009-04-18" value={dob} />
        <Field label="City" onChangeText={setCity} value={city} />
        <Field autoCapitalize="characters" label="State" maxLength={2} onChangeText={setStateCode} value={stateCode} />
        {gate ? (
          gate.allowed ? (
            <StatusPill label={`Age ${gate.age}: eligible`} tone="success" />
          ) : (
            <StatusPill label={gate.reason} tone="danger" />
          )
        ) : null}
      </Card>

      <Card>
        <Text variant="subtitle">Choose your role</Text>
        <View style={styles.roleGrid}>
          {(["teen", "adult", "guardian"] as const).map((candidate) => {
            const disabled = !allowedRoles.includes(candidate);
            const selected = role === candidate;
            return (
              <Pressable
                accessibilityRole="button"
                disabled={disabled}
                key={candidate}
                onPress={() => setRole(candidate)}
                style={[styles.roleCard, selected ? styles.selectedRole : null, disabled ? styles.disabledRole : null]}
              >
                <Text variant="label">{candidate.toUpperCase()}</Text>
                <Text color={colors.muted}>{roleCopy[candidate]}</Text>
              </Pressable>
            );
          })}
        </View>
        <Text variant="caption">Admin access cannot be self-selected. Admins must be promoted from a trusted Supabase context.</Text>
      </Card>

      <ErrorBanner message={error} />
      <Button
        disabled={busy || !displayName || !dob || !city || stateCode.length !== 2 || !role || !gate?.allowed}
        title={busy ? "Saving..." : "Finish onboarding"}
        onPress={submit}
      />
      <Button title="Sign out" variant="secondary" onPress={signOut} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  roleGrid: {
    gap: spacing.md
  },
  roleCard: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.md
  },
  selectedRole: {
    borderColor: colors.primary,
    backgroundColor: "#10251d"
  },
  disabledRole: {
    opacity: 0.45
  }
});
