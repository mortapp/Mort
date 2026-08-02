import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  constantTimeEqual,
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "../_shared/observability.ts";

type WorkerPayload = { requestId?: string };
type ClaimedRequest = {
  id: string;
  user_id: string | null;
  attempt_count: number;
  processor_lock_id: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const workerSecret = Deno.env.get("ACCOUNT_DELETION_WORKER_SECRET");

if (!supabaseUrl || !serviceRoleKey || !workerSecret) {
  throw new Error("Account deletion worker secrets are not configured.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method !== "POST") {
    return correlatedJson({ ok: false, code: "post_required" }, 405, traceId);
  }
  const suppliedSecret = request.headers.get("x-mort-deletion-secret") ?? "";
  if (!constantTimeEqual(workerSecret, suppliedSecret)) {
    structuredLog("warn", "deletion.authorization_rejected", traceId);
    return correlatedJson(
      { ok: false, code: "deletion_worker_authorization_required" },
      401,
      traceId,
    );
  }

  let claimed: ClaimedRequest | null = null;
  let stage = "claim";
  try {
    const payload = await readPayload(request);
    const { data, error } = await supabase.rpc(
      "service_claim_account_deletion_request",
      { p_request_id: payload.requestId ?? null },
    );
    if (error) throw error;
    if (data?.ok !== true) {
      return correlatedJson(
        { ok: true, processed: 0, code: data?.code ?? "deletion_request_unavailable" },
        200,
        traceId,
      );
    }
    claimed = data.request as ClaimedRequest;

    let removedStorageObjects = 0;
    if (claimed.user_id) {
      stage = "financial_retention";
      const { data: retention, error: retentionError } = await supabase.rpc(
        "service_check_account_deletion_financial_retention",
        { p_user_id: claimed.user_id },
      );
      if (retentionError || retention?.ok !== true) {
        throw retentionError ?? new Error("FinancialRetentionCheckFailed");
      }
      if (retention.retention_review_required === true) {
        const { data: held, error: holdError } = await supabase.rpc(
          "service_hold_account_deletion_for_financial_retention",
          {
            p_request_id: claimed.id,
            p_processor_lock_id: claimed.processor_lock_id,
          },
        );
        if (holdError || held?.ok !== true) {
          throw holdError ?? new Error("FinancialRetentionHoldFailed");
        }
        structuredLog("info", "deletion.retention_review", traceId, {
          attempt: claimed.attempt_count,
        });
        return correlatedJson(
          {
            ok: true,
            processed: 0,
            code: "financial_retention_review_required",
          },
          200,
          traceId,
        );
      }
      stage = "storage";
      removedStorageObjects = await removeOwnedStorage(claimed.user_id);
      stage = "auth_delete";
      const { data: authUser } = await supabase.auth.admin.getUserById(
        claimed.user_id,
      );
      if (authUser?.user) {
        const { error: deleteError } = await supabase.auth.admin.deleteUser(
          claimed.user_id,
          false,
        );
        if (deleteError) throw deleteError;
      }
    }

    const summary =
      `Ordinary account data and Auth identity deleted; owned storage objects removed: ${removedStorageObjects}. ` +
      "Legally required safety, fraud, and audit records may remain de-identified under the retention matrix.";
    stage = "complete";
    const { data: completion, error: completionError } = await supabase.rpc(
      "service_complete_account_deletion_request",
      {
        p_request_id: claimed.id,
        p_processor_lock_id: claimed.processor_lock_id,
        p_retention_summary: summary,
      },
    );
    if (completionError || completion?.ok !== true) {
      throw completionError ?? new Error("DeletionCompletionFailed");
    }

    structuredLog("info", "deletion.completed", traceId, {
      attempt: claimed.attempt_count,
      removed_storage_objects: removedStorageObjects,
    });
    return correlatedJson(
      { ok: true, processed: 1, removedStorageObjects },
      200,
      traceId,
    );
  } catch (error) {
    const errorCode = error instanceof DeletionWorkerError
      ? error.code
      : `deletion_${stage}_failed`;
    if (claimed) {
      await supabase.rpc("service_fail_account_deletion_request", {
        p_request_id: claimed.id,
        p_processor_lock_id: claimed.processor_lock_id,
        p_error_code: errorCode,
      });
    }
    structuredLog("error", "deletion.failed", traceId, {
      kind: safeErrorKind(error),
      code: errorCode,
    });
    return correlatedJson({ ok: false, code: errorCode }, 500, traceId);
  }
});

async function readPayload(request: Request): Promise<WorkerPayload> {
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > 4096) {
    throw new DeletionWorkerError("payload_too_large");
  }
  if (!text.trim()) return {};
  const parsed = JSON.parse(text);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new DeletionWorkerError("invalid_json_object");
  }
  const requestId = (parsed as WorkerPayload).requestId;
  if (requestId != null && !uuidPattern.test(requestId)) {
    throw new DeletionWorkerError("invalid_request_id");
  }
  return { requestId };
}

async function removeOwnedStorage(userId: string) {
  let removed = 0;
  while (true) {
    const { data, error } = await supabase.rpc(
      "service_list_account_deletion_storage_objects",
      { p_user_id: userId, p_limit: 500 },
    );
    if (error) throw error;
    const objects = data ?? [];
    if (objects.length === 0) return removed;

    const byBucket = new Map<string, string[]>();
    for (const object of objects) {
      const paths = byBucket.get(object.bucket_id) ?? [];
      paths.push(object.object_name);
      byBucket.set(object.bucket_id, paths);
    }
    for (const [bucket, paths] of byBucket) {
      for (let index = 0; index < paths.length; index += 100) {
        const { error: removeError } = await supabase.storage
          .from(bucket)
          .remove(paths.slice(index, index + 100));
        if (removeError) throw removeError;
      }
    }
    removed += objects.length;
  }
}

class DeletionWorkerError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "DeletionWorkerError";
  }
}
