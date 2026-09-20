import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const batchLimit = 100;

type RetentionRow = {
  document_id: string;
  bucket_id: string;
  object_name: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ ok: false, code: "post_required" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ ok: false, code: "retention_worker_not_configured" }, 503);
  }

  const authorization = request.headers.get("authorization") ?? "";
  if (!constantTimeEqual(authorization, `Bearer ${serviceRoleKey}`)) {
    return json({ ok: false, code: "service_role_required" }, 403);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const legacy = await purgeRetentionSet({
    supabase,
    listRpc: "service_list_expired_teen_school_id_objects",
    finalizeRpc: "service_finalize_teen_school_id_purge",
    label: "legacy_teen_school_id",
  });
  if (!legacy.ok) return json(legacy, 503);

  const canonical = await purgeRetentionSet({
    supabase,
    listRpc: "service_list_expired_mort_verify_documents",
    finalizeRpc: "service_finalize_mort_verify_document_purge",
    label: "mort_verify",
  });
  if (!canonical.ok) return json(canonical, 503);

  return json(
    {
      ok: true,
      removed: legacy.removed + canonical.removed,
      legacy_removed: legacy.removed,
      canonical_removed: canonical.removed,
      remaining_hint: legacy.remaining_hint || canonical.remaining_hint,
    },
    200,
  );
});

async function purgeRetentionSet({
  supabase,
  listRpc,
  finalizeRpc,
  label,
}: {
  supabase: ReturnType<typeof createClient>;
  listRpc: string;
  finalizeRpc: string;
  label: string;
}): Promise<
  | { ok: true; removed: number; remaining_hint: boolean }
  | {
      ok: false;
      code: string;
      retention_set: string;
      removed_before_failure?: number;
      storage_objects_removed?: number;
    }
> {
  const { data: expired, error: listError } = await supabase.rpc(listRpc, {
    p_limit: batchLimit,
  });
  if (listError) {
    console.error("verification retention list failed", {
      retention_set: label,
      code: listError.code,
    });
    return {
      ok: false,
      code: "retention_list_failed",
      retention_set: label,
    };
  }

  const rows = Array.isArray(expired) ? expired : [];
  if (rows.length === 0) {
    return { ok: true, removed: 0, remaining_hint: false };
  }

  const normalized: RetentionRow[] = [];
  for (const row of rows) {
    if (
      typeof row?.document_id !== "string" ||
      typeof row?.bucket_id !== "string" ||
      typeof row?.object_name !== "string"
    ) {
      console.error("verification retention row malformed", {
        retention_set: label,
      });
      return {
        ok: false,
        code: "retention_row_invalid",
        retention_set: label,
      };
    }
    normalized.push({
      document_id: row.document_id,
      bucket_id: row.bucket_id,
      object_name: row.object_name,
    });
  }

  const removedIds: string[] = [];
  const byBucket = new Map<string, RetentionRow[]>();
  for (const row of normalized) {
    const items = byBucket.get(row.bucket_id) ?? [];
    items.push(row);
    byBucket.set(row.bucket_id, items);
  }

  for (const [bucket, items] of byBucket) {
    for (let index = 0; index < items.length; index += 100) {
      const slice = items.slice(index, index + 100);
      const { error: removeError } = await supabase.storage
        .from(bucket)
        .remove(slice.map((item) => item.object_name));
      if (removeError) {
        console.error("verification retention storage removal failed", {
          retention_set: label,
          bucket,
          code: removeError.message,
        });
        return {
          ok: false,
          code: "retention_storage_remove_failed",
          retention_set: label,
          removed_before_failure: removedIds.length,
        };
      }
      removedIds.push(...slice.map((item) => item.document_id));
    }
  }

  const { data: finalized, error: finalizeError } = await supabase.rpc(
    finalizeRpc,
    { p_document_ids: removedIds },
  );
  if (finalizeError || finalized?.ok !== true) {
    console.error("verification retention finalize failed", {
      retention_set: label,
      code: finalizeError?.code ?? finalized?.code ?? "unknown",
    });
    return {
      ok: false,
      code: "retention_finalize_failed",
      retention_set: label,
      storage_objects_removed: removedIds.length,
    };
  }

  return {
    ok: true,
    removed: Number(finalized.purged ?? 0),
    remaining_hint: rows.length === batchLimit,
  };
}

function constantTimeEqual(left: string, right: string) {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  let mismatch = leftBytes.length ^ rightBytes.length;
  const length = Math.max(leftBytes.length, rightBytes.length);
  for (let index = 0; index < length; index += 1) {
    mismatch |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }
  return mismatch === 0;
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
