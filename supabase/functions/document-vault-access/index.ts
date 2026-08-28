import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

type AccessRequest = {
  caseId?: string;
  vaultObjectId?: string;
  action?: "view" | "download";
  reason?: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !anonKey || !serviceRoleKey) {
  throw new Error(
    "SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY must be configured as server-only Edge Function secrets.",
  );
}

const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "POST required" }, 405);

  const authorization = request.headers.get("authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Authenticated reviewer required" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) {
    return json({ error: "Authenticated reviewer required" }, 401);
  }

  const readiness = await userClient.rpc("get_document_collection_readiness");
  if (
    readiness.error ||
    readiness.data?.ready !== true ||
    readiness.data?.real_document_collection_enabled !== true
  ) {
    return json(
      {
        error: "Real document collection and vault delivery are disabled until operational readiness.",
        code: "document_collection_disabled",
      },
      423,
    );
  }

  const payload = await readPayload(request);
  if (
    !isUUID(payload.caseId) ||
    !isUUID(payload.vaultObjectId) ||
    !["view", "download"].includes(payload.action ?? "") ||
    (payload.reason?.trim().length ?? 0) < 12
  ) {
    return json({ error: "Case, object, action, and a specific access reason are required" }, 400);
  }

  const grant = await userClient.rpc("request_document_vault_access", {
    p_case_id: payload.caseId,
    p_vault_object_id: payload.vaultObjectId,
    p_access_action: payload.action,
    p_access_reason: payload.reason?.trim(),
  });
  if (grant.error || grant.data?.ok !== true || !isUUID(grant.data?.grant_id)) {
    return json(
      {
        error: "Vault access was not authorized",
        code: grant.data?.code ?? "vault_access_not_authorized",
      },
      403,
    );
  }

  const exchange = await serviceClient.rpc("consume_document_vault_access_grant", {
    p_grant_id: grant.data.grant_id,
  });
  if (
    exchange.error ||
    exchange.data?.ok !== true ||
    exchange.data?.reviewer_id !== userData.user.id ||
    exchange.data?.case_id !== payload.caseId
  ) {
    await recordDelivery(grant.data.grant_id, false, "grant_exchange_rejected");
    return json({ error: "Vault grant exchange failed" }, 403);
  }

  const expiresIn = Math.min(
    Math.max(Number(exchange.data.signed_url_max_seconds) || 1, 1),
    60,
  );
  const signed = await serviceClient.storage
    .from(exchange.data.bucket)
    .createSignedUrl(exchange.data.storage_path, expiresIn, {
      download: payload.action === "download",
    });

  if (signed.error || !signed.data?.signedUrl) {
    await recordDelivery(grant.data.grant_id, false, "signed_url_creation_failed");
    return json({ error: "Private vault delivery failed" }, 500);
  }

  await recordDelivery(grant.data.grant_id, true, "edge_signed_delivery");
  console.info("document-vault-access delivered one audited short-lived grant");
  return json({
    ok: true,
    action: payload.action,
    expiresIn,
    signedUrl: signed.data.signedUrl,
    publicUrl: false,
    oneTimeGrantConsumed: true,
  });
});

async function readPayload(request: Request): Promise<AccessRequest> {
  try {
    return (await request.json()) as AccessRequest;
  } catch {
    return {};
  }
}

async function recordDelivery(
  grantId: string,
  delivered: boolean,
  reference: string,
) {
  await serviceClient.rpc("record_document_vault_delivery", {
    p_grant_id: grantId,
    p_delivered: delivered,
    p_event_reference: reference,
  });
}

function isUUID(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    )
  );
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store, max-age=0",
      Pragma: "no-cache",
    },
  });
}
