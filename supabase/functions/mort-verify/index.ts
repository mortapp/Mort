import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "../_shared/observability.ts";

const maxJsonBytes = 32 * 1024;
const maxDocumentBytes = 10 * 1024 * 1024;
const bucket = "mort-verify-evidence";

type Action =
  | "start"
  | "finalize_document"
  | "review_document_url";

type RequestBody = {
  action?: Action;
  email?: string;
  session_id?: string;
  storage_path?: string;
  side?: "front" | "back";
};

class VerifyError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

Deno.serve(async (request: Request) => {
  const traceId = correlationId(request);
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (request.method !== "POST") {
    return correlatedJson(
      { ok: false, code: "post_required" },
      405,
      traceId,
      corsHeaders(),
    );
  }

  try {
    const { user, userClient, serviceClient } = await authenticate(request);
    const body = await readJson(request);
    switch (body.action) {
      case "start":
        return await startVerification(
          user.id,
          userClient,
          serviceClient,
          body,
          traceId,
        );
      case "finalize_document":
        return await finalizeDocument(
          user.id,
          serviceClient,
          body,
          traceId,
        );
      case "review_document_url":
        return await reviewerDocumentUrl(
          user.id,
          serviceClient,
          body,
          traceId,
        );
      default:
        throw new VerifyError("unsupported_action", 400);
    }
  } catch (error) {
    if (error instanceof VerifyError) {
      return correlatedJson(
        { ok: false, code: error.code },
        error.status,
        traceId,
        corsHeaders(),
      );
    }
    structuredLog("error", "mort_verify.unhandled_failure", traceId, {
      kind: safeErrorKind(error),
    });
    return correlatedJson(
      { ok: false, code: "mort_verify_failed" },
      500,
      traceId,
      corsHeaders(),
    );
  }
});

async function authenticate(request: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    throw new VerifyError("server_not_configured", 503);
  }

  const authorization = request.headers.get("authorization") ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) throw new VerifyError("authentication_required", 401);
  const token = match[1];

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data.user) throw new VerifyError("invalid_session", 401);

  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { user: data.user, userClient, serviceClient };
}

async function readJson(request: Request): Promise<RequestBody> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > maxJsonBytes) {
    throw new VerifyError("payload_too_large", 413);
  }
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > maxJsonBytes) {
    throw new VerifyError("payload_too_large", 413);
  }
  try {
    const parsed = raw.trim() ? JSON.parse(raw) : {};
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new VerifyError("invalid_json", 400);
    }
    return parsed as RequestBody;
  } catch (error) {
    if (error instanceof VerifyError) throw error;
    throw new VerifyError("invalid_json", 400);
  }
}

async function startVerification(
  userId: string,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
  body: RequestBody,
  traceId: string,
) {
  const email = typeof body.email === "string"
    ? body.email.trim().toLowerCase()
    : "";
  if (!/^.{1,64}@[^@\s]{1,253}$/.test(email)) {
    throw new VerifyError("invalid_school_email", 400);
  }

  const apiKey = Deno.env.get("MORT_VERIFY_EMAIL_API_KEY");
  const from = Deno.env.get("MORT_VERIFY_EMAIL_FROM");
  if (!apiKey || !from) {
    throw new VerifyError("school_email_delivery_not_configured", 503);
  }

  const { data: started, error: startError } = await userClient.rpc(
    "start_mort_verify_teen_session",
    { p_school_email: email },
  );
  if (startError) {
    structuredLog("warn", "mort_verify.start_rpc_failed", traceId, {
      database_code: startError.code,
    });
    throw new VerifyError("session_start_failed", 503);
  }
  if (started?.ok !== true || typeof started?.session_id !== "string") {
    return correlatedJson(
      {
        ok: false,
        code: started?.code ?? "session_start_rejected",
        message: started?.message ?? null,
      },
      400,
      traceId,
      corsHeaders(),
    );
  }

  const code = randomEightDigitCode();
  const codeHash = await sha256Hex(code);
  const { data: challenge, error: challengeError } = await serviceClient.rpc(
    "service_mort_verify_issue_email_challenge",
    {
      p_user_id: userId,
      p_session_id: started.session_id,
      p_code_hash: codeHash,
    },
  );
  if (challengeError || challenge?.ok !== true) {
    structuredLog("warn", "mort_verify.challenge_create_failed", traceId, {
      database_code: challengeError?.code ?? null,
      safe_code: challenge?.code ?? null,
    });
    throw new VerifyError(
      challenge?.code ?? "email_challenge_unavailable",
      challenge?.code?.includes("rate") ||
          challenge?.code === "email_challenge_cooldown"
        ? 429
        : 503,
    );
  }

  const emailSent = await sendSchoolEmail({
    apiKey,
    from,
    to: challenge.email,
    schoolName: started.school ?? challenge.school_name ?? "your school",
    code,
  });
  await serviceClient.rpc("service_mort_verify_mark_email_delivery", {
    p_session_id: started.session_id,
    p_code_hash: codeHash,
    p_sent: emailSent,
  });

  if (!emailSent) {
    structuredLog("error", "mort_verify.email_delivery_failed", traceId, {
      session_id: started.session_id,
    });
    throw new VerifyError("school_email_delivery_failed", 503);
  }

  structuredLog("info", "mort_verify.school_email_sent", traceId, {
    session_id: started.session_id,
  });
  return correlatedJson(
    {
      ok: true,
      session_id: started.session_id,
      status: "email_pending",
      school: started.school,
      email_masked: started.email_masked,
      code_expires_in_seconds: 900,
      next_step: "verify_school_email_code",
    },
    200,
    traceId,
    corsHeaders(),
  );
}

