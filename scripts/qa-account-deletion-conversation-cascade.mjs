import {
  assertQa,
  qaLog,
  saveJob,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-account-deletion-conversation-cascade";

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult" },
    { key: "teen", role: "teen" },
  ],
  async ({ adult, teen }) => {
    const job = await saveJob(adult.client, {
      title: "QA Account Deletion Conversation Cascade",
      summary: "Synthetic fixture for the account-deletion cascade regression.",
    });
    assertQa(job.result?.ok === true, "Could not publish the synthetic deletion fixture job.");

    const application = await teen.client.rpc("submit_job_application", {
      p_job_id: job.result.job.id,
      p_note: "Synthetic account-deletion cascade check.",
      p_availability_confirmed: true,
      p_portfolio_ids: [],
    });
    assertQa(
      !application.error && application.data?.ok === true,
      `Could not create the synthetic conversation: ${application.error?.message ?? application.data?.code}`,
    );

    const deletion = await serviceClient.auth.admin.deleteUser(teen.id, false);
    assertQa(!deletion.error, "Supabase Auth rejected the account-deletion conversation cascade.");

    const residue = await withDatabase(async (database) => {
      const result = await database.query(
        `select
           exists(select 1 from auth.users where id = $1) as auth_user_exists,
           exists(select 1 from public.profiles where id = $1) as profile_exists,
           exists(
             select 1
             from public.conversations conversation
             join public.message_threads thread on thread.id = conversation.legacy_thread_id
             where thread.teen_id = $1
           ) as conversation_exists`,
        [teen.id],
      );
      return result.rows[0];
    });
    assertQa(
      residue.auth_user_exists === false &&
        residue.profile_exists === false &&
        residue.conversation_exists === false,
      "Account deletion left Auth, profile, or conversation residue.",
    );
    qaLog(scope, "Auth deletion completed across an active synthetic job conversation without residue");
  },
);
