import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const batchLimit = 100;

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

  const { data: expired, error: listError } = await supabase.rpc(
    "service_list_expired_teen_school_id_objects",
    { p_limit: batchLimit },
  );
  if (listError) {
    console.error("teen verification retention list failed", {
      code: listError.code,
    });
    return json({ ok: false, code: "retention_list_failed" }, 503);
  }

  const rows = Array.isArray(expired) ? expired : [];
  if (rows.length === 0) {
    return json({ ok: true, removed: 0, remaining_hint: false }, 200);
  }

  const removedIds: string[] = [];
  const byBucket = new Map<string, Array<{ id: string; path: string }>>();

  for (const row of rows) {
    if (
      typeof row?.document_id !== "string" ||
      typeof row?.bucket_id !== "string" ||
      typeof row?.object_name !== "string"
    ) {
      continue;
    }
    const items = byBucket.get(row.bucket_id) ?? [];
    items.push({ id: row.document_id, path: row.object_name });
    byBucket.set(row.bucket_id, items);
  }

  for (const [bucket, items] of byBucket) {
    for (let index = 0; index < items.length; index += 100) {
      const slice = items.slice(index, index + 100);
      const { error: removeError } = await supabase.storage
        .from(bucket)
        .remove(slice.map((item) => item.path));
      if (removeError) {
        console.error("teen verification retention storage removal failed", {
          bucket,
          code: removeError.message,
        });
        return json(
          {
            ok: false,
            code: "retention_storage_remove_failed",
            removed_before_failure: removedIds.length,
          },
          503,
        );
      }
      removedIds.push(...slice.map((item) => item.id));
    }
  }

  const { data: finalized, error: finalizeError } = await supabase.rpc(
    "service_finalize_teen_school_id_purge",
    { p_document_ids: removedIds },
  );
  if (finalizeError || finalized?.ok !== true) {
    console.error("teen verification retention finalize failed", {
      code: finalizeError?.code ?? finalized?.code ?? "unknown",
    });
    return json(
      {
        ok: false,
        code: "retention_finalize_failed",
        storage_objects_removed: removedIds.length,
      },
      503,
    );
  }

  return json(
    {
      ok: true,
      removed: Number(finalized.purged ?? 0),
      remaining_hint: rows.length === batchLimit,
    },
    200,
  );
});

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
