import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-mort-0.9.4-operational-controls";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "operator", role: "admin", identityVerified: true },
  ],
  async ({ teen, adult, operator }) => {
    await withDatabase(async (database) => {
      await database.query(
        "delete from private.operational_alerts where safe_code = 'qa_proof_storage_failure'",
      );
      await database.query(
        `
          insert into public.admin_role_assignments (
            user_id, role, granted_by, grant_reason
          ) values ($1, 'incident_manager', $1, $2)
          on conflict (user_id, role) where revoked_at is null do nothing
        `,
        [operator.id, "Temporary isolated MORT 0.9.4 operational QA role."],
      );
    });

    const runtime = await teen.client.rpc("get_runtime_feature_status");
    assertQa(!runtime.error && runtime.data?.ok === true, "Runtime status RPC failed.");
    assertQa(runtime.data.maintenance_mode === false, "Maintenance must default off.");
    assertQa(runtime.data.ai_provider_disabled === true, "External AI must default disabled.");
    assertQa(runtime.data.payments_disabled === true, "Payments must default disabled.");
    assertQa(runtime.data.new_job_publishing_disabled === false, "Pilot publishing must not be emergency-paused by default.");
    assertQa(runtime.data.public_marketplace_closed === true, "Public marketplace must remain closed.");
    qaLog(scope, "server-owned fail-closed runtime defaults are active");

    const privateRead = await teen.client.from("runtime_feature_controls").select("*");
    assertQa(privateRead.error, "Private runtime controls were exposed through the Data API.");

    const deniedControl = await adult.client.rpc("admin_update_runtime_feature_controls", {
      p_maintenance_mode: false,
      p_ai_provider_disabled: true,
      p_payments_disabled: true,
      p_new_job_publishing_disabled: false,
      p_public_marketplace_closed: true,
      p_reason: "Ordinary adult must not change emergency controls.",
    });
    assertQa(
      !deniedControl.error && deniedControl.data?.code === "incident_manager_role_required",
      "Ordinary adult changed or reached privileged runtime controls.",
    );

    const deniedQueue = await teen.client.rpc("get_admin_operational_alerts", {
      p_status: "open",
      p_limit: 20,
    });
    assertQa(
      !deniedQueue.error && deniedQueue.data?.code === "operational_review_role_required",
      "Ordinary teen accessed the operational alert queue.",
    );
    qaLog(scope, "ordinary users cannot read or mutate operational controls");

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const telemetry = await teen.client.rpc("record_my_evidence_upload_failure", {
        p_upload_kind: "proof",
        p_safe_code: "qa_proof_storage_failure",
        p_client_request_id: randomUUID(),
      });
      assertQa(!telemetry.error && telemetry.data?.ok === true, "Upload failure telemetry failed.");
    }

    const alert = await withDatabase(async (database) => {
      const result = await database.query(
        `
          select id, occurrence_count, correlation_id, status
          from private.operational_alerts
          where category = 'evidence_upload_failure'
            and source = 'upload.proof'
            and safe_code = 'qa_proof_storage_failure'
            and resource_id = $1
        `,
        [teen.id],
      );
      assertQa(result.rowCount === 1, "Upload alerts were not deduplicated.");
      return result.rows[0];
    });
    assertQa(alert.occurrence_count === 2, "Deduplicated alert count was not incremented.");
    assertQa(alert.correlation_id, "Upload alert lacks a correlation ID.");
    qaLog(scope, "redacted upload alerts deduplicate and retain correlation IDs");

    const report = await teen.client.rpc("submit_safety_report", {
      p_target_user_id: adult.id,
      p_category: "other_urgent_concern",
      p_severity: "moderate",
      p_immediate_danger: false,
      p_details: "Synthetic QA report for restricted moderation authorization.",
    });
    assertQa(!report.error && report.data?.ok === true, "Synthetic QA report creation failed.");
    const reportId = report.data.report_id;

    for (const user of [teen, adult]) {
      const denied = await user.client.rpc("admin_get_moderation_record", {
        p_record_type: "report",
        p_record_id: reportId,
      });
      assertQa(
        !denied.error && denied.data?.code === "incident_manager_required",
        `${user.role} directly accessed a restricted moderation record.`,
      );
    }

    const moderation = await operator.client.rpc("admin_get_moderation_record", {
      p_record_type: "report",
      p_record_id: reportId,
    });
    assertQa(!moderation.error && moderation.data?.ok === true, "Authorized report load failed.");
    assertQa(moderation.data.record?.id === reportId, "Authorized report response was mismatched.");
    assertQa(
      !("object_path" in moderation.data.record) && !("signed_url" in moderation.data.record),
      "Moderation response exposed a private object path or signed URL.",
    );

    const review = await operator.client.rpc("admin_update_report_status", {
      p_report_id: reportId,
      p_status: "reviewing",
      p_reason: "Synthetic QA reviewer accepted this case for authorization testing.",
    });
    assertQa(!review.error && review.data?.ok === true, "Authorized report transition failed.");

    const suspend = await operator.client.rpc("admin_set_account_status", {
      p_user_id: adult.id,
      p_status: "suspended",
      p_reason: "Synthetic QA account restriction for server authorization testing.",
    });
    assertQa(!suspend.error && suspend.data?.ok === true, "Authorized account restriction failed.");
    const restore = await operator.client.rpc("admin_set_account_status", {
      p_user_id: adult.id,
      p_status: "active",
      p_reason: "Restore the synthetic QA account after restriction testing.",
    });
    assertQa(!restore.error && restore.data?.ok === true, "Synthetic QA account restoration failed.");

    const selfRestriction = await operator.client.rpc("admin_set_account_status", {
      p_user_id: operator.id,
      p_status: "suspended",
      p_reason: "An administrator must not restrict their own account through this endpoint.",
    });
    assertQa(
      !selfRestriction.error && selfRestriction.data?.code === "admin_self_restriction_blocked",
      "Administrator self-restriction did not fail closed.",
    );
    qaLog(scope, "moderation endpoints enforce specialized roles and reasoned actions");

    const queue = await operator.client.rpc("get_admin_operational_alerts", {
      p_status: "open",
      p_limit: 100,
    });
    assertQa(!queue.error && queue.data?.ok === true, "Authorized operational queue load failed.");
    assertQa(
      queue.data.items.some((item) => item.id === alert.id),
      "Authorized queue omitted the QA operational alert.",
    );

    const acknowledged = await operator.client.rpc("admin_acknowledge_operational_alert", {
      p_alert_id: alert.id,
      p_resolution_status: "resolved",
      p_reason: "Synthetic QA alert resolved after deduplication and access checks.",
    });
    assertQa(!acknowledged.error && acknowledged.data?.ok === true, "Alert resolution failed.");
    qaLog(scope, "specialized operator can load and resolve redacted alerts");

    const draft = await saveJob(adult.client, {}, false);
    assertQa(
      draft.result?.ok === true && draft.result?.job?.id,
      "QA draft creation failed.",
    );
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(
          "update private.runtime_feature_controls set new_job_publishing_disabled = true where singleton",
        );
        await database.query("savepoint before_publish");
        let blocked = false;
        try {
          await database.query("update public.jobs set status = 'open' where id = $1", [draft.result.job.id]);
        } catch (error) {
          blocked = String(error.message).includes("new_job_publishing_disabled");
          await database.query("rollback to savepoint before_publish");
        }
        assertQa(blocked, "Emergency publishing control did not block a draft transition.");
      } finally {
        await database.query("rollback");
      }
    });
    qaLog(scope, "new-job emergency pause is enforced and transactionally restored");

    const attemptedOpen = await operator.client.rpc("admin_update_runtime_feature_controls", {
      p_maintenance_mode: false,
      p_ai_provider_disabled: true,
      p_payments_disabled: true,
      p_new_job_publishing_disabled: false,
      p_public_marketplace_closed: false,
      p_reason: "Synthetic QA must prove public marketplace opening is unavailable.",
    });
    assertQa(
      !attemptedOpen.error && attemptedOpen.data?.code === "public_marketplace_activation_not_authorized",
      "Public marketplace activation did not fail closed.",
    );

    await withDatabase(async (database) => {
      await database.query(
        `
          delete from private.operational_alerts
          where resource_id = any($1::uuid[])
            and safe_code like 'qa_%'
        `,
        [[teen.id, adult.id, operator.id]],
      );
    });
    qaLog(scope, "removed QA-only operational alerts");
  },
);

qaLog(scope, "all remote 0.9.4 operational and moderation checks passed");
