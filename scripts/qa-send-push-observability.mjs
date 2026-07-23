import { randomBytes, randomUUID } from "node:crypto";

const projectRef = "rakjydmgwwgtdislanbt";
const expectedUrl = `https://${projectRef}.supabase.co`;
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (supabaseUrl !== expectedUrl) {
  throw new Error(`EXPO_PUBLIC_SUPABASE_URL must target ${projectRef}.`);
}
if (!serviceRoleKey) {
  throw new Error("Missing required environment variable: SUPABASE_SERVICE_ROLE_KEY");
}

const traceId = randomUUID();
const response = await fetch(`${supabaseUrl}/functions/v1/send-push`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    "Content-Type": "application/json",
    "x-correlation-id": traceId,
    "x-mort-push-secret": randomBytes(32).toString("base64url"),
  },
  body: "{}",
});

const body = await response.json().catch(() => null);
if (response.status !== 401) {
  throw new Error(`Expected send-push authorization rejection; received HTTP ${response.status}.`);
}
if (body?.ok !== false || body?.code !== "push_authorization_required") {
  throw new Error("send-push did not return the safe authorization error contract.");
}
if (body?.correlation_id !== traceId || response.headers.get("x-correlation-id") !== traceId) {
  throw new Error("send-push did not preserve the validated correlation ID.");
}

console.log(
  JSON.stringify({
    project_ref: projectRef,
    status: "PASS",
    http_status: response.status,
    safe_error_code: body.code,
    correlation_id_validated: true,
    secrets_printed: false,
  }),
);
