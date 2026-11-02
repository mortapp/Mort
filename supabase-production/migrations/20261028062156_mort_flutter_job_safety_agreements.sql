-- A participant-scoped safety plan and mutual confirmation for the current
-- job_applications/job_assignments schema. Older safety migrations target
-- the removed public.applications model and must not be replayed here.

create table public.job_safety_plans (
  application_id uuid primary key
    references public.job_applications(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  teen_id uuid not null references public.profiles(id) on delete restrict,
  adult_id uuid not null references public.profiles(id) on delete restrict,
  expected_people text,
  public_or_visible_meeting boolean not null default true,
  daylight_preferred boolean not null default true,
  transportation_plan text,
  checkin_cadence_minutes integer,
  teen_updated_at timestamptz,
  adult_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_safety_plans_party_check check (teen_id <> adult_id),
  constraint job_safety_plans_people_length
    check (expected_people is null or char_length(expected_people) <= 500),
  constraint job_safety_plans_transport_length
    check (transportation_plan is null or char_length(transportation_plan) <= 1000),
  constraint job_safety_plans_cadence_check
    check (checkin_cadence_minutes is null or checkin_cadence_minutes between 15 and 240)
);

create table public.job_safety_agreements (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique
    references public.job_applications(id) on delete restrict,
  job_id uuid not null references public.jobs(id) on delete restrict,
  teen_id uuid not null references public.profiles(id) on delete restrict,
  adult_id uuid not null references public.profiles(id) on delete restrict,
  agreement_version integer not null default 1,
  terms_snapshot jsonb not null,
  material_terms_hash text not null,
  status text not null default 'awaiting_both',
  teen_confirmed_at timestamptz,
  adult_confirmed_at timestamptz,
  teen_confirmed_version integer,
  adult_confirmed_version integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_safety_agreements_party_check check (teen_id <> adult_id),
  constraint job_safety_agreements_version_check check (agreement_version > 0),
  constraint job_safety_agreements_hash_check
    check (material_terms_hash ~ '^[a-f0-9]{64}$'),
  constraint job_safety_agreements_status_check check (
    status in (
      'awaiting_both', 'awaiting_teen', 'awaiting_adult',
      'confirmed', 'reconfirmation_required'
    )
  )
);

create index job_safety_plans_job_status_idx
  on public.job_safety_plans(job_id, updated_at desc);
create index job_safety_agreements_participants_idx
  on public.job_safety_agreements(teen_id, adult_id, status);

alter table public.job_safety_plans enable row level security;
alter table public.job_safety_agreements enable row level security;

revoke all on public.job_safety_plans, public.job_safety_agreements
  from public, anon, authenticated;
grant select on public.job_safety_plans, public.job_safety_agreements
  to authenticated;

create or replace function private.is_job_safety_participant(
  p_application_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select p_user_id is not null
    and p_user_id = (select auth.uid())
    and exists (
      select 1
      from public.job_applications application
      join public.jobs job on job.id = application.job_id
      join public.job_assignments assignment
        on assignment.application_id = application.id
       and assignment.job_id = application.job_id
      where application.id = p_application_id
        and p_user_id in (application.applicant_id, job.poster_id)
    );
$function$;

revoke all on function private.is_job_safety_participant(uuid, uuid)
  from public, anon;
grant execute on function private.is_job_safety_participant(uuid, uuid)
  to authenticated;

create policy job_safety_plan_participants_read
  on public.job_safety_plans
  for select to authenticated
  using (private.is_job_safety_participant(application_id, (select auth.uid())));

create policy job_safety_agreement_participants_read
  on public.job_safety_agreements
  for select to authenticated
  using (private.is_job_safety_participant(application_id, (select auth.uid())));

create or replace function private.job_safety_terms(p_application_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'job_id', job.id,
    'job_title', job.title,
    'scope', coalesce(nullif(job.summary, ''), job.description),
    'approximate_area', jsonb_build_object(
      'city', job.city,
      'region', job.region,
      'remote', job.remote_allowed
    ),
    'who_will_be_present', coalesce(
      nullif(plan.expected_people, ''),
      case when job.adult_supervision_present
        then 'The job poster reports adult supervision will be present.'
        else 'Presence details must be agreed before the job starts.'
      end
    ),
    'physical_requirements', to_jsonb(job.physical_requirements),
    'hazards', job.safety_notes,
    'equipment', jsonb_build_object(
      'provided', job.equipment_provided,
      'worker_brings', job.equipment_worker_brings
    ),
    'payment', jsonb_build_object(
      'amount_cents', job.pay_amount_cents,
      'type', job.payment_type,
      'method_preference', job.payment_method,
      'timing', job.payment_timing
    ),
    'proof_expected', job.proof_expected,
    'safety_plan', jsonb_build_object(
      'public_or_visible_meeting', plan.public_or_visible_meeting,
      'daylight_preferred', plan.daylight_preferred,
      'transportation_plan', plan.transportation_plan,
      'checkin_cadence_minutes', plan.checkin_cadence_minutes
    ),
    'contract', (
      select jsonb_build_object(
        'contract_id', contract.id,
        'version_id', coalesce(contract.active_version_id, latest.id),
        'content_hash', latest.content_hash,
        'status', contract.status
      )
      from public.job_contracts contract
      left join lateral (
        select version.id, version.content_hash
        from public.job_contract_versions version
        where version.contract_id = contract.id
        order by version.version_number desc
        limit 1
      ) latest on true
      where contract.application_id = application.id
    ),
    'exact_location_policy',
      'The exact address stays private until the authorized job stage.',
    'communication_boundaries', jsonb_build_array(
      'Keep job communication in MORT.',
      'No harassment, sexual behavior, threats, weapons, alcohol, or drugs.',
      'No forced off-platform contact or unapproved work changes.'
    ),
    'right_to_leave', true,
    'verification_not_safety_guarantee', true
  )
  from public.job_applications application
  join public.jobs job on job.id = application.job_id
  left join public.job_safety_plans plan on plan.application_id = application.id
  where application.id = p_application_id;
$function$;

revoke all on function private.job_safety_terms(uuid)
  from public, anon, authenticated;

create or replace function private.refresh_job_safety_agreement(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_terms jsonb;
begin
  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null then
    return;
  end if;

  update public.job_safety_agreements
  set agreement_version = agreement_version + 1,
      terms_snapshot = v_terms,
      material_terms_hash = encode(extensions.digest(v_terms::text, 'sha256'), 'hex'),
      status = 'reconfirmation_required',
      teen_confirmed_at = null,
      adult_confirmed_at = null,
      teen_confirmed_version = null,
      adult_confirmed_version = null,
      updated_at = now()
  where application_id = p_application_id;
end;
$function$;

revoke all on function private.refresh_job_safety_agreement(uuid)
  from public, anon, authenticated;

create or replace function private.create_job_safety_agreement_after_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_job public.jobs%rowtype;
  v_terms jsonb;
begin
  if new.status <> 'accepted'::public.mort_application_status
     or old.status is not distinct from new.status then
    return new;
  end if;

  select * into v_job from public.jobs where id = new.job_id;
  if v_job.id is null then
    raise exception 'Safety agreement job is unavailable';
  end if;

  insert into public.job_safety_plans (
    application_id, job_id, teen_id, adult_id,
    public_or_visible_meeting, daylight_preferred, checkin_cadence_minutes
  ) values (
    new.id, new.job_id, new.applicant_id, v_job.poster_id, true, true, 30
  ) on conflict (application_id) do nothing;

  v_terms := private.job_safety_terms(new.id);
  insert into public.job_safety_agreements (
    application_id, job_id, teen_id, adult_id,
    terms_snapshot, material_terms_hash
  ) values (
    new.id, new.job_id, new.applicant_id, v_job.poster_id,
    v_terms, encode(extensions.digest(v_terms::text, 'sha256'), 'hex')
  ) on conflict (application_id) do nothing;

  return new;
end;
$function$;

revoke all on function private.create_job_safety_agreement_after_acceptance()
  from public, anon, authenticated;

create trigger job_applications_create_safety_agreement
after update of status on public.job_applications
for each row execute function private.create_job_safety_agreement_after_acceptance();

create or replace function private.refresh_safety_agreement_after_contract_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.active_version_id is distinct from old.active_version_id
     and new.active_version_id is not null then
    perform private.refresh_job_safety_agreement(new.application_id);
  end if;
  return new;
end;
$function$;

revoke all on function private.refresh_safety_agreement_after_contract_change()
  from public, anon, authenticated;

create trigger job_contracts_refresh_safety_agreement
after update of active_version_id on public.job_contracts
for each row execute function private.refresh_safety_agreement_after_contract_change();

create or replace function public.save_job_safety_plan(
  p_application_id uuid,
  p_expected_people text,
  p_public_or_visible_meeting boolean,
  p_daylight_preferred boolean,
  p_transportation_plan text,
  p_checkin_cadence_minutes integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_plan public.job_safety_plans%rowtype;
  v_agreement public.job_safety_agreements%rowtype;
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;
  if char_length(coalesce(p_expected_people, '')) > 500
     or char_length(coalesce(p_transportation_plan, '')) > 1000
     or p_checkin_cadence_minutes is null
     or p_checkin_cadence_minutes not between 15 and 240
     or p_public_or_visible_meeting is null
     or p_daylight_preferred is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_safety_plan');
  end if;

  update public.job_safety_plans
  set expected_people = nullif(left(btrim(coalesce(p_expected_people, '')), 500), ''),
      public_or_visible_meeting = p_public_or_visible_meeting,
      daylight_preferred = p_daylight_preferred,
      transportation_plan = nullif(left(btrim(coalesce(p_transportation_plan, '')), 1000), ''),
      checkin_cadence_minutes = p_checkin_cadence_minutes,
      teen_updated_at = case when teen_id = v_user then now() else teen_updated_at end,
      adult_updated_at = case when adult_id = v_user then now() else adult_updated_at end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_plan;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_not_found');
  end if;

  perform private.refresh_job_safety_agreement(p_application_id);
  select * into v_agreement from public.job_safety_agreements
  where application_id = p_application_id;

  return jsonb_build_object(
    'ok', true,
    'plan', to_jsonb(v_plan),
    'agreement_version', v_agreement.agreement_version,
    'agreement_status', v_agreement.status
  );
end;
$function$;

create or replace function public.confirm_job_safety_agreement(
  p_application_id uuid,
  p_agreement_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_agreement public.job_safety_agreements%rowtype;
  v_terms jsonb;
begin
  if v_user is null or not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  if not private.is_job_safety_participant(p_application_id, v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_participant_required');
  end if;
  if not exists (
    select 1
    from public.job_applications application
    join public.job_assignments assignment
      on assignment.application_id = application.id
     and assignment.job_id = application.job_id
    where application.id = p_application_id
      and application.status = 'accepted'::public.mort_application_status
      and assignment.status = 'accepted'
  ) then
    return jsonb_build_object('ok', false, 'code', 'accepted_job_required');
  end if;

  select * into v_agreement
  from public.job_safety_agreements
  where application_id = p_application_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_not_found');
  end if;
  if p_agreement_version is null
     or p_agreement_version <> v_agreement.agreement_version then
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  v_terms := private.job_safety_terms(p_application_id);
  if v_terms is null
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_agreement.terms_snapshot::text, 'sha256'), 'hex')
     or v_agreement.material_terms_hash <>
       encode(extensions.digest(v_terms::text, 'sha256'), 'hex') then
    perform private.refresh_job_safety_agreement(p_application_id);
    return jsonb_build_object('ok', false, 'code', 'safety_agreement_version_changed');
  end if;

  if not exists (
    select 1 from public.job_safety_plans plan
    where plan.application_id = p_application_id
      and plan.checkin_cadence_minutes between 15 and 240
      and (plan.expected_people is not null or exists (
        select 1 from public.jobs job
        where job.id = plan.job_id and job.remote_allowed
      ))
  ) then
    return jsonb_build_object('ok', false, 'code', 'safety_plan_required');
  end if;

  update public.job_safety_agreements
  set teen_confirmed_at = case when teen_id = v_user then coalesce(teen_confirmed_at, now()) else teen_confirmed_at end,
      adult_confirmed_at = case when adult_id = v_user then coalesce(adult_confirmed_at, now()) else adult_confirmed_at end,
      teen_confirmed_version = case when teen_id = v_user then agreement_version else teen_confirmed_version end,
      adult_confirmed_version = case when adult_id = v_user then agreement_version else adult_confirmed_version end,
      updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  update public.job_safety_agreements
  set status = case
    when teen_confirmed_version = agreement_version
      and adult_confirmed_version = agreement_version then 'confirmed'
    when teen_confirmed_version = agreement_version then 'awaiting_adult'
    when adult_confirmed_version = agreement_version then 'awaiting_teen'
    else 'awaiting_both'
  end,
  updated_at = now()
  where application_id = p_application_id
  returning * into v_agreement;

  return jsonb_build_object(
    'ok', true,
    'status', v_agreement.status,
    'agreement_version', v_agreement.agreement_version,
    'both_confirmed', v_agreement.status = 'confirmed'
  );
end;
$function$;

revoke all on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer)
  from public, anon;
revoke all on function public.confirm_job_safety_agreement(uuid, integer)
  from public, anon;
grant execute on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer)
  to authenticated;
grant execute on function public.confirm_job_safety_agreement(uuid, integer)
  to authenticated;

comment on table public.job_safety_agreements is
  'Immutable, participant-scoped safety snapshots for accepted MORT jobs; material changes invalidate both confirmations.';
comment on function public.save_job_safety_plan(uuid, text, boolean, boolean, text, integer) is
  'Saves an accepted job participants’ safety plan and clears prior confirmations when it changes.';
comment on function public.confirm_job_safety_agreement(uuid, integer) is
  'Records one current participant confirmation; the agreement is confirmed only after both parties accept the same hashed snapshot.';

