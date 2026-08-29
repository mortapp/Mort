// Minimal, hosted-safe post-deploy proof for the account-deletion FK fix
// (20260829010000_account_deletion_retention_deidentification.sql). Uses the
// existing hosted-safe QA infrastructure (feature-qa-helpers.mjs) -- creates
// exactly one disposable, isolated QA account, attaches one representative
// previously-RESTRICT row (account_ban_appeals, the same table used for the
// original local proof-of-concept), calls the real auth.admin.deleteUser(),
// and verifies deidentified survival. Does not touch any real/non-test user.
import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-account-deletion-hosted-e2e";

await withQaUsers(scope, [{ key: "subject", role: "adult", identityVerified: false }], async ({ subject }) => {
  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      await database.query("select set_config('mort.internal_update', 'true', true)");
      await database.query(
        `insert into public.account_ban_appeals (id, user_id, reason)
         values (gen_random_uuid(), $1, 'Hosted post-deploy QA fixture -- verifies the FK fix on the live database.')`,
        [subject.id],
      );
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });

  const { error: deleteError } = await serviceClient.auth.admin.deleteUser(subject.id, false);
  assertQa(!deleteError, `hosted auth.admin.deleteUser succeeded for the disposable QA subject: ${deleteError?.message ?? ""}`);

  await withDatabase(async (database) => {
    const profile = await database.query("select count(*)::int as count from public.profiles where id = $1", [subject.id]);
    assertQa(profile.rows[0].count === 0, "hosted: profile is gone after deletion");

    const appeal = await database.query(
      "select user_id, reason from public.account_ban_appeals where reason = $1",
      ["Hosted post-deploy QA fixture -- verifies the FK fix on the live database."],
    );
    assertQa(appeal.rowCount === 1, "hosted: the account_ban_appeals row survives");
    assertQa(appeal.rows[0].user_id === null, "hosted: the surviving row's user_id is genuinely NULL (deidentified, not blocking)");

    // Clean up the QA fixture row itself (not part of the frozen legacy
    // snapshot or any real moderation record -- safe to remove).
    await database.query("select set_config('mort.internal_update', 'true', true)");
    await database.query(
      "delete from public.account_ban_appeals where reason = $1",
      ["Hosted post-deploy QA fixture -- verifies the FK fix on the live database."],
    );
  });
});

qaLog(scope, "hosted deleteUser() succeeds post-migration; previously-RESTRICT row survives deidentified; QA fixture cleaned up");
