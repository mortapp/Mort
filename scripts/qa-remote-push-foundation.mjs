import { createHash, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "remote-push-foundation";
const categories = {
  application_updates: true,
  job_updates: true,
  schedule_changes: true,
  new_messages: true,
  work_reminders: true,
  support_updates: true,
  guardian_updates: true,
  verification_updates: true,
  dispute_updates: true,
};

function token(label) {
  return `fcm_${label}_${randomUUID().replaceAll("-", "_")}`;
}

function expectOk(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message ?? "RPC error"}`);
  assertQa(result.data?.ok === true, `${message}: ${result.data?.code ?? "not ok"}`);
  return result.data;
}

function registrationParams(deviceId, registrationToken, requestId = randomUUID()) {
  return {
    p_device_id: deviceId,
    p_provider: "fcm",
    p_registration_token: registrationToken,
    p_platform: "android",
    p_permission_status: "authorized",
    p_app_version: "0.9.11+101",
    p_locale: "en_US",
    p_timezone_name: "America/Indiana/Indianapolis",
    p_environment: "closed_test",
    p_client_request_id: requestId,
  };
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
  ],
  async ({ teen, adult }) => {
    const deviceA = randomUUID();
    const deviceB = randomUUID();
    const firstToken = token("teen_first");
    const firstRequest = randomUUID();
    const first = expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, firstToken, firstRequest),
      ),
      "first token registration failed",
    );
    const replay = expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, firstToken, firstRequest),
      ),
      "token registration replay failed",
    );
    assertQa(
      first.device?.provider === "fcm" &&
        first.device?.device_id === deviceA &&
        replay.replayed === true &&
        !JSON.stringify(first).includes(firstToken),
      "registration response exposed the token or lost replay/device state",
    );
    const substituted = await teen.client.rpc(
      "register_my_push_device_v2",
      registrationParams(deviceA, token("substitution"), firstRequest),
    );
    assertQa(
      !substituted.error && substituted.data?.code === "push_request_id_reused",
      "registration request ID accepted payload substitution",
    );
    qaLog(scope, "registration is response-minimized, replay-safe, and payload-bound");

    const ownDirectRead = await teen.client.from("push_tokens").select("id").limit(1);
    const directInsert = await teen.client.from("push_tokens").insert({
      user_id: teen.id,
      provider: "fcm",
      registration_token: token("direct"),
      token_sha256: "0".repeat(64),
      device_id: randomUUID(),
      platform: "android",
    });
    const outsiderRead = await adult.client.from("push_tokens").select("id").limit(1);
    assertQa(
      Boolean(ownDirectRead.error) && Boolean(directInsert.error) && Boolean(outsiderRead.error),
      "raw push-token table access was available to an authenticated client",
    );
    qaLog(scope, "raw token reads and direct writes are denied to owners and outsiders");

    const rotatedToken = token("teen_rotated");
    expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, rotatedToken),
      ),
      "token rotation failed",
    );
    expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceB, token("teen_second_device")),
      ),
      "second-device registration failed",
    );
    const activeTeenTokens = await serviceClient
      .from("push_tokens")
      .select("id,device_id,registration_token,is_active")
      .eq("user_id", teen.id)
      .eq("provider", "fcm")
      .eq("is_active", true);
    const status = expectOk(
      await teen.client.rpc("get_my_push_status"),
      "push status failed",
    );
    assertQa(
      !activeTeenTokens.error &&
        activeTeenTokens.data?.length === 2 &&
        activeTeenTokens.data.some((item) => item.registration_token === rotatedToken) &&
        status.active_device_count === 2 &&
        status.provider_delivery_verified === false &&
        !JSON.stringify(status).includes(rotatedToken),
      "rotation, multi-device registration, or safe status failed",
    );
    qaLog(scope, "token rotation and multiple active devices are server-authoritative");

    const preferences = expectOk(
      await teen.client.rpc("get_my_notification_preferences"),
      "default preferences failed",
    ).preferences;
    assertQa(
      preferences.push_enabled === true &&
        preferences.categories.application_updates === true,
      "registration did not establish the expected opt-in preference state",
    );
    const updatedCategories = { ...categories, new_messages: false };
    expectOk(
      await teen.client.rpc("update_my_notification_preferences", {
        p_push_enabled: true,
        p_categories: updatedCategories,
        p_quiet_hours_enabled: true,
        p_quiet_start: "00:00:00",
        p_quiet_end: "23:59:59",
        p_timezone_name: "UTC",
      }),
      "preference update failed",
    );
    const invalidPreferences = await teen.client.rpc(
      "update_my_notification_preferences",
      {
        p_push_enabled: true,
        p_categories: { ...updatedCategories, exact_location_alerts: true },
        p_quiet_hours_enabled: false,
        p_quiet_start: "21:00:00",
        p_quiet_end: "07:00:00",
        p_timezone_name: "UTC",
      },
    );
    assertQa(
      !invalidPreferences.error &&
        invalidPreferences.data?.code === "invalid_notification_preferences",
      "unknown notification preference keys were accepted",
    );
    qaLog(scope, "category preferences and local-time quiet hours validate exactly");

    const threadId = randomUUID();
    const newMessageEvent = await serviceClient
      .from("notification_events")
      .insert({
        recipient_id: teen.id,
        title: "Private message from a named adult",
        body: "Meet at 111 Exact Street and use PIN 123456.",
        data: {
          threadId,
          route: "/admin/users",
          exactAddress: "111 Exact Street",
          pin: "123456",
        },
      })
      .select("id,notification_type,sensitivity,data")
      .single();
    assertQa(!newMessageEvent.error, "notification normalization fixture failed");
    assertQa(
      newMessageEvent.data.notification_type === "new_message" &&
        newMessageEvent.data.sensitivity === "sensitive" &&
        newMessageEvent.data.data.threadId === threadId &&
        newMessageEvent.data.data.type === "new_message" &&
        !("route" in newMessageEvent.data.data) &&
        !("exactAddress" in newMessageEvent.data.data) &&
        !("pin" in newMessageEvent.data.data),
      "notification deep-link data retained a raw route, address, or PIN",
    );
    const ordinaryClaim = await teen.client.rpc("service_claim_push_events", {
      p_limit: 1,
      p_notification_id: newMessageEvent.data.id,
    });
    assertQa(Boolean(ordinaryClaim.error), "ordinary user invoked the service-only push worker");

    await serviceClient
      .from("push_delivery_runtime")
      .update({ remote_push_enabled: true })
      .eq("singleton", true);
    try {
      const messageClaim = expectOk(
        await serviceClient.rpc("service_claim_push_events", {
          p_limit: 1,
          p_notification_id: newMessageEvent.data.id,
        }),
        "message preference claim failed",
      );
      const suppressedMessage = await serviceClient
        .from("notification_events")
        .select("status,last_error")
        .eq("id", newMessageEvent.data.id)
        .single();
      assertQa(
        messageClaim.events.length === 0 &&
          suppressedMessage.data?.status === "failed" &&
          suppressedMessage.data?.last_error === "suppressed_by_preference",
        "disabled message category was delivered or left claimable",
      );

      const quietEvent = await serviceClient
        .from("notification_events")
        .insert({
          recipient_id: teen.id,
          title: "Job update",
          body: "Private job detail.",
          data: { jobId: randomUUID() },
          notification_type: "job_update",
        })
        .select("id")
        .single();
      const quietClaim = expectOk(
        await serviceClient.rpc("service_claim_push_events", {
          p_limit: 1,
          p_notification_id: quietEvent.data.id,
        }),
        "quiet-hours claim failed",
      );
      const deferred = await serviceClient
        .from("notification_events")
        .select("status,last_error,next_attempt_at")
        .eq("id", quietEvent.data.id)
        .single();
      assertQa(
        quietClaim.events.length === 0 &&
          deferred.data?.status === "pending" &&
          deferred.data?.last_error === "deferred_quiet_hours" &&
          new Date(deferred.data.next_attempt_at).getTime() > Date.now(),
        "quiet hours did not defer a nonessential update",
      );

      const safetyEvent = await serviceClient
        .from("notification_events")
        .insert({
          recipient_id: teen.id,
          title: "Unsafe raw safety title",
          body: "Exact location and evidence details must not leave the server.",
          data: { safetyPingId: randomUUID(), evidencePath: "private/path.jpg" },
          notification_type: "safety_alert",
        })
        .select("id")
        .single();
      const safetyClaim = expectOk(
        await serviceClient.rpc("service_claim_push_events", {
          p_limit: 1,
          p_notification_id: safetyEvent.data.id,
        }),
        "safety claim failed",
      );
      assertQa(
        safetyClaim.events.length === 1 &&
          safetyClaim.events[0].notification_type === "safety_alert" &&
          safetyClaim.events[0].targets.length === 2 &&
          !("evidencePath" in safetyClaim.events[0].safe_data),
        "safety alert did not bypass quiet hours or exposed evidence metadata",
      );
      const invalidTarget = safetyClaim.events[0].targets[0];
      const completion = expectOk(
        await serviceClient.rpc("service_complete_push_event", {
          p_event_id: safetyEvent.data.id,
          p_results: safetyClaim.events[0].targets.map((target, index) => ({
            token_id: target.token_id,
            outcome: index === 0 ? "invalid_token" : "sent",
            error_code: index === 0 ? "unregistered" : null,
            provider_message_id: index === 0 ? null : `projects/qa/messages/${randomUUID()}`,
            latency_ms: 20 + index,
          })),
        }),
        "delivery completion failed",
      );
      const invalidRow = await serviceClient
        .from("push_tokens")
        .select("is_active,last_error")
        .eq("id", invalidTarget.token_id)
        .single();
      assertQa(
        completion.sent === 1 &&
          invalidRow.data?.is_active === false &&
          invalidRow.data?.last_error === "unregistered",
        "invalid-token cleanup or partial multi-device success failed",
      );
      qaLog(scope, "preferences, quiet hours, safety bypass, payload privacy, and invalid-token cleanup pass");
    } finally {
      await serviceClient
        .from("push_delivery_runtime")
        .update({ remote_push_enabled: false })
        .eq("singleton", true);
    }

    const localUnregister = expectOk(
      await teen.client.rpc("unregister_my_push_devices_v2", {
        p_device_id: deviceA,
        p_all_devices: false,
        p_client_request_id: randomUUID(),
      }),
      "local unregister failed",
    );
    assertQa(
      localUnregister.scope === "local_device" &&
        localUnregister.deactivated_count <= 1,
      "local unregister changed an unexpected scope",
    );
    const accountSwitchToken = token("account_switch");
    expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, accountSwitchToken),
      ),
      "source account-switch token registration failed",
    );
    const replacedAdultToken = token("adult_replaced_device");
    expectOk(
      await adult.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, replacedAdultToken),
      ),
      "destination device fixture registration failed",
    );
    expectOk(
      await adult.client.rpc(
        "register_my_push_device_v2",
        registrationParams(deviceA, accountSwitchToken),
      ),
      "same-device account switch registration failed",
    );
    const switchedOwner = await serviceClient
      .from("push_tokens")
      .select("user_id,device_id,is_active")
      .eq("provider", "fcm")
      .eq("registration_token", accountSwitchToken)
      .single();
    assertQa(
      switchedOwner.data?.user_id === adult.id &&
        switchedOwner.data?.device_id === deviceA &&
        switchedOwner.data?.is_active === true,
      "one-device account switch retained the wrong owner",
    );
    const replacedDevice = await serviceClient
      .from("push_tokens")
      .select("is_active,last_error")
      .eq("provider", "fcm")
      .eq("registration_token", replacedAdultToken)
      .single();
    assertQa(
      replacedDevice.data?.is_active === false &&
        replacedDevice.data?.last_error === "device_registration_replaced",
      "same-device account switch did not retire the replaced registration",
    );
    expectOk(
      await adult.client.rpc("unregister_my_push_devices_v2", {
        p_device_id: deviceA,
        p_all_devices: true,
        p_client_request_id: randomUUID(),
      }),
      "global unregister failed",
    );
    const activeAdult = await serviceClient
      .from("push_tokens")
      .select("id", { count: "exact", head: true })
      .eq("user_id", adult.id)
      .eq("is_active", true);
    assertQa(activeAdult.count === 0, "global unregister left an active device");
    const cappedTokens = [];
    for (let index = 0; index < 12; index += 1) {
      const cappedToken = token(`adult_capped_${index}`);
      cappedTokens.push(cappedToken);
      expectOk(
        await adult.client.rpc(
          "register_my_push_device_v2",
          registrationParams(randomUUID(), cappedToken),
        ),
        `active-device cap fixture ${index + 1} failed`,
      );
    }
    const cappedRows = await serviceClient
      .from("push_tokens")
      .select("registration_token,is_active,last_error")
      .eq("user_id", adult.id)
      .eq("provider", "fcm")
      .in("registration_token", cappedTokens);
    assertQa(
      !cappedRows.error &&
        cappedRows.data.filter((item) => item.is_active).length === 10 &&
        cappedRows.data.filter(
          (item) =>
            !item.is_active && item.last_error === "active_device_limit_reached",
        ).length === 2,
      "active FCM device count was not bounded to ten",
    );
    expectOk(
      await adult.client.rpc("unregister_my_push_devices_v2", {
        p_device_id: deviceA,
        p_all_devices: true,
        p_client_request_id: randomUUID(),
      }),
      "post-cap global unregister failed",
    );
    qaLog(
      scope,
      "local/global logout, collision-safe account switching, and the ten-device cap pass",
    );

    expectOk(
      await teen.client.rpc(
        "register_my_push_device_v2",
        registrationParams(randomUUID(), token("before_deletion")),
      ),
      "pre-deletion token registration failed",
    );
    const deletionId = randomUUID();
    const deletionInsert = await serviceClient.from("account_deletion_requests").insert({
      id: deletionId,
      user_id: teen.id,
      requester_fingerprint: createHash("sha256").update(teen.id).digest("hex"),
      source: "in_app",
      status: "requested",
      identity_confirmed_at: new Date().toISOString(),
    });
    assertQa(!deletionInsert.error, "deletion-request fixture failed");
    const afterDeletion = await serviceClient
      .from("push_tokens")
      .select("id", { count: "exact", head: true })
      .eq("user_id", teen.id)
      .eq("is_active", true);
    const afterDeletionPreferences = await serviceClient
      .from("notification_preferences")
      .select("push_enabled")
      .eq("user_id", teen.id)
      .single();
    assertQa(
      afterDeletion.count === 0 &&
        afterDeletionPreferences.data?.push_enabled === false,
      "account deletion request did not revoke tokens and push preference",
    );
    await serviceClient.from("account_deletion_requests").delete().eq("id", deletionId);
    qaLog(scope, "account deletion requests immediately revoke all push delivery");

    const runtime = expectOk(
      await serviceClient.rpc("service_get_push_runtime"),
      "push runtime lookup failed",
    );
    assertQa(
      runtime.provider === "fcm" && runtime.remote_push_enabled === false,
      "hosted push runtime was not left fail-closed",
    );
    qaLog(scope, "hosted FCM runtime remains disabled pending real provider verification");
  },
);

qaLog(scope, "all remote push foundation checks completed");
