import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) {
  throw new Error(
    "SUPABASE_DB_PASSWORD is required and is never printed.",
  );
}

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function pass(message) {
  console.log(`[qa-message-thread-context] PASS: ${message}`);
}

async function become(role, userId = null) {
  await client.query("reset role");
  await client.query(`set local role ${role}`);
  await client.query(
    "select set_config('request.jwt.claim.sub', $1, true), set_config('request.jwt.claim.role', $2, true), set_config('request.jwt.claims', $3, true)",
    [
      userId ?? "",
      role,
      JSON.stringify(userId ? { sub: userId, role } : { role }),
    ],
  );
}

async function expectRejected(label, run, acceptedMessages, acceptedCodes = []) {
  const savepoint = `qa_${Math.random().toString(16).slice(2)}`;
  await client.query(`savepoint ${savepoint}`);
  try {
    await run();
    throw new Error(`${label}: operation unexpectedly succeeded.`);
  } catch (error) {
    await client.query(`rollback to savepoint ${savepoint}`);
    const message = String(error?.message ?? "");
    assert(
      acceptedMessages.some((item) => message.includes(item)) ||
        acceptedCodes.includes(error?.code),
      `${label}: unexpected rejection category.`,
    );
    pass(label);
  }
}

await client.connect();
try {
  await client.query("begin");

  const migration = await client.query(
    `select 1 from supabase_migrations.schema_migrations
     where version = '20260808010000'`,
  );
  assert(migration.rowCount === 1, "Messaging context migration is not applied.");
  pass("migration 20260808010000 is applied");

  const fixture = await client.query(`
    select thread.id, thread.teen_id, thread.adult_id, job.title
    from public.message_threads thread
    join public.jobs job on job.id = thread.job_id
    join public.conversations conversation
      on conversation.legacy_thread_id = thread.id
    join public.conversation_participants teen_participant
      on teen_participant.conversation_id = conversation.id
     and teen_participant.user_id = thread.teen_id
     and teen_participant.role = 'teen'
    join public.conversation_participants adult_participant
      on adult_participant.conversation_id = conversation.id
     and adult_participant.user_id = thread.adult_id
     and adult_participant.role = 'adult'
    join public.profiles teen on teen.id = thread.teen_id
    join public.profiles adult on adult.id = thread.adult_id
    where teen.is_test_account
      and adult.is_test_account
      and teen.account_status = 'active'
      and adult.account_status = 'active'
      and private.has_marketplace_identity(thread.teen_id)
      and private.has_marketplace_identity(thread.adult_id)
    order by thread.updated_at desc
    limit 1
  `);
  assert(fixture.rowCount === 1, "An active participant-only QA thread is required.");
  const thread = fixture.rows[0];

  await become("authenticated", thread.teen_id);
  const teenPage = await client.query(
    `select public.list_my_message_threads_page($1, null, null, 20) as result`,
    [thread.title],
  );
  const teenItems = teenPage.rows[0].result.items;
  const teenThread = teenItems.find((item) => item.id === thread.id);
  assert(teenThread, "Teen participant could not find the authorized thread.");
  assert(teenThread.job_title === thread.title, "Job context did not match.");
  assert(
    teenThread.counterparty_role === "adult",
    "Teen did not receive the adult participant role.",
  );
  const teenSerialized = JSON.stringify(teenThread);
  assert(!teenSerialized.includes("raw_body"), "Raw scanner evidence leaked.");
  assert(!teenSerialized.includes("exact_address"), "Exact address leaked.");
  pass("teen receives only public-safe participant and job context");

  const threadPage = await client.query(
    `select public.list_thread_messages_page($1, null, null, 1) as result`,
    [thread.id],
  );
  assert(
    threadPage.rows[0].result.thread.id === thread.id,
    "Thread page did not include its authorized summary.",
  );
  pass("message page includes the authorized thread summary");

  await become("authenticated", thread.adult_id);
  const adultPage = await client.query(
    `select public.list_my_message_threads_page($1, null, null, 20) as result`,
    [thread.title],
  );
  const adultThread = adultPage.rows[0].result.items.find(
    (item) => item.id === thread.id,
  );
  assert(adultThread, "Adult participant could not find the authorized thread.");
  assert(
    adultThread.counterparty_role === "teen",
    "Adult did not receive the teen participant role.",
  );
  pass("adult receives only the opposing participant context");

  await expectRejected(
    "authenticated callers cannot execute the private summary helper",
    () =>
      client.query(
        "select private.get_message_thread_summary($1, $2)",
        [thread.id, thread.adult_id],
      ),
    ["permission denied"],
    ["42501"],
  );

  await client.query("reset role");
  const outsider = await client.query(
    `select id
     from public.profiles
     where is_test_account
       and account_status = 'active'
       and role in ('teen', 'adult')
       and id not in ($1::uuid, $2::uuid)
     order by created_at
     limit 1`,
    [thread.teen_id, thread.adult_id],
  );
  assert(outsider.rowCount === 1, "An active outsider QA profile is required.");
  await become("authenticated", outsider.rows[0].id);
  await expectRejected(
    "outsider cannot read another thread",
    () =>
      client.query(
        "select public.list_thread_messages_page($1, null, null, 1)",
        [thread.id],
      ),
    ["thread_participant_required"],
  );

  await become("anon");
  await expectRejected(
    "anonymous caller cannot list message threads",
    () =>
      client.query(
        "select public.list_my_message_threads_page(null, null, null, 20)",
      ),
    ["authentication_required", "permission denied"],
    ["42501"],
  );

  await client.query("reset role");
  await client.query("rollback");
  pass("rollback-only QA completed without persistent writes");
} catch (error) {
  try {
    await client.query("reset role");
    await client.query("rollback");
  } catch {
    // Preserve the original failure.
  }
  console.error(`[qa-message-thread-context] FAIL: ${error.message}`);
  process.exitCode = 1;
} finally {
  await client.end();
}
