import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";
import {
  fetchAdMobKeys,
  verifyAdMobCallback,
} from "../_shared/admob_ssv.ts";

// Google calls this endpoint directly. A valid ECDSA signature, current key,
// configured ad unit, and unique transaction ID are required to grant Spark.
Deno.serve(async (request: Request) => {
  if (request.method !== "GET") {
    return Response.json({ ok: false, code: "get_required" }, { status: 405 });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const adUnits = (Deno.env.get("ADMOB_REWARDED_AD_UNIT_IDS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean);
  if (!url || !serviceKey || adUnits.length === 0) {
    return Response.json({ ok: false, code: "ssv_not_configured" }, {
      status: 503,
    });
  }
  try {
    const queryStart = request.url.indexOf("?");
    if (queryStart < 0) throw new Error("Missing callback query");
    const event = await verifyAdMobCallback(
      request.url.slice(queryStart + 1),
      adUnits,
      await fetchAdMobKeys(),
    );
    const supabase = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await supabase.rpc("process_mort_spark_ssv", {
      p_transaction_id: event.transactionId,
      p_user_id: event.userId,
      p_ad_unit_id: event.adUnitId,
      p_rewarded_at: event.rewardedAt,
    });
    if (error) {
      return Response.json({ ok: false, code: "reward_processing_failed" }, {
        status: 503,
      });
    }
    return Response.json(data);
  } catch (_) {
    return Response.json({ ok: false, code: "ssv_rejected" }, {
      status: 401,
    });
  }
});
