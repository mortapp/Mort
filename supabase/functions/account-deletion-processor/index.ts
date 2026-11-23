import { createClient } from "npm:@supabase/supabase-js@2.110.1";
import {
  constantTimeEqual,
  correlatedJson,
  correlationId,
  safeErrorKind,
  structuredLog,
} from "./observability.ts";
import { readDeletionRequest } from "./request.ts";
import { removeAndConfirmAuthIdentity } from "./auth_identity.ts";

type ClaimedRequest = {
  id: string;
  user_id: string;
  attempt_count: number;
  processor_lock_id: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const workerSecret = Deno.env.get("ACCOUNT_DELETION_WORKER_SECRET");

const supabase = supabaseUrl && serviceRoleKey
  ? createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: (input, init) =>
          fetch(input, {
            ...init,
            signal: init?.signal
              ? AbortSignal.any([init.signal, AbortSignal.timeout(12_000)])
              : AbortSignal.timeout(12_000),
          }),
      },
    })
  : null;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  const traceId = correlationId(request);
  if (request.method !== "POST") {
    return correlatedJson({ ok: false, code: "post_required" }, 405, traceId);
  }
  if (!supabase || !workerSecret) {
    return correlatedJson(
      { ok: false, code: "deletion_worker_not_configured" },
      503,
      traceId,
    );
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
    const payload = await readDeletionRequest(request);
    if (!payload.ok) {
      return correlatedJson(
        { ok: false, code: payload.code },
        payload.status,
        traceId,
      );
    }
    const { data, error } = await supabase.rpc(
      "service_claim_account_deletion_request",
      { p_request_id: payload.requestId },
    );
    if (error) throw error;
    if (data?.ok !== true) {
      if (data?.ok !== false || data?.code !== "deletion_request_unavailable") {
        throw new Error("DeletionClaimUnconfirmed");
      }
      return correlatedJson(
        { ok: true, processed: 0, code: data.code },
        200,
        traceId,
      );
    }
    const candidate = data.request;
    if (
      !candidate ||
      ![candidate.id, candidate.user_id, candidate.processor_lock_id]
        .every((value) =>
          typeof value === "string" && uuidPattern.test(value)
        ) ||
      !Number.isInteger(candidate.attempt_count)
    ) {
      throw new Error("DeletionClaimMalformed");
    }
    const job = candidate as ClaimedRequest;
    claimed = job;
    const deadline = Date.now() + 100_000;
    const assertLease = async () => {
      if (Date.now() >= deadline) throw new Error("DeletionWorkerDeadline");
      const { data, error } = await supabase.rpc(
        "service_assert_account_deletion_lease",
        {
          p_request_id: job.id,
          p_processor_lock_id: job.processor_lock_id,
        },
      );
      if (error || data !== true) {
        throw error ?? new Error("DeletionLeaseExpired");
      }
    };
    stage = "financial_retention";
    await assertLease();
    const { data: retention, error: retentionError } = await supabase.rpc(
      "service_check_account_deletion_financial_retention",
      { p_user_id: job.user_id },
    );
    if (
      retentionError || retention?.ok !== true ||
      typeof retention.retention_review_required !== "boolean"
    ) {
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
    const removedStorageObjects = await removeOwnedStorage(
      supabase,
      job.user_id,
      assertLease,
    );
    stage = "auth_delete";
    await removeAndConfirmAuthIdentity(
      supabase.auth.admin,
      job.user_id,
      assertLease,
    );

    const summary =
      `Ordinary account data and Auth identity deleted; owned storage objects removed: ${removedStorageObjects}. ` +
      "Legally required safety, fraud, and audit records may remain de-identified under the retention matrix.";
    stage = "complete";
    await assertLease();
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
    const errorCode = `deletion_${stage}_failed`;
    if (claimed) {
      try {
        const result = await supabase.rpc(
          "service_fail_account_deletion_request",
          {
            p_request_id: claimed.id,
            p_processor_lock_id: claimed.processor_lock_id,
            p_error_code: errorCode,
          },
        );
        if (result.error || result.data?.ok !== true) {
          structuredLog("warn", "deletion.failure_state_not_recorded", traceId);
        }
      } catch {
        structuredLog("warn", "deletion.failure_state_not_recorded", traceId);
      }
    }
    structuredLog("error", "deletion.failed", traceId, {
      kind: safeErrorKind(error),
      code: errorCode,
    });
    return correlatedJson({ ok: false, code: errorCode }, 500, traceId);
  }
});

async function removeOwnedStorage(
  client: NonNullable<typeof supabase>,
  userId: string,
  assertLease: () => Promise<void>,
) {
  let removed = 0;
  let lastPage: string | null = null;
  while (true) {
    await assertLease();
    const { data, error } = await client.rpc(
      "service_list_account_deletion_storage_objects",
      { p_user_id: userId, p_limit: 500 },
    );
    if (error) throw error;
    if (!Array.isArray(data)) {
      throw new Error("DeletionStorageListingUnconfirmed");
    }
    const objects = data;
    if (objects.length === 0) return removed;
    const page = JSON.stringify(objects);
    if (page === lastPage) {
      throw new Error("DeletionStorageRemovalDidNotProgress");
    }
    lastPage = page;

    const byBucket = new Map<string, string[]>();
    for (const object of objects) {
      if (
        typeof object?.bucket_id !== "string" || !object.bucket_id ||
        typeof object?.object_name !== "string" || !object.object_name
      ) {
        throw new Error("DeletionStorageListingMalformed");
      }
      const paths = byBucket.get(object.bucket_id) ?? [];
      paths.push(object.object_name);
      byBucket.set(object.bucket_id, paths);
    }
    for (const [bucket, paths] of byBucket) {
      for (let index = 0; index < paths.length; index += 100) {
        await assertLease();
        const { error: removeError } = await client.storage
          .from(bucket)
          .remove(paths.slice(index, index + 100));
        if (removeError) throw removeError;
      }
    }
    removed += objects.length;
  }
}
