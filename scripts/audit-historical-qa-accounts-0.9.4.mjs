import { withDatabase } from "./feature-qa-helpers.mjs";

const report = await withDatabase(async (database) => {
  const summary = await database.query(`
    with qa as (
      select profile.id, profile.role, profile.account_status,
             profile.display_name, auth_user.email, auth_user.phone,
             auth_user.created_at
      from public.profiles profile
      join auth.users auth_user on auth_user.id = profile.id
      where profile.is_test_account
    )
    select
      (select count(*)::integer from auth.users) as total_auth_users,
      count(*)::integer as qa_users,
      count(*) filter (where account_status = 'active')::integer as qa_active,
      count(*) filter (where account_status <> 'active')::integer as qa_restricted,
      count(*) filter (where role = 'teen')::integer as qa_teens,
      count(*) filter (where role = 'adult')::integer as qa_adults,
      count(*) filter (where role = 'guardian')::integer as qa_guardians,
      count(*) filter (where role = 'admin')::integer as qa_profile_admins,
      count(*) filter (where email ~* '@mort\\.test$')::integer as synthetic_email_domain,
      count(*) filter (where email !~* '@mort\\.test$')::integer as non_mort_test_email_domain,
      count(*) filter (where phone is not null)::integer as phone_values_present,
      count(*) filter (
        where coalesce(display_name, '') !~* '^(qa|mort review|test|play review)'
      )::integer as nonsynthetic_name_indicator,
      count(*) filter (
        where email ~* '^qa-feature-[a-z0-9_-]+-[a-z0-9-]+@mort\\.test$'
      )::integer as strict_feature_qa_users,
      count(*) filter (where created_at < now() - interval '24 hours')::integer as older_than_24_hours
    from qa
  `);

  const privileges = await database.query(`
    with qa as (select id from public.profiles where is_test_account)
    select
      (select count(*)::integer from public.admin_role_assignments assignment
       where assignment.user_id in (select id from qa) and assignment.revoked_at is null) as admin_safety_roles,
      (select count(*)::integer from private.support_staff_assignments assignment
       where assignment.user_id in (select id from qa) and assignment.revoked_at is null
         and assignment.expires_at > now()) as support_roles,
      (select count(*)::integer from private.stripe_financial_role_assignments assignment
       where assignment.user_id in (select id from qa) and assignment.revoked_at is null
         and assignment.expires_at > now()) as financial_roles,
      (select count(*)::integer from public.team_role_assignments assignment
       where assignment.user_id in (select id from qa) and assignment.revoked_at is null
         and (assignment.expires_at is null or assignment.expires_at > now())) as trust_team_roles,
      (select count(*)::integer from public.partner_staff staff
       where staff.user_id in (select id from qa) and staff.revoked_at is null
         and staff.status = 'active'
         and (staff.expires_at is null or staff.expires_at > now())) as partner_staff_roles
  `);

  const sessions = await database.query(`
    with qa as (select id from public.profiles where is_test_account)
    select
      (select count(*)::integer from auth.sessions session
       where session.user_id in (select id from qa)) as auth_sessions,
      (select count(*)::integer from auth.refresh_tokens token
       where token.user_id in (select id::text from qa) and not token.revoked) as active_refresh_tokens
  `);

  const data = await database.query(`
    with qa as (select id from public.profiles where is_test_account)
    select
      (select count(*)::integer from public.identity_verifications verification
       where verification.user_id in (select id from qa)
         and verification.environment = 'production') as production_identity_records,
      (select count(*)::integer from public.identity_verification_evidence evidence
       join public.identity_verifications verification on verification.id = evidence.verification_id
       where verification.user_id in (select id from qa)) as identity_evidence_records,
      (select count(*)::integer from public.proof_uploads proof
       where proof.uploaded_by in (select id from qa)) as proof_records,
      (select count(*)::integer from public.support_evidence_attachments evidence
       where evidence.owner_id in (select id from qa)) as support_evidence_records,
      (select count(*)::integer from storage.objects object
       where split_part(object.name, '/', 1) in (select id::text from qa)) as owned_storage_objects
  `);

  return {
    project_ref: "rakjydmgwwgtdislanbt",
    generated_at: new Date().toISOString(),
    aggregate_only: true,
    account_summary: summary.rows[0],
    active_privilege_assignments: privileges.rows[0],
    session_summary: sessions.rows[0],
    sensitive_data_indicators: data.rows[0],
    interpretation: {
      no_account_identifiers_printed: true,
      real_person_content_not_opened: true,
      zero_privilege_assignments_required_before_real_users: true,
      zero_production_identity_records_required: true,
      evidence_or_storage_counts_require_owner_classification_before_deletion: true,
    },
  };
});

process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
