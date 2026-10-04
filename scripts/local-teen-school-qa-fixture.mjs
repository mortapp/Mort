// Use the real school binding gate for synthetic teens on the local MORT stack.
// This fixture never approves a production domain or runs against hosted data.
export async function bindLocalTeenSchool(db, userId, dob, isTestAccount = true) {
  const databaseUrl = new URL(process.env.SUPABASE_DB_URL ?? "postgres://invalid");
  if (process.env.MORT_QA_LOCAL_SUPABASE !== "true" ||
      !["127.0.0.1", "localhost"].includes(databaseUrl.hostname) ||
      databaseUrl.port !== "54322") {
    throw new Error("Synthetic school fixture requires the local MORT database.");
  }
  if (!isTestAccount) {
    // Production-mode QA users exist only in this local database. This does
    // not seed any hosted or release school-domain approval.
    await db.query(
      `insert into public.school_domains (
         normalized_domain, organization_name, organization_type, status,
         environment, official_source_url, approved_at, expires_at
       ) values (
         'qa-school.mort.test', 'MORT local ordinary-teen QA domain', 'school',
         'approved', 'production', 'https://mort.test/qa-only',
         now(), now() + interval '1 year'
       ) on conflict (normalized_domain, environment) do update
         set status = 'approved', approved_at = now(),
             expires_at = excluded.expires_at`,
    );
  }
  const environment = isTestAccount ? "sandbox" : "production";
  const emailDomain = isTestAccount ? "mort.test" : "qa-school.mort.test";
  const domain = await db.query(
    `select id from public.school_domains
     where normalized_domain = $2
       and environment = $1::public.verification_environment
       and status = 'approved'
       and (expires_at is null or expires_at > now())`,
    [environment, emailDomain],
  );
  if (domain.rowCount !== 1) {
    throw new Error("The local synthetic school domain is missing.");
  }
  const school = await db.query(
    `insert into public.schools (
       official_name, display_name, city, state, school_type,
       status, official_source_url
     ) values (
       'MORT Isolated QA School', 'MORT Isolated QA School',
       'Indianapolis', 'IN', 'high_school', 'listed', 'https://mort.test/qa-only'
     ) on conflict (official_name, city, state) do update
       set status = 'listed'
     returning id`,
  );
  await db.query(
    `insert into private.school_domain_assignments (
       school_id, domain_id, status, student_allowed,
       evidence_source_url, reviewed_at, expires_at
     ) values ($1, $2, 'approved', true, 'https://mort.test/qa-only',
       now(), now() + interval '1 year')
     on conflict (school_id, domain_id) do update
       set status = 'approved', student_allowed = true,
           evidence_source_url = excluded.evidence_source_url,
           reviewed_at = now(), expires_at = excluded.expires_at`,
    [school.rows[0].id, domain.rows[0].id],
  );
  // The trigger checks the existing profile row, so age and test isolation
  // must be present before assigning the teen role.
  await db.query(
    `update public.profiles set dob = $2::date, is_test_account = $3
     where id = $1 and role is null`,
    [userId, dob, isTestAccount],
  );
  await db.query(
    `insert into private.teen_school_email_bindings (
       user_id, school_id, domain_id, status
     ) values ($1, $2, $3, 'verified')
     on conflict (user_id) do update set
       school_id = excluded.school_id, domain_id = excluded.domain_id,
       status = 'verified', revoked_at = null, verified_at = now()`,
    [userId, school.rows[0].id, domain.rows[0].id],
  );
}
