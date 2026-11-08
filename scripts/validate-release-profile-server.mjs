import { getReleaseStatusError } from "./release-profile-server-contract.mjs";

const profile = process.argv[2];
const supabaseUrl = process.env.SUPABASE_URL?.trim();
const anonKey = process.env.SUPABASE_ANON_KEY?.trim();

function fail(message) {
  throw new Error(`[release-server-gate] ${message}`);
}

async function validate() {
  const earlyError = getReleaseStatusError(profile, {});
  if (earlyError === "unknown release profile") fail(earlyError);
  if (profile === "development" || profile === "automated_test") {
    console.log(
      `[release-server-gate] PASS: ${profile} has no hosted activation requirement.`,
    );
    return;
  }
  if (!supabaseUrl?.startsWith("https://") || !anonKey) {
    fail("hosted public Supabase configuration is unavailable");
  }

  const response = await fetch(
    `${supabaseUrl}/rest/v1/rpc/get_release_mode_status`,
    {
      method: "POST",
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${anonKey}`,
        "content-type": "application/json",
      },
      body: "{}",
    },
  );
  if (!response.ok) fail(`server release RPC returned HTTP ${response.status}`);
  const status = await response.json();
  const statusError = getReleaseStatusError(profile, status);
  if (statusError) fail(statusError);

  console.log(
    `[release-server-gate] PASS: profile=${profile}, server_stage=${status.release_mode}, public=${status.public_marketplace_enabled === true}.`,
  );
}

try {
  await validate();
} catch (error) {
  console.error(
    error instanceof Error ? error.message : "[release-server-gate] unknown error",
  );
  process.exitCode = 1;
}
