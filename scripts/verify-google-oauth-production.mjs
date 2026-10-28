const expectedUrl = "https://jxbnrkasktbhtiujkhay.supabase.co";
const callback = "com.mortapp.mobile://app/auth-callback";
const supabaseUrl = (process.env.SUPABASE_URL ?? "").replace(/\/$/, "");
const anonKey = process.env.SUPABASE_ANON_KEY ?? "";

function fail(message) {
  console.error(`[google-oauth-production] ${message}`);
  process.exit(1);
}

if (supabaseUrl !== expectedUrl || anonKey.length < 20) {
  fail("expected production Supabase URL or public key is missing");
}

const headers = {
  apikey: anonKey,
  authorization: `Bearer ${anonKey}`,
};

const settingsResponse = await fetch(`${supabaseUrl}/auth/v1/settings`, {
  headers,
});
if (!settingsResponse.ok) {
  fail(`Supabase Auth settings returned HTTP ${settingsResponse.status}`);
}
const settings = await settingsResponse.json();
if (settings?.external?.google !== true) {
  fail("Google is not enabled in production Supabase Auth");
}

const authorizationUrl = new URL(`${supabaseUrl}/auth/v1/authorize`);
authorizationUrl.searchParams.set("provider", "google");
authorizationUrl.searchParams.set("redirect_to", callback);
const authorizationResponse = await fetch(authorizationUrl, {
  headers,
  redirect: "manual",
});
const location = authorizationResponse.headers.get("location");
let providerUrl;
try {
  providerUrl = new URL(location ?? "");
} catch {
  fail("Supabase did not return a Google authorization redirect");
}

if (
  ![301, 302, 303].includes(authorizationResponse.status) ||
  providerUrl.hostname !== "accounts.google.com" ||
  !providerUrl.searchParams.get("client_id")
) {
  fail("Supabase Google authorization endpoint is not fully configured");
}

console.log(
  "[google-oauth-production] PASS: Google is enabled and Supabase redirects to Google with a configured client.",
);
