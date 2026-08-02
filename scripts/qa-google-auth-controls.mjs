import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-google-auth-controls";

await withQaUsers(
  scope,
  [
    { key: "owner", role: "adult" },
    { key: "outsider", role: "adult" },
  ],
  async ({ owner, outsider }) => {
    const ownerProfileBefore = await owner.client.rpc("get_my_profile");
    assertQa(
      !ownerProfileBefore.error && ownerProfileBefore.data?.length === 1,
      "The existing owner profile was unavailable before bootstrap QA.",
    );
    const ownerEnsureFirst = await owner.client.rpc("ensure_my_profile");
    const ownerEnsureReplay = await owner.client.rpc("ensure_my_profile");
    assertQa(
      !ownerEnsureFirst.error &&
        !ownerEnsureReplay.error &&
        ownerEnsureFirst.data?.length === 1 &&
        ownerEnsureReplay.data?.length === 1,
      "The caller-bound profile bootstrap was not idempotent.",
    );
    assertQa(
      JSON.stringify(ownerEnsureFirst.data[0]) ===
        JSON.stringify(ownerProfileBefore.data[0]) &&
        JSON.stringify(ownerEnsureReplay.data[0]) ===
          JSON.stringify(ownerProfileBefore.data[0]),
      "Profile bootstrap overwrote an existing profile.",
    );

    const forgedTarget = await owner.client.rpc("ensure_my_profile", {
      p_user_id: outsider.id,
    });
    assertQa(
      forgedTarget.error,
      "Profile bootstrap accepted a client-selected user identifier.",
    );
    qaLog(scope, "existing profile is unchanged and the RPC is caller-bound");

    const providerAbsent = await owner.client.rpc(
      "record_my_auth_identity_event",
      {
        p_event_type: "google_sign_in",
        p_provider: "google",
        p_client_request_id: randomUUID(),
      },
    );
    assertQa(
      !providerAbsent.error &&
        providerAbsent.data?.code === "provider_identity_not_connected",
      "A user without Google connected recorded a Google sign-in event.",
    );

    const unsupportedProvider = await owner.client.rpc(
      "record_my_auth_identity_event",
      {
        p_event_type: "google_sign_in",
        p_provider: "github",
        p_client_request_id: randomUUID(),
      },
    );
    assertQa(
      !unsupportedProvider.error &&
        unsupportedProvider.data?.code === "provider_not_allowed",
      "An unapproved provider reached the Google audit path.",
    );

    const noPriorLink = await owner.client.rpc(
      "record_my_auth_identity_event",
      {
        p_event_type: "google_unlinked",
        p_provider: "google",
        p_client_request_id: randomUUID(),
      },
    );
    assertQa(
      !noPriorLink.error &&
        noPriorLink.data?.code === "prior_link_event_required",
      "An unlink event was accepted without a verified prior link event.",
    );
    qaLog(scope, "provider, event type, and prior-link state fail closed");

    const directInsert = await owner.client
      .from("account_security_events")
      .insert({
        user_id: owner.id,
        event_type: "auth_google_linked",
        severity: "info",
        status: "cleared",
      });
    assertQa(
      directInsert.error,
      "An authenticated client inserted its own trusted auth audit event.",
    );

    await withDatabase(async (database) => {
      await database.query(
        `
          insert into public.account_security_events (
            user_id, event_type, severity, event_data, status
          ) values ($1, 'auth_google_linked', 'info', $2::jsonb, 'cleared')
        `,
        [
          owner.id,
          JSON.stringify({
            provider: "google",
            identity_count: 2,
            client_request_id: randomUUID(),
            synthetic_qa: true,
          }),
        ],
      );
    });

    const requestId = randomUUID();
    const first = await owner.client.rpc("record_my_auth_identity_event", {
      p_event_type: "google_unlinked",
      p_provider: "google",
      p_client_request_id: requestId,
    });
    const replay = await owner.client.rpc("record_my_auth_identity_event", {
      p_event_type: "google_unlinked",
      p_provider: "google",
      p_client_request_id: requestId,
    });
    assertQa(
      !first.error && first.data?.ok === true,
      "A valid server-verifiable unlink audit event failed.",
    );
    assertQa(
      !replay.error &&
        replay.data?.ok === true &&
        replay.data.event_id === first.data.event_id,
      "An identity audit replay was not idempotent.",
    );

    const rows = await owner.client
      .from("account_security_events")
      .select("id,event_type,event_data")
      .eq("id", first.data.event_id);
    assertQa(
      !rows.error && rows.data?.length === 1,
      "The owner could not read the resulting security event.",
    );
    assertQa(
      rows.data[0].event_data?.provider === "google" &&
        !("email" in rows.data[0].event_data) &&
        !("token" in rows.data[0].event_data),
      "The identity audit payload exposed unnecessary identity or token data.",
    );

    const outside = await outsider.client
      .from("account_security_events")
      .select("id")
      .eq("id", first.data.event_id);
    assertQa(
      !outside.error && outside.data.length === 0,
      "Another user read a private identity audit event.",
    );
    qaLog(scope, "audit writes are server-owned, idempotent, minimal, and isolated");

    await withDatabase(async (database) => {
      await database.query("delete from public.profiles where id = $1", [
        outsider.id,
      ]);
    });
    const missingProfileRepair = await outsider.client.rpc("ensure_my_profile");
    const missingProfileReplay = await outsider.client.rpc("ensure_my_profile");
    assertQa(
      !missingProfileRepair.error &&
        !missingProfileReplay.error &&
        missingProfileRepair.data?.length === 1 &&
        missingProfileReplay.data?.length === 1,
      "An older Auth user with a missing profile was not repaired idempotently.",
    );
    const repaired = missingProfileRepair.data[0];
    assertQa(
      repaired.id === outsider.id &&
        repaired.role === null &&
        repaired.onboarding_completed === false &&
        repaired.account_status === "active" &&
        repaired.verification_status === "not_started",
      "Missing-profile repair assigned privilege or bypassed onboarding.",
    );
    qaLog(scope, "missing profile is repaired with non-privileged defaults");
  },
);
