const profile = process.argv[2];
const supabaseUrl = process.env.SUPABASE_URL?.trim();
const anonKey = process.env.SUPABASE_ANON_KEY?.trim();
const knownProfiles = new Set([
  "development",
  "automated_test",
  "reviewer_demo",
  "closed_test",
  "production_candidate",
  "production",
]);

function fail(message) {
  throw new Error(`[release-server-gate] ${message}`);
}

async function validate() {
  if (!knownProfiles.has(profile)) fail("unknown release profile");
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
  if (!status || typeof status !== "object") {
    fail("server release RPC returned malformed data");
  }
  if (status.maintenance_mode === true) fail("server maintenance mode is active");

  const expectedStage = {
    reviewer_demo: "closed_test",
    closed_test: "closed_test",
    production_candidate: "production_pilot",
    production: "production_public",
  }[profile];
  if (status.release_mode !== expectedStage) {
    fail(
      `server release mode is ${status.release_mode ?? "missing"}, expected ${expectedStage}`,
    );
  }
  if (profile !== "production" && status.public_marketplace_enabled === true) {
    fail("non-production build cannot target a public server marketplace");
  }
  if (profile === "production") {
    if (status.public_marketplace_enabled !== true) {
      fail("server has not approved public marketplace activation");
    }
    if (status.real_document_collection !== true) {
      fail("server has not approved production identity verification");
    }
  }

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
