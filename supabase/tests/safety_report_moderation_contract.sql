begin;
select plan(11);

select has_function(
  'public',
  'mort_review_safety_report',
  array['uuid','text','text','uuid','timestamp with time zone']
);
select ok(
  not has_function_privilege('anon',
    'public.mort_review_safety_report(uuid,text,text,uuid,timestamp with time zone)',
    'execute'),
  'anonymous callers cannot moderate safety reports'
);
select ok(
  has_function_privilege('authenticated',
    'public.mort_review_safety_report(uuid,text,text,uuid,timestamp with time zone)',
    'execute'),
  'authenticated staff can invoke the protected moderation RPC'
);

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data,
  raw_user_meta_data, created_at, updated_at
) values
  ('41000000-0000-4000-8000-000000000001','authenticated','authenticated','reporter@example.invalid','','{}','{}',now(),now()),
  ('41000000-0000-4000-8000-000000000002','authenticated','authenticated','target@example.invalid','','{}','{}',now(),now()),
  ('41000000-0000-4000-8000-000000000003','authenticated','authenticated','moderator@example.invalid','','{}','{}',now(),now());

insert into public.profiles(id,role,account_status,date_of_birth)
values
  ('41000000-0000-4000-8000-000000000001','teen','active',current_date - interval '16 years'),
  ('41000000-0000-4000-8000-000000000002','adult','active',current_date - interval '30 years'),
  ('41000000-0000-4000-8000-000000000003','moderator','active',current_date - interval '30 years')
on conflict (id) do update set role=excluded.role,account_status=excluded.account_status;

insert into private.user_roles(user_id,role)
values ('41000000-0000-4000-8000-000000000003','moderator'::public.mort_role)
on conflict do nothing;

insert into public.safety_reports(
  id,reporter_id,reported_user_id,category,description,status,severity
) values (
  '42000000-0000-4000-8000-000000000001',
  '41000000-0000-4000-8000-000000000001',
  '41000000-0000-4000-8000-000000000002',
  'harassment','Synthetic report for isolated moderation contract testing.',
  'open','normal'
);

select set_config('request.jwt.claim.sub','41000000-0000-4000-8000-000000000003',true);
set local role authenticated;

create temporary table moderation_triage as
select public.mort_review_safety_report(
  '42000000-0000-4000-8000-000000000001',
  'triage',
  'Initial staff triage and ownership assignment.',
  null,
  (select updated_at from public.safety_reports where id='42000000-0000-4000-8000-000000000001')
) as result;

select is((select result->>'status' from moderation_triage),'triaged',
  'staff can move an open report into triage');
select is((select result->>'assigned_to' from moderation_triage),
  '41000000-0000-4000-8000-000000000003',
  'triage defaults ownership to the acting staff member');

create temporary table moderation_investigate as
select public.mort_review_safety_report(
  '42000000-0000-4000-8000-000000000001',
  'investigate',
  'Evidence review started by assigned staff.',
  null,
  (select updated_at from public.safety_reports where id='42000000-0000-4000-8000-000000000001')
) as result;

select is((select result->>'status' from moderation_investigate),'investigating',
  'triaged reports can enter investigation');

create temporary table moderation_resolve as
select public.mort_review_safety_report(
  '42000000-0000-4000-8000-000000000001',
  'resolve',
  'Investigation completed and outcome documented.',
  null,
  (select updated_at from public.safety_reports where id='42000000-0000-4000-8000-000000000001')
) as result;

select is((select result->>'status' from moderation_resolve),'resolved',
  'investigating reports can be resolved');
select ok(
  (select resolved_at is not null from public.safety_reports
   where id='42000000-0000-4000-8000-000000000001'),
  'resolved reports receive a resolution timestamp'
);

create temporary table moderation_reopen as
select public.mort_review_safety_report(
  '42000000-0000-4000-8000-000000000001',
  'reopen',
  'New evidence requires a second investigation.',
  null,
  (select updated_at from public.safety_reports where id='42000000-0000-4000-8000-000000000001')
) as result;

select is((select result->>'status' from moderation_reopen),'open',
  'resolved reports can be reopened with a reason');
select ok(
  (select resolved_at is null from public.safety_reports
   where id='42000000-0000-4000-8000-000000000001'),
  'reopened reports clear the resolution timestamp'
);
select is(
  (select count(*)::integer from public.admin_audit_log
   where target_type='safety_report'
     and target_id='42000000-0000-4000-8000-000000000001'),
  4,
  'every moderation transition is recorded in the admin audit log'
);

reset role;
rollback;
