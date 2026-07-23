import { Link, router } from "expo-router";
import { useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ConfigNotice } from "@/components/ConfigNotice";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { supabase } from "@/lib/supabase";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";

export default function SignInScreen() {
  const { configured, refreshProfile } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function signIn() {
    setBusy(true);
    setError(null);
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password
      });
      if (signInError) throw signInError;
      await refreshProfile();
      router.replace("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to sign in.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="title">Welcome to MORT</Text>
      {!configured ? <ConfigNotice /> : null}
      <Card>
        <Field autoCapitalize="none" keyboardType="email-address" label="Email" onChangeText={setEmail} value={email} />
        <Field label="Password" onChangeText={setPassword} secureTextEntry value={password} />
        <ErrorBanner message={error} />
        <Button disabled={busy || !email || !password} title={busy ? "Signing in..." : "Sign in"} onPress={signIn} />
      </Card>
      <Link href="/auth/sign-up">
        <Text color={colors.primary} variant="label">
          Create an account
        </Text>
      </Link>
    </Screen>
  );
}
