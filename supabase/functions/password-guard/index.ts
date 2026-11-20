import { createClient } from "npm:@supabase/supabase-js@2.110.1";
import { createPasswordGuardHandler } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("MORT_PUBLIC_API_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !anonKey || !serviceRoleKey) {
  throw new Error("Supabase server environment is not configured.");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(createPasswordGuardHandler({
  supabaseUrl,
  anonKey,
  attestationSecret: Deno.env.get("MORT_PASSWORD_ATTESTATION_SECRET"),
  consumeSignupQuota: async (bucketKey, limit, windowSeconds) => {
    const { data, error } = await admin.rpc(
      "mort_consume_password_guard_rate_limit",
      {
        p_bucket_key: bucketKey,
        p_limit: limit,
        p_window_seconds: windowSeconds,
      },
    );
    if (error) throw error;
    return data === true;
  },
}));
