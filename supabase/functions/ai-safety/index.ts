import { createClient } from "https://esm.sh/@supabase/supabase-js@2.110.1";

const patterns: Record<string, RegExp> = {
  phone: /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/i,
  email: /\b[\w.-]+@[\w.-]+\.\w{2,}\b/i,
  payment: /\b(cashapp|venmo|paypal|zelle|\$cashtag)\b/i,
  social: /\b(snapchat|snap|insta|instagram|kik|discord|whatsapp)\b/i,
  address: /\b\d{1,5}\s\w+\s(st|street|ave|avenue|blvd|rd|road|dr|drive|lane|ln)\b/i,
  off_platform: /\b(call me|text me|dm me on|message me on|hit me up on)\b/i,
  threats: /\b(kill|beat up|hurt|shoot|stab|die)\b/i,
  scam: /\b(gift card|wire|western union|upfront fee|cash advance)\b/i,
  unsafe_job: /\b(massage|modeling|hotel room|night shift|delivery driver|driving)\b/i,
  grooming: /\b(don't tell your parents|keep this a secret|don't tell your guardian)\b/i,
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return Response.json({ ok: false, code: "post_required" }, { status: 405 });
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = request.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!url || !anonKey || !serviceKey) return Response.json({ ok: false, code: "server_not_configured" }, { status: 503 });
  if (!token) return Response.json({ ok: false, code: "authentication_required" }, { status: 401 });

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: auth, error: authError } = await authClient.auth.getUser(token);
  if (authError || !auth.user) return Response.json({ ok: false, code: "invalid_session" }, { status: 401 });

  const body = await request.json().catch(() => ({}));
  const content = typeof body.content === "string" ? body.content.trim() : "";
  const resourceType = typeof body.resourceType === "string" ? body.resourceType : "message_draft";
  const resourceId = typeof body.resourceId === "string" ? body.resourceId : crypto.randomUUID();
  if (!content || content.length > 4000 || !/^[a-z_]{3,40}$/.test(resourceType) || resourceId.length > 100) {
    return Response.json({ ok: false, code: "invalid_request" }, { status: 400 });
  }

  const flags = Object.entries(patterns).filter(([, pattern]) => pattern.test(content)).map(([name]) => name);
  const serviceClient = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await serviceClient.from("ai_moderation_events").insert({
    user_id: auth.user.id,
    resource_type: resourceType,
    resource_id: resourceId,
    content: null,
    detected_flags: flags,
    ai_provider: null,
    fallback_used: true,
    status: flags.length > 0 ? "flagged" : "clean",
  }).select("id,status,detected_flags,created_at").single();
  if (error) return Response.json({ ok: false, code: "moderation_write_failed" }, { status: 503 });
  return Response.json({ ok: true, flags, event: data });
});
