import { Link } from "expo-router";

import { Card } from "@/components/Card";
import { Text } from "@/components/Text";

export function ConfigNotice() {
  return (
    <Card>
      <Text variant="subtitle">Supabase environment needed</Text>
      <Text>
        Add `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY` in `.env.local` before using live auth and data.
      </Text>
      <Link href="/auth/sign-in">
        <Text color="#39ff88" variant="label">
          Continue to sign in
        </Text>
      </Link>
    </Card>
  );
}
