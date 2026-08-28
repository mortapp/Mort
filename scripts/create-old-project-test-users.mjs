import { createClient } from "@supabase/supabase-js";
import pg from "pg";
import { randomUUID } from "node:crypto";

const { Client } = pg;

const oldProjectUrl = "https://rakjydmgwwgtdislanbt.supabase.co";
const password = process.env.MORT_REBUILD_TEST_PASSWORD;

const users = [
  { key: "teen", email: "teen.rebuild@mort.test", role: "teen", displayName: "Rebuild QA Teen", dob: "2010-04-18" },
  { key: "teen2", email: "teen2.rebuild@mort.test", role: "teen", displayName: "Rebuild QA Teen Two", dob: "2009-08-12" },
  { key: "adult", email: "adult.rebuild@mort.test", role: "adult", displayName: "Rebuild QA Adult", dob: "1994-03-10" },
  { key: "adult2", email: "adult2.rebuild@mort.test", role: "adult", displayName: "Rebuild QA Adult Two", dob: "1991-06-19" },
  { key: "guardian", email: "guardian.rebuild@mort.test", role: "guardian", displayName: "Rebuild QA Guardian", dob: "1989-09-22" },
  { key: "admin", email: "admin.rebuild@mort.test", role: "admin", displayName: "Rebuild QA Admin", dob: "1985-01-15" }
];

function fail(message) {
  console.error(`create-old-project-test-users failed: ${message}`);
  process.exit(1);
}

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const dbPassword = process.env.SUPABASE_DB_PASSWORD;

if (process.env.MORT_QA_TARGET !== "old-project-rebuild") fail("Set MORT_QA_TARGET=old-project-rebuild.");
if (process.env.MORT_REUSE_OLD_PROJECT_REF !== "rakjydmgwwgtdislanbt") fail("Set MORT_REUSE_OLD_PROJECT_REF=rakjydmgwwgtdislanbt.");
if (supabaseUrl !== oldProjectUrl) fail(`EXPO_PUBLIC_SUPABASE_URL must be ${oldProjectUrl}.`);
if (!serviceRoleKey) fail("Set SUPABASE_SERVICE_ROLE_KEY from the current rotated old-project key.");
if (!dbPassword) fail("Set SUPABASE_DB_PASSWORD for the old project.");
if (!password || password.length < 12) fail("Set MORT_REBUILD_TEST_PASSWORD to a temporary QA password at least 12 characters long.");

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false }
});

async function findUserByEmail(email) {
  for (let page = 1; page <= 10; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 100 });
    if (error) throw error;
    const found = data.users.find((user) => user.email?.toLowerCase() === email.toLowerCase());
    if (found) return found;
    if (data.users.length < 100) return null;
  }
  return null;
}

async function ensureAuthUser(input) {
  const existing = await findUserByEmail(input.email);
  if (existing) {
    await supabase.auth.admin.updateUserById(existing.id, { password, email_confirm: true });
    return existing;
  }

  const { data, error } = await supabase.auth.admin.createUser({
    email: input.email,
    password,
    email_confirm: true,
    user_metadata: { display_name: input.displayName }
  });

  if (error) throw error;
  return data.user;
}

const authUsers = {};
for (const user of users) {
  const authUser = await ensureAuthUser(user);
  authUsers[user.key] = authUser.id;
  console.log(`[old-project-users] ${user.email} -> ${authUser.id}`);
}

const ids = {
  guardianConnectionId: randomUUID(),
  verificationId: randomUUID(),
  adult2VerificationId: randomUUID(),
  jobId: randomUUID(),
  adult2JobId: randomUUID(),
  applicationId: randomUUID(),
  proofId: randomUUID(),
  reportId: randomUUID(),
  safetyPingId: randomUUID(),
  notificationId: randomUUID(),
  notificationEventId: randomUUID(),
  adminActionLogId: randomUUID()
};

const client = new Client({
  host: "db.rakjydmgwwgtdislanbt.supabase.co",
  port: 5432,
  database: "postgres",
  user: "postgres",
  password: dbPassword,
  ssl: { rejectUnauthorized: false }
});

await client.connect();