async function finalizeDocument(
  userId: string,
  serviceClient: ReturnType<typeof createClient>,
  body: RequestBody,
  traceId: string,
) {
  const sessionId = body.session_id ?? "";
  const path = body.storage_path ?? "";
  const side = body.side;
  if (!uuidPattern.test(sessionId) || !side || !path) {
    throw new VerifyError("invalid_document_request", 400);
  }
  const expectedPrefix = `${userId}/${sessionId}/${side}/`;
  if (!path.startsWith(expectedPrefix) || path.includes("..")) {
    throw new VerifyError("invalid_storage_path", 400);
  }

  const { data: blob, error } = await serviceClient.storage
    .from(bucket)
    .download(path);
  if (error || !blob) throw new VerifyError("uploaded_object_not_found", 404);

  const bytes = new Uint8Array(await blob.arrayBuffer());
  if (bytes.length === 0 || bytes.length > maxDocumentBytes) {
    throw new VerifyError("invalid_document_size", 400);
  }
  const contentType = detectContentType(bytes);
  if (!contentType) throw new VerifyError("unsupported_document_type", 400);
  if (!extensionMatches(path, contentType)) {
    throw new VerifyError("document_extension_mismatch", 400);
  }
  const digest = await sha256Bytes(bytes);

  const { data: registered, error: registerError } = await serviceClient.rpc(
    "service_mort_verify_register_document",
    {
      p_user_id: userId,
      p_session_id: sessionId,
      p_storage_path: path,
      p_side: side,
      p_content_type: contentType,
      p_byte_size: bytes.length,
      p_sha256: digest,
    },
  );
  if (registerError || registered?.ok !== true) {
    structuredLog("warn", "mort_verify.document_register_failed", traceId, {
      database_code: registerError?.code ?? null,
      safe_code: registered?.code ?? null,
    });
    throw new VerifyError(
      registered?.code ?? "document_registration_failed",
      400,
    );
  }

  structuredLog("info", "mort_verify.document_registered", traceId, {
    session_id: sessionId,
    side,
    bytes: bytes.length,
  });
  return correlatedJson(
    {
      ok: true,
      document_id: registered.document_id,
      side,
      status: registered.status,
      next_step: "submit_when_ready",
    },
    200,
    traceId,
    corsHeaders(),
  );
}

async function reviewerDocumentUrl(
  reviewerId: string,
  serviceClient: ReturnType<typeof createClient>,
  body: RequestBody,
  traceId: string,
) {
  const sessionId = body.session_id ?? "";
  const side = body.side;
  if (!uuidPattern.test(sessionId) || !side) {
    throw new VerifyError("invalid_review_document_request", 400);
  }

  const { data: document, error } = await serviceClient.rpc(
    "service_mort_verify_get_review_document",
    {
      p_reviewer_id: reviewerId,
      p_session_id: sessionId,
      p_side: side,
    },
  );
  if (error || document?.ok !== true) {
    throw new VerifyError(
      document?.code ?? "review_document_unavailable",
      document?.code === "active_review_assignment_required" ? 403 : 404,
    );
  }

  const { data: signed, error: signedError } = await serviceClient.storage
    .from(document.bucket_id)
    .createSignedUrl(document.storage_path, 300);
  if (signedError || !signed?.signedUrl) {
    throw new VerifyError("signed_review_url_failed", 503);
  }

  structuredLog("info", "mort_verify.review_document_url_issued", traceId, {
    session_id: sessionId,
    document_id: document.document_id,
    side,
  });
  return correlatedJson(
    {
      ok: true,
      document_id: document.document_id,
      side,
      content_type: document.content_type,
      byte_size: document.byte_size,
      signed_url: signed.signedUrl,
      expires_in_seconds: 300,
    },
    200,
    traceId,
    corsHeaders(),
  );
}

async function sendSchoolEmail({
  apiKey,
  from,
  to,
  schoolName,
  code,
}: {
  apiKey: string;
  from: string;
  to: string;
  schoolName: string;
  code: string;
}) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Your MORT school verification code",
      text:
        `MORT Verify code: ${code}\n\nThis code expires in 15 minutes. ` +
        `It verifies access to the ${schoolName} email account only. ` +
        "It does not by itself prove your age or legal identity. " +
        "If you did not request this, ignore this email.",
    }),
  });
  return response.ok;
}

function randomEightDigitCode() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(values[0] % 100_000_000).padStart(8, "0");
}

async function sha256Hex(value: string) {
  return sha256Bytes(new TextEncoder().encode(value));
}

async function sha256Bytes(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function detectContentType(bytes: Uint8Array) {
  if (
    bytes.length >= 3 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) return "image/jpeg";
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) return "image/png";
  if (
    bytes.length >= 5 &&
    bytes[0] === 0x25 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x44 &&
    bytes[3] === 0x46 &&
    bytes[4] === 0x2d
  ) return "application/pdf";
  return null;
}

function extensionMatches(path: string, contentType: string) {
  const lower = path.toLowerCase();
  if (contentType === "image/jpeg") {
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg");
  }
  if (contentType === "image/png") return lower.endsWith(".png");
  if (contentType === "application/pdf") return lower.endsWith(".pdf");
  return false;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
