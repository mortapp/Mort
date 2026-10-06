import { createHash } from "node:crypto";
import { assertQa, qaLog, withDatabase, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "mort-verify-hash-resolution";
if (process.env.MORT_QA_TARGET !== "local" || process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
    new URL(process.env.SUPABASE_DB_URL ?? "postgres://invalid").hostname !== "127.0.0.1") {
  throw new Error("MORT Verify hash QA requires the local MORT database.");
}

await withQaUsers(scope, [{ key: "hash_teen", role: "teen" }], async ({ hash_teen: teen }) => {
  await withDatabase(async (db) => {
    await db.query("begin");
    try {
      const email = "synthetic-hash-qa@mort.test";
      await db.query("select set_config('request.jwt.claim.sub', $1, true)", [teen.id]);
      await db.query("update private.mort_verify_control set mode = 'disabled' where singleton");
      await db.query("set local role authenticated");
      const disabled = await db.query("select public.start_mort_verify_teen_session($1) as result", [email]);
      await db.query("reset role");
      assertQa(disabled.rows[0].result.code === "mort_verify_disabled", "Disabled verification accepted a submission.");
      await db.query(
        `update private.mort_verify_control set mode = 'sandbox',
         school_email_enabled = true, school_id_enabled = true,
         production_document_collection_approved = false where singleton`,
      );
      await db.query("set local role authenticated");
      const started = await db.query("select public.start_mort_verify_teen_session($1) as result", [email]);
      await db.query("reset role");
      assertQa(started.rows[0].result.ok, "Synthetic sandbox session failed to start.");
      const session = await db.query(
        "select school_email_hash, environment, age_verified_at from private.mort_verify_sessions where id = $1",
        [started.rows[0].result.session_id],
      );
      assertQa(session.rows[0].school_email_hash === createHash("sha256").update(email).digest("hex"),
        "School-email hashing did not match SHA-256.");
      assertQa(session.rows[0].environment === "sandbox" && session.rows[0].age_verified_at === null,
        "Starting a session granted age verification or left sandbox isolation.");
      const verification = await db.query(
        "select identity_verification_id from private.mort_verify_sessions where id = $1",
        [started.rows[0].result.session_id],
      );
      const verificationId = verification.rows[0].identity_verification_id;
      async function rejectsDecision(sql, expectedConstraint) {
        await db.query("savepoint invalid_decision");
        let rejected = false;
        try { await db.query(sql, [verificationId]); } catch (error) {
          rejected = error.code === "23514" && error.constraint === expectedConstraint;
        } finally {
          await db.query("rollback to savepoint invalid_decision");
          await db.query("release savepoint invalid_decision");
        }
        assertQa(rejected, "Identity decision-source gate accepted an invalid transition.");
      }
      await rejectsDecision(
        "update public.identity_verifications set status = 'verified', verified_at = now(), verification_level = 1 where id = $1",
        "identity_verification_decision_source_check",
      );
      await rejectsDecision(
        "update public.identity_verifications set provider = 'wrong_provider', decision_source = 'mort_verify_manual_review' where id = $1",
        "identity_verification_decision_source_check",
      );
      await rejectsDecision(
        "update public.identity_verifications set environment = 'production', status = 'verified', verified_at = now(), verification_level = 1, decision_source = 'mort_verify_manual_review' where id = $1",
        "identity_verification_production_source_check",
      );
      const grants = await db.query(
        `select has_function_privilege('authenticated',
           'public.verify_mort_school_email_code(uuid,text)', 'EXECUTE') as raw_code_allowed,
           has_function_privilege('authenticated',
           'public.service_mort_verify_verify_email_code(uuid,uuid,text)', 'EXECUTE') as service_code_allowed`,
      );
      assertQa(!grants.rows[0].raw_code_allowed && !grants.rows[0].service_code_allowed,
        "Client can execute a retired raw-code or provider-only verifier.");
      qaLog(scope, "sandbox session hashes correctly; disabled collection and verifier permissions stay enforced");
    } finally {
      await db.query("rollback");
    }
  });
});
qaLog(scope, "synthetic session and sandbox controls rolled back; no email or document was sent");
