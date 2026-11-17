import { createPasswordGuardHandler } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
// Public client key only. The service role key is deliberately not used.
const anonKey = Deno.env.get("MORT_PUBLIC_API_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!supabaseUrl || !anonKey) {
  throw new Error("Supabase public environment is not configured.");
}

Deno.serve(createPasswordGuardHandler({
  supabaseUrl,
  anonKey,
  attestationSecret: Deno.env.get("MORT_PASSWORD_ATTESTATION_SECRET"),
}));
