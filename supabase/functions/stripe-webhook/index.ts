import {
  json,
  safeError,
  serviceClient,
  sha256,
  webhookRuntime,
} from "../_shared/stripe.ts";
import { observe, targetFor } from "./observation.ts";
import { verifyWebhookEvent } from "./verification.ts";

const maximumWebhookBytes = 512 * 1024;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json({ ok: false, code: "post_required" }, 405);
  }
  let claim: { environment: string; id: string; token: string } | undefined;
  try {
    const runtime = webhookRuntime();
    const environment = runtime.environment;
    const signature = request.headers.get("Stripe-Signature");
    if (!signature) {
      return json({ ok: false, code: "stripe_signature_required" }, 401);
    }
    const length = Number(request.headers.get("content-length") ?? "0");
    if (Number.isFinite(length) && length > maximumWebhookBytes) {
      return json({ ok: false, code: "payload_too_large" }, 413);
    }
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).byteLength > maximumWebhookBytes) {
      return json({ ok: false, code: "payload_too_large" }, 413);
    }

    const { event, source } = await verifyWebhookEvent(
      runtime.stripe,
      rawBody,
      signature,
      {
        platform: runtime.webhookSecret,
        connect: runtime.connectWebhookSecret,
      },
    );
    if (event.livemode !== (environment === "live")) {
      return json({ ok: false, code: "stripe_environment_mismatch" }, 400);
    }
    const target = targetFor(event, source);
    if (!target) {
      return json({
        ok: false,
        code: "webhook_event_source_or_object_mismatch",
      }, 400);
    }
    const supabase = serviceClient();
    const claimed = await rpc(
      supabase,
      "stripe_server_claim_webhook_event_v3",
      {
        p_environment: environment,
        p_provider_event_id: event.id,
        p_event_type: event.type,
        p_provider_created_at: new Date(event.created * 1000).toISOString(),
        p_payload_sha256: await sha256(rawBody),
        p_resource_key: target.key,
      },
    );
    if (claimed?.claimed !== true) {
      if (
        claimed?.processing_status === "processed" ||
        claimed?.processing_status === "ignored"
      ) {
        return json({ ok: true, duplicate: true });
      }
      // An active, recoverable claim is not a completed duplicate.
      return json({ ok: false, code: "webhook_retry_required" }, 503);
    }
    if (typeof claimed.lease_token !== "string") {
      throw new Error("webhook_lease_token_missing");
    }
    claim = { environment, id: event.id, token: claimed.lease_token };

    const outcome = await observe(
      runtime.stripe,
      target,
      environment,
      event.type,
    );
    await rpc(supabase, "stripe_server_finish_webhook_observation_v3", {
      p_environment: claim.environment,
      p_provider_event_id: claim.id,
      p_lease_token: claim.token,
      p_observation: outcome,
    });
    return json({ ok: true, event_id: claim.id });
  } catch (error) {
    if (claim) {
      const args = {
        p_environment: claim.environment,
        p_provider_event_id: claim.id,
        p_lease_token: claim.token,
        p_observation: null,
      };
      try {
        await rpc(
          serviceClient(),
          "stripe_server_finish_webhook_observation_v3",
          args,
        );
      } catch {
        // The old lease cannot change a newer worker's result. Stripe retries non-2xx deliveries.
      }
      safeError(error);
      return json(
        { ok: false, code: "webhook_processing_retry_required" },
        503,
      );
    }
    return safeError(error);
  }
});

async function rpc(
  client: ReturnType<typeof serviceClient>,
  name: string,
  parameters: Record<string, unknown>,
) {
  const { data, error } = await client.rpc(name, parameters);
  if (error) throw error;
  if (data?.ok !== true) throw new Error("webhook_rpc_not_acknowledged");
  return data;
}
