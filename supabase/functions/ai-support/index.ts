import OpenAI from "npm:openai@6.48.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class PublicError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function uuid(value: unknown, field: string) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new PublicError(`invalid_${field}`, 400);
  }
  return value;
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ ok: false, code: "post_required" }, 405);

  let reservationClient: ReturnType<typeof createClient> | null = null;
  let reservationId: string | null = null;
  let reservationFinalized = false;
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) throw new PublicError("server_not_configured", 503);

    const authorization = request.headers.get("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token) throw new PublicError("authentication_required", 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    reservationClient = serviceClient;
    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) throw new PublicError("invalid_session", 401);

    const bodyText = await request.text();
    if (new TextEncoder().encode(bodyText).byteLength > 16 * 1024) {
      throw new PublicError("payload_too_large", 413);
    }
    let body: Record<string, unknown>;
    try {
      body = bodyText.trim() ? JSON.parse(bodyText) : {};
    } catch {
      throw new PublicError("invalid_json", 400);
    }

    const { data: config, error: configError } = await userClient.rpc("get_mort_guide_config");
    if (configError || config?.ok !== true) throw new PublicError("mort_guide_unavailable", 503);
    if (body.action === "config") return json(config);

    const question = typeof body.question === "string" ? body.question.trim() : "";
    if (question.length < 3 || question.length > 500) throw new PublicError("invalid_question", 400);
    const clientRequestId = uuid(body.client_request_id, "client_request_id");
    const conversationId = body.conversation_id == null ? null : uuid(body.conversation_id, "conversation_id");

    if (config.mode === "disabled") throw new PublicError("mort_guide_disabled", 503);
    const requiresDeterministicSafetyFlow =
      /(suicid|kill myself|kill someone|kidnap|immediate danger|weapon|gun|being followed|traffick|password|social security|ssn|passport|driver.?s license|exact address|auth token|card number|cvc|who should i hire|rank (the )?applicants|approve (my )?id|decide (the )?dispute|is this person dangerous)/i
        .test(question);
    if (
      config.mode === "faq_only" ||
      config.external_provider_available !== true ||
      requiresDeterministicSafetyFlow
    ) {
      const { data, error } = await userClient.rpc("ask_mort_guide_faq", {
        p_question: question,
        p_conversation_id: conversationId,
        p_client_request_id: clientRequestId,
      });
      if (error) throw new PublicError("faq_request_failed", 503);
      return json(data, data?.ok === true ? 200 : 400);
    }

    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("role,is_test_account")
      .eq("id", authData.user.id)
      .single();
    if (profileError || !profile) throw new PublicError("profile_unavailable", 403);
    if (config.mode === "sandbox" && profile.is_test_account !== true) {
      throw new PublicError("sandbox_qa_only", 403);
    }
    if (profile.role === "teen" && config.consent_status !== "approved") {
      throw new PublicError("minor_ai_consent_required", 403);
    }

    const apiKey = Deno.env.get("OPENAI_API_KEY");
    if (!apiKey) {
      const { data, error } = await userClient.rpc("ask_mort_guide_faq", {
        p_question: question,
        p_conversation_id: conversationId,
        p_client_request_id: clientRequestId,
      });
      if (error) throw new PublicError("provider_not_configured", 503);
      return json({ ...data, provider_fallback: true });
    }

    const { data: reservation, error: reservationError } = await userClient.rpc(
      "reserve_mort_guide_provider_request",
      {
        p_client_request_id: clientRequestId,
        p_input_characters: question.length,
      },
    );
    if (reservationError) throw new PublicError("provider_control_unavailable", 503);
    if (reservation?.ok !== true) {
      const { data, error } = await userClient.rpc("ask_mort_guide_faq", {
        p_question: question,
        p_conversation_id: conversationId,
        p_client_request_id: clientRequestId,
      });
      if (error || data?.ok !== true) {
        throw new PublicError(reservation?.code ?? data?.code ?? "provider_limited", 429);
      }
      return json({ ...data, provider_fallback: true });
    }
    reservationId = uuid(reservation.reservation_id, "reservation_id");
    const model = typeof reservation.approved_model === "string" ? reservation.approved_model : "";
    const maxInputTokens = Number(reservation.max_input_tokens);
    const maxOutputTokens = Number(reservation.max_output_tokens);
    const timeoutSeconds = Number(reservation.timeout_seconds);
    if (
      !model ||
      !Number.isFinite(maxInputTokens) ||
      !Number.isFinite(maxOutputTokens) ||
      !Number.isFinite(timeoutSeconds)
    ) {
      throw new PublicError("provider_limits_invalid", 503);
    }
    if (question.length > maxInputTokens * 4) throw new PublicError("question_too_long", 400);

    const provider = new OpenAI({ apiKey, timeout: Math.trunc(timeoutSeconds * 1000), maxRetries: 1 });
    const startedAt = Date.now();
    const inputModeration = await provider.moderations.create({
      model: "omni-moderation-latest",
      input: question,
    });
    if (inputModeration.results.some((result) => result.flagged)) {
      await serviceClient.rpc("mort_guide_server_finalize_provider_request", {
        p_reservation_id: reservationId,
        p_outcome: "input_blocked",
      });
      reservationFinalized = true;
      await serviceClient.from("ai_safety_events").insert({
        user_id: authData.user.id,
        direction: "input",
        category: "provider_moderation_flagged",
        action: "blocked",
        scanner: "openai_omni_moderation",
        requires_adult_review: false,
      });
      throw new PublicError("unsafe_input", 400);
    }

    const { data: sources, error: sourceError } = await serviceClient
      .from("ai_knowledge_sources")
      .select("id,title,source_url,answer_text")
      .eq("approval_status", "approved")
      .gte("review_due_at", new Date().toISOString().slice(0, 10))
      .limit(10);
    if (sourceError || !sources?.length) throw new PublicError("knowledge_base_unavailable", 503);
    const approvedContext = sources
      .map((source) => `${source.title}\n${source.answer_text}\nSource: ${source.source_url}`)
      .join("\n\n");

    const response = await provider.responses.create({
      model,
      store: false,
      max_output_tokens: Math.trunc(maxOutputTokens),
      instructions:
        "You are MORT Guide for a teen-safe local job app. Answer only from the approved MORT context. Never rank applicants, approve identity, decide moderation or payment disputes, determine danger, provide legal or medical decisions, or claim emergency dispatch. Never ask for IDs, passwords, exact addresses, private messages, incident evidence, payment credentials, or auth tokens. Keep the answer brief, cite the provided MORT source URL, and direct immediate danger to local emergency services and MORT Safety Center.",
      input: `Approved MORT context:\n${approvedContext}\n\nUser question:\n${question}`,
    });
    const answer = response.output_text.trim();
    if (!answer || answer.length > 4000) throw new PublicError("provider_output_invalid", 503);

    const outputModeration = await provider.moderations.create({
      model: "omni-moderation-latest",
      input: answer,
    });
    if (outputModeration.results.some((result) => result.flagged)) {
      await serviceClient.rpc("mort_guide_server_finalize_provider_request", {
        p_reservation_id: reservationId,
        p_outcome: "output_blocked",
        p_input_tokens: response.usage?.input_tokens ?? null,
        p_output_tokens: response.usage?.output_tokens ?? null,
      });
      reservationFinalized = true;
      await serviceClient.from("ai_provider_events").insert({
        user_id: authData.user.id,
        provider: "openai",
        model,
        request_hash: await sha256(question),
        response_hash: await sha256(answer),
        store_disabled: true,
        moderation_input_passed: true,
        moderation_output_passed: false,
        outcome: "output_blocked",
        latency_ms: Date.now() - startedAt,
      });
      throw new PublicError("unsafe_output", 503);
    }

    let activeConversationId = conversationId;
    if (activeConversationId) {
      const { data: owned } = await serviceClient
        .from("ai_conversations")
        .select("id")
        .eq("id", activeConversationId)
        .eq("user_id", authData.user.id)
        .maybeSingle();
      if (!owned) throw new PublicError("conversation_not_found", 404);
    } else {
      const { data: created, error } = await serviceClient
        .from("ai_conversations")
        .insert({ user_id: authData.user.id, mode: config.mode })
        .select("id")
        .single();
      if (error || !created) throw new PublicError("history_write_failed", 503);
      activeConversationId = created.id;
    }

    const { data: messages, error: messageError } = await serviceClient
      .from("ai_messages")
      .insert([
        { conversation_id: activeConversationId, user_id: authData.user.id, role: "user", content: question },
        { conversation_id: activeConversationId, user_id: authData.user.id, role: "assistant", content: answer, provider_generated: true },
      ])
      .select("id,role");
    if (messageError) throw new PublicError("history_write_failed", 503);
    const answerMessageId = messages?.find((message) => message.role === "assistant")?.id;

    const { data: finalized, error: finalizeError } = await serviceClient.rpc(
      "mort_guide_server_finalize_provider_request",
      {
        p_reservation_id: reservationId,
        p_outcome: "answered",
        p_conversation_id: activeConversationId,
        p_input_tokens: response.usage?.input_tokens ?? null,
        p_output_tokens: response.usage?.output_tokens ?? null,
      },
    );
    if (finalizeError || finalized !== true) {
      throw new PublicError("provider_usage_finalize_failed", 503);
    }
    reservationFinalized = true;
    await serviceClient.from("ai_provider_events").insert({
      user_id: authData.user.id,
      conversation_id: activeConversationId,
      provider: "openai",
      model,
      request_hash: await sha256(question),
      response_hash: await sha256(answer),
      provider_request_id: response.id,
      store_disabled: true,
      moderation_input_passed: true,
      moderation_output_passed: true,
      outcome: "answered",
      latency_ms: Date.now() - startedAt,
    });

    return json({
      ok: true,
      mode: config.mode,
      conversation_id: activeConversationId,
      message_id: answerMessageId,
      answer,
      provider_generated: true,
      warning: "AI may make mistakes. MORT Guide is not emergency, legal, or medical assistance.",
    });
  } catch (error) {
    if (reservationClient && reservationId && !reservationFinalized) {
      try {
        await reservationClient.rpc("mort_guide_server_finalize_provider_request", {
          p_reservation_id: reservationId,
          p_outcome: error instanceof DOMException && error.name === "TimeoutError"
            ? "timeout"
            : "provider_error",
        });
      } catch {
        // The original sanitized request error remains authoritative.
      }
    }
    if (error instanceof PublicError) return json({ ok: false, code: error.code }, error.status);
    console.error("MORT Guide request failed", { kind: error instanceof Error ? error.name : "unknown" });
    return json({ ok: false, code: "mort_guide_request_failed" }, 500);
  }
});
