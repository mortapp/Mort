import { randomUUID } from "node:crypto";

import {
  anonKey,
  assertQa,
  qaLog,
  supabaseUrl,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-ai-safety-edge";
const endpoint = `${supabaseUrl}/functions/v1/ai-safety`;

const unauthenticated = await fetch(endpoint, {
  method: "POST",
  headers: { apikey: anonKey, "content-type": "application/json" },
  body: JSON.stringify({}),
});
assertQa(
  unauthenticated.status === 401,
  "The AI safety Edge Function accepted an unauthenticated request.",
);

await withQaUsers(
  scope,
  [
    { key: "owner", role: "teen" },
    { key: "outsider", role: "teen" },
  ],
  async ({ owner, outsider }) => {
    const resourceId = randomUUID();
    const clientRequestId = randomUUID();
    const body = {
      content: "Please text me at 317-555-0123 instead.",
      resourceType: "message_draft",
      resourceId,
      clientRequestId,
    };
    const session = await owner.client.auth.getSession();
    const token = session.data.session?.access_token;
    assertQa(token, "The QA user session was unavailable.");
    const invoke = (payload) =>
      fetch(endpoint, {
        method: "POST",
        headers: {
          apikey: anonKey,
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(payload),
      });
    const firstResponse = await invoke(body);
    const first = await firstResponse.json();
    if (
      firstResponse.status !== 200 ||
      first?.ok !== true ||
      first?.idempotent !== false ||
      !first?.event?.detected_flags?.includes("phone")
    ) {
      throw new Error(
        `The authenticated deterministic AI safety scan failed: ${JSON.stringify({
          code: first?.code ?? null,
          status: firstResponse.status,
        })}`,
      );
    }

    const replayResponse = await invoke(body);
    const replay = await replayResponse.json();
    assertQa(
      replayResponse.status === 200 &&
        replay?.ok === true &&
        replay?.idempotent === true &&
        replay?.event?.id === first.event.id,
      "AI safety replay did not return the original event.",
    );

    const outside = await outsider.client
      .from("ai_moderation_events")
      .select("id")
      .eq("id", first.event.id);
    assertQa(
      !outside.error && outside.data.length === 0,
      "Another user read a private AI moderation event.",
    );

    const oversized = await fetch(endpoint, {
      method: "POST",
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        ...body,
        clientRequestId: randomUUID(),
        content: "x".repeat(17 * 1024),
      }),
    });
    assertQa(
      oversized.status === 413,
      "The AI safety Edge Function accepted an oversized request.",
    );
    qaLog(
      scope,
      "authentication, bounded input, deterministic flags, idempotency, and isolation passed",
    );
  },
);