try {
  await client.query("begin");
  await client.query("select set_config('mort.internal_update', 'true', true)");
  await client.query("select set_config('mort.onboarding_completion', 'true', true)");

  for (const user of users) {
    await client.query(
      `
        insert into public.profiles (id, role, display_name, dob, city, state, onboarding_completed, verification_status)
        values ($1, $2::public.user_role, $3, $4::date, 'Carmel', 'IN', true, $5::public.verification_status)
        on conflict (id) do update
        set role = excluded.role,
            display_name = excluded.display_name,
            dob = excluded.dob,
            city = excluded.city,
            state = excluded.state,
            onboarding_completed = excluded.onboarding_completed,
            verification_status = excluded.verification_status
      `,
      [authUsers[user.key], user.role, user.displayName, user.dob, user.key === "adult" ? "approved" : "not_started"]
    );
  }

  for (const teenKey of ["teen", "teen2"]) {
    await client.query(
      `
        insert into public.teen_profiles (user_id, guardian_approval_required, skills)
        values ($1, true, array['yard work', 'pet care'])
        on conflict (user_id) do update set guardian_approval_required = excluded.guardian_approval_required, skills = excluded.skills
      `,
      [authUsers[teenKey]]
    );
  }

  for (const adultKey of ["adult", "adult2"]) {
    await client.query(
      `
        insert into public.adult_profiles (user_id, business_name, business_type)
        values ($1, $2, 'home services')
        on conflict (user_id) do update set business_name = excluded.business_name, business_type = excluded.business_type
      `,
      [authUsers[adultKey], adultKey === "adult" ? "Rebuild QA Business" : "Rebuild QA Other Business"]
    );
  }

  await client.query(
    `
      insert into public.guardian_profiles (user_id, emergency_contact_name)
      values ($1, 'Rebuild QA Guardian')
      on conflict (user_id) do update set emergency_contact_name = excluded.emergency_contact_name
    `,
    [authUsers.guardian]
  );

  await client.query(
    `
      with existing as (
        select id from public.guardian_connections
        where teen_id = $2 and guardian_id = $3 and status = 'active'
        limit 1
      ),
      inserted as (
        insert into public.guardian_connections (id, teen_id, guardian_id, status, invite_code)
        select $1, $2, $3, 'active', $4
        where not exists (select 1 from existing)
        returning id
      )
      select id from inserted
      union all
      select id from existing
    `,
    [ids.guardianConnectionId, authUsers.teen, authUsers.guardian, `RB${Date.now().toString().slice(-6)}`]
  );

  await client.query(
    `
      insert into public.business_verifications (id, adult_id, business_name, business_type, notes, status, reviewed_by)
      values ($1, $2, 'Rebuild QA Business', 'home services', 'Old-project rebuild approved verification.', 'approved', $3)
    `,
    [ids.verificationId, authUsers.adult, authUsers.admin]
  );

  await client.query(
    `
      insert into public.business_verifications (id, adult_id, business_name, business_type, notes, status)
      values ($1, $2, 'Rebuild QA Other Business', 'home services', 'Old-project rebuild pending verification.', 'pending')
    `,
    [ids.adult2VerificationId, authUsers.adult2]
  );

  await client.query(
    `
      insert into public.jobs (id, poster_id, title, description, category, location_text, city, state, pay_label, teen_min_age, teen_max_age, requires_guardian_approval, status)
      values ($1, $2, 'Rebuild QA Yard Cleanup', 'Rake leaves and bag yard waste.', 'yard work', 'Near Main St', 'Carmel', 'IN', '$40 after completion', 13, 17, true, 'open')
    `,
    [ids.jobId, authUsers.adult]
  );

  await client.query(
    `
      insert into public.jobs (id, poster_id, title, description, category, location_text, city, state, pay_label, teen_min_age, teen_max_age, requires_guardian_approval, status)
      values ($1, $2, 'Rebuild QA Garage Sweep', 'Sweep a small garage and stack bins.', 'cleaning', 'Near Oak Ave', 'Carmel', 'IN', '$25 after completion', 13, 17, true, 'open')
    `,
    [ids.adult2JobId, authUsers.adult2]
  );

  await client.query(
    `
      insert into public.applications (id, job_id, teen_id, guardian_id, status, note)
      values ($1, $2, $3, $4, 'accepted', 'Old-project rebuild accepted application.')
    `,
    [ids.applicationId, ids.jobId, authUsers.teen, authUsers.guardian]
  );

  const threadResult = await client.query("select id from public.message_threads where application_id = $1 limit 1", [ids.applicationId]);
  const threadId = threadResult.rows[0]?.id;
  if (threadId) {
    await client.query(
      `
        insert into public.messages (thread_id, sender_id, body, scanner_status)
        values ($1, $2, 'I can do this after school and will keep updates in MORT.', 'clean')
      `,
      [threadId, authUsers.teen]
    );
  }

  const proofPath = `${authUsers.teen}/old-project-rebuild-proof.jpg`;
  await client.query(
    `
      insert into public.proof_uploads (id, application_id, uploaded_by, storage_path, note)
      values ($1, $2, $3, $4, 'Old-project rebuild proof metadata.')
    `,
    [ids.proofId, ids.applicationId, authUsers.teen, proofPath]
  );

  const { error: proofUploadError } = await supabase.storage
    .from("proof-uploads")
    .upload(proofPath, Buffer.from("MORT old-project rebuild proof placeholder"), {
      contentType: "image/jpeg",
      upsert: true
    });
  if (proofUploadError) throw proofUploadError;

  await client.query(
    `
      insert into public.reports (id, reporter_id, target_user_id, target_job_id, reason, details, status)
      values ($1, $2, $3, $4, 'Old-project rebuild moderation test', 'Seeded report for admin queue testing.', 'open')
    `,
    [ids.reportId, authUsers.teen, authUsers.adult, ids.jobId]
  );

  await client.query(
    `
      insert into public.safety_pings (id, teen_id, guardian_id, status, note)
      values ($1, $2, $3, 'ok', 'Old-project rebuild safety ping.')
    `,
    [ids.safetyPingId, authUsers.teen, authUsers.guardian]
  );

  await client.query(
    `
      insert into public.notifications (id, recipient_id, title, body, data)
      values ($1, $2, 'Rebuild QA notification', 'Open MORT for details.', '{"type":"old-project-rebuild"}')
    `,
    [ids.notificationId, authUsers.guardian]
  );

  await client.query(
    `
      insert into public.notification_events (id, recipient_id, title, body, data)
      values ($1, $2, 'Rebuild QA push event', 'Open MORT for details.', '{"type":"old-project-rebuild"}')
    `,
    [ids.notificationEventId, authUsers.guardian]
  );

  await client.query(
    `
      insert into public.admin_action_logs (id, admin_id, action, target_table, target_id, details)
      values ($1, $2, 'old_project_rebuild_seed', 'reports', $3, '{"type":"old-project-rebuild"}')
    `,
    [ids.adminActionLogId, authUsers.admin, ids.reportId]
  );

  await client.query("commit");
} catch (error) {
  await client.query("rollback");
  throw error;
} finally {
  await client.end();
}

console.log("[old-project-users] Created old-project rebuild QA auth users and sample data.");
console.log("[old-project-users] Rebuild QA user password is set locally and was not printed.");
