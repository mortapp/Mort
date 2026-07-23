import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

type PushRequest = {
  notificationId?: string;
  userId?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
  batchSize?: number;
};

type NotificationEvent = {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
};

type ExpoPushResult = {
  data?: Array<{ status?: string; message?: string; details?: { error?: string } }>;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const invokeSecret = Deno.env.get("SEND_PUSH_INVOKE_SECRET");

if (!supabaseUrl || !serviceRoleKey || !invokeSecret) {
  throw new Error("SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SEND_PUSH_INVOKE_SECRET must be configured as Edge Function secrets.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "POST required" }, 405);
  }

  if (request.headers.get("x-mort-push-secret") !== invokeSecret) {
    return json({ error: "Unauthorized push invocation." }, 401);
  }

  const payload = await readPayload(request);

  try {
    if (payload.notificationId || payload.userId) {
      const result = await processSingle(payload);
      console.info("send-push processed single notification request.");
      return json({ ok: true, processed: 1, result });
    }

    const results = await processPendingQueue(Math.min(Math.max(payload.batchSize ?? 25, 1), 100));
    console.info(`send-push processed queue batch: ${results.length}`);
    return json({
      ok: true,
      processed: results.length,
      sent: results.filter((result) => result.status === "sent").length,
      failed: results.filter((result) => result.status === "failed").length,
      results
    });
  } catch (error) {
    console.error("send-push failed", error);
    return json({ error: error instanceof Error ? error.message : "Unable to send push." }, 400);
  }
});

async function readPayload(request: Request): Promise<PushRequest> {
  const text = await request.text();
  if (!text.trim()) return {};

  try {
    return JSON.parse(text) as PushRequest;
  } catch {
    throw new Error("Request body must be valid JSON.");
  }
}

async function processPendingQueue(batchSize: number) {
  const { data, error } = await supabase
    .from("notification_events")
    .select("id,recipient_id,title,body,data")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error) throw error;

  const events = (data ?? []) as NotificationEvent[];
  const results = [];
  for (const event of events) {
    results.push(await sendEvent(event));
  }

  return results;
}

async function processSingle(payload: PushRequest) {
  if (payload.notificationId) {
    const { data, error } = await supabase
      .from("notification_events")
      .select("id,recipient_id,title,body,data")
      .eq("id", payload.notificationId)
      .single();

    if (error) throw error;
    return sendEvent(data as NotificationEvent);
  }

  if (!payload.userId || !payload.title || !payload.body) {
    throw new Error("Provide notificationId or userId/title/body.");
  }

  return sendToRecipient({
    recipientId: payload.userId,
    title: sanitizePushText(payload.title, "MORT update", 80),
    body: sanitizePushText(payload.body, "Open MORT for details.", 140),
    data: payload.data ?? {}
  });
}

async function sendEvent(event: NotificationEvent) {
  try {
    const result = await sendToRecipient({
      recipientId: event.recipient_id,
      title: sanitizePushText(event.title, "MORT update", 80),
      body: sanitizePushText(event.body, "Open MORT for details.", 140),
      data: event.data ?? {}
    });

    await supabase
      .from("notification_events")
      .update({ status: "sent", sent_at: new Date().toISOString(), last_error: null })
      .eq("id", event.id);

    return { id: event.id, status: "sent", result };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await supabase.from("notification_events").update({ status: "failed", last_error: message }).eq("id", event.id);
    return { id: event.id, status: "failed", error: message };
  }
}

async function sendToRecipient(input: { recipientId: string; title: string; body: string; data: Record<string, unknown> }) {
  const { data: tokens, error: tokenError } = await supabase
    .from("push_tokens")
    .select("id,expo_push_token")
    .eq("user_id", input.recipientId)
    .eq("is_active", true);

  if (tokenError) throw tokenError;

  const activeTokens = tokens ?? [];
  if (activeTokens.length === 0) {
    const { data: profile } = await supabase.from("profiles").select("expo_push_token").eq("id", input.recipientId).maybeSingle();
    if (profile?.expo_push_token) {
      activeTokens.push({ id: null, expo_push_token: profile.expo_push_token });
    }
  }

  if (activeTokens.length === 0) {
    throw new Error("Recipient has no active Expo push token.");
  }

  const expoResponse = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json"
    },
    body: JSON.stringify(
      activeTokens.map((token) => ({
        to: token.expo_push_token,
        title: input.title,
        body: input.body,
        data: input.data
      }))
    )
  });

  const expoBody = (await expoResponse.json()) as ExpoPushResult;
  if (!expoResponse.ok) {
    throw new Error(JSON.stringify(expoBody));
  }

  await deactivateInvalidTokens(activeTokens, expoBody);
  return expoBody;
}

function sanitizePushText(value: string, fallback: string, maxLength: number) {
  const text = value.replace(/\s+/g, " ").trim();
  if (!text) return fallback;

  if (
    text.match(/(\+?1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}/) ||
    text.match(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
  ) {
    return fallback;
  }

  return text.slice(0, maxLength);
}

async function deactivateInvalidTokens(tokens: Array<{ id: string | null; expo_push_token: string }>, expoBody: ExpoPushResult) {
  const results = expoBody.data ?? [];

  for (let index = 0; index < results.length; index += 1) {
    const result = results[index];
    const token = tokens[index];
    if (!token?.id) continue;

    if (result.details?.error === "DeviceNotRegistered") {
      await supabase
        .from("push_tokens")
        .update({ is_active: false, last_error: "DeviceNotRegistered" })
        .eq("id", token.id);
    } else if (result.status === "error") {
      await supabase
        .from("push_tokens")
        .update({ last_error: result.message ?? "Expo push error" })
        .eq("id", token.id);
    }
  }
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json"
    }
  });
}
