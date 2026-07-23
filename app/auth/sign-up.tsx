import * as Linking from "expo-linking";
import { Link, router } from "expo-router";
import { useState } from "react";

import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { ErrorBanner } from "@/components/ErrorBanner";
import { Field } from "@/components/Field";
import { Screen } from "@/components/Screen";
import { Text } from "@/components/Text";
import { supabase } from "@/lib/supabase";
import { colors } from "@/lib/theme";
import { useAuth } from "@/providers/AuthProvider";

export default function SignUpScreen() {
  const { refreshProfile } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function signUp() {
    setBusy(true);
    setError(null);
    setMessage(null);
    try {
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: {
          emailRedirectTo: Linking.createURL("/")
        }
      });
      if (signUpError) throw signUpError;

      if (data.session) {
        await refreshProfile();
        router.replace("/onboarding");
      } else {
        setMessage("Check your email to confirm your account, then sign in to finish onboarding.");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create account.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen>
      <Text variant="title">Create MORT account</Text>
      <Card>
        <Field autoCapitalize="none" keyboardType="email-address" label="Email" onChangeText={setEmail} value={email} />
        <Field label="Password" onChangeText={setPassword} secureTextEntry value={password} />
        <Text variant="caption">Date of birth and role are checked after auth so Supabase Auth remains the only identity provider.</Text>
        <ErrorBanner message={error} />
        {message ? <Text color={colors.success}>{message}</Text> : null}
        <Button disabled={busy || !email || password.length < 8} title={busy ? "Creating..." : "Create account"} onPress={signUp} />
      </Card>
      <Link href="/auth/sign-in">
        <Text color={colors.primary} variant="label">
          I already have an account
        </Text>
      </Link>
    </Screen>
  );
}
