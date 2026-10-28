-- Permit real, resumable drafts while preserving strict publication rules.
alter table public.jobs alter column city drop not null;
alter table public.jobs alter column region drop not null;

alter table public.jobs drop constraint if exists jobs_title_check;
alter table public.jobs add constraint jobs_title_check check (
  char_length(title) <= 120 and (status = 'draft'::public.mort_job_status or char_length(title) >= 5)
);
alter table public.jobs drop constraint if exists jobs_description_check;
alter table public.jobs add constraint jobs_description_check check (
  char_length(description) <= 5000 and (status = 'draft'::public.mort_job_status or char_length(description) >= 20)
);
alter table public.jobs drop constraint if exists jobs_pay_amount_check;
alter table public.jobs add constraint jobs_pay_amount_check check (
  pay_amount >= 0 and pay_amount <= 10000
  and (status = 'draft'::public.mort_job_status or pay_amount > 0)
);
alter table public.jobs add constraint jobs_publication_requirements_check check (
  status = 'draft'::public.mort_job_status
  or (
    char_length(title) between 5 and 120
    and char_length(description) between 20 and 5000
    and pay_amount > 0
    and city is not null and btrim(city) <> ''
    and region is not null and btrim(region) <> ''
  )
);

create table if not exists private.mort_job_mutation_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  client_request_id uuid not null,
  operation text not null,
  request_hash text not null,
  response jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, client_request_id)
);
revoke all on private.mort_job_mutation_requests from public, anon, authenticated;

create table if not exists public.job_status_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  from_status public.mort_job_status,
  to_status public.mort_job_status not null,
  action text not null,
  created_at timestamptz not null default now()
);
create index if not exists job_status_events_job_created_idx
  on public.job_status_events (job_id, created_at, id);
alter table public.job_status_events enable row level security;
create or replace function private.can_access_job_status_events(p_job_id uuid)
returns boolean language sql stable security definer set search_path = '' as $function$
  select auth.uid() is not null and private.is_active_user() and (
    private.has_staff_role(array['admin','moderator']::public.mort_role[])
    or exists(select 1 from public.jobs j where j.id=p_job_id and j.poster_id=auth.uid())
    or exists(select 1 from public.job_applications ja where ja.job_id=p_job_id and ja.applicant_id=auth.uid())
    or exists(select 1 from public.job_assignments a where a.job_id=p_job_id and (a.teen_user_id=auth.uid() or a.adult_user_id=auth.uid()))
    or exists(
      select 1 from public.guardian_links gl
      join public.job_applications ja on ja.applicant_id=gl.teen_user_id
      where ja.job_id=p_job_id and gl.guardian_user_id=auth.uid() and gl.status='active'
        and gl.teen_consent_at is not null and gl.guardian_consent_at is not null
    )
  );
$function$;
revoke all on function private.can_access_job_status_events(uuid) from public,anon;
grant execute on function private.can_access_job_status_events(uuid) to authenticated;
drop policy if exists job_status_events_select_participant on public.job_status_events;
create policy job_status_events_select_participant on public.job_status_events
for select to authenticated using (private.can_access_job_status_events(job_id));
revoke all on public.job_status_events from anon, authenticated;
grant select on public.job_status_events to authenticated;

create or replace function private.can_access_application_status_events(p_application_id uuid)
returns boolean language sql stable security definer set search_path = '' as $function$
  select auth.uid() is not null and private.is_active_user() and (
    private.has_staff_role(array['admin','moderator']::public.mort_role[])
    or exists(
      select 1 from public.job_applications ja join public.jobs j on j.id=ja.job_id
      where ja.id=p_application_id and (
        ja.applicant_id=auth.uid() or j.poster_id=auth.uid()
        or exists(select 1 from public.guardian_links gl
          where gl.teen_user_id=ja.applicant_id and gl.guardian_user_id=auth.uid()
            and gl.status='active' and gl.teen_consent_at is not null and gl.guardian_consent_at is not null)
      )
    )
  );
$function$;
revoke all on function private.can_access_application_status_events(uuid) from public,anon;
grant execute on function private.can_access_application_status_events(uuid) to authenticated;
drop policy if exists application_status_events_select_participant on public.application_status_events;
create policy application_status_events_select_participant on public.application_status_events
for select to authenticated using (private.can_access_application_status_events(application_id));

create or replace function private.capture_job_status_event()
returns trigger language plpgsql security definer set search_path = '' as $function$
declare
  v_action text := coalesce(nullif(current_setting('mort.job_action', true), ''), 'status_changed');
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.job_status_events(job_id, actor_id, from_status, to_status, action)
    values (new.id, auth.uid(), case when tg_op = 'INSERT' then null else old.status end, new.status, v_action);
  end if;
  return new;
end;
$function$;
revoke all on function private.capture_job_status_event() from public, anon, authenticated;
drop trigger if exists jobs_log_status_event on public.jobs;
create trigger jobs_log_status_event after insert or update of status on public.jobs
for each row execute function private.capture_job_status_event();

-- Direct client table writes could otherwise bypass review and lifecycle RPCs.
create or replace function private.guard_job_table_mutations()
returns trigger language plpgsql set search_path = '' as $function$
begin
  if current_user in ('anon', 'authenticated') then
    raise exception using errcode = '42501', message = 'Use the protected job operations.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$function$;
revoke all on function private.guard_job_table_mutations() from public, anon, authenticated;
drop trigger if exists jobs_require_protected_mutation on public.jobs;
create trigger jobs_require_protected_mutation before insert or update or delete on public.jobs
for each row execute function private.guard_job_table_mutations();

create or replace function public.save_job_draft_or_publish(
  p_job_id uuid,
  p_client_request_id uuid,
  p_payload jsonb,
  p_publish boolean
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user uuid := auth.uid();
  v_existing public.jobs%rowtype;
  v_job public.jobs%rowtype;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_category text := v_payload->>'category';
  v_title text := btrim(coalesce(v_payload->>'title', ''));
  v_description text := btrim(coalesce(v_payload->>'description', ''));
  v_city text := nullif(btrim(coalesce(v_payload->>'city', '')), '');
  v_region text := nullif(upper(btrim(coalesce(v_payload->>'state', ''))), '');
  v_amount_cents integer := nullif(v_payload->>'adult_job_amount_cents', '')::integer;
  v_min_age integer := coalesce(nullif(v_payload->>'teen_min_age', '')::integer, 13);
  v_max_age integer := coalesce(nullif(v_payload->>'teen_max_age', '')::integer, 17);
  v_schedule text := coalesce(nullif(v_payload->>'schedule_type', ''), 'flexible');
  v_payment_type text := coalesce(nullif(v_payload->>'payment_type', ''), 'fixed');
  v_hash text;
  v_response jsonb;
  v_inserted integer;
  v_state public.mort_job_status;
  v_public_enabled boolean;
  v_maintenance boolean;
begin
  if v_user is null or not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
    return jsonb_build_object('ok', false, 'code', 'active_adult_account_required');
  end if;
  if p_client_request_id is null or jsonb_typeof(v_payload) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'job_save_request_invalid');
  end if;
  if v_category not in ('yard_work','pet_care','tutoring','household_help','moving_help','tech_help','other') then
    return jsonb_build_object('ok', false, 'code', 'job_category_invalid', 'field', 'category');
  end if;
  if char_length(v_title) > 120 or char_length(v_description) > 5000 then
    return jsonb_build_object('ok', false, 'code', 'job_content_too_long');
  end if;
  if v_amount_cents is not null and (v_amount_cents < 0 or v_amount_cents > 1000000) then
    return jsonb_build_object('ok', false, 'code', 'job_amount_invalid', 'field', 'adult_job_amount_cents');
  end if;
  if v_min_age < 13 or v_min_age > 17 or v_max_age < v_min_age or v_max_age > 17 then
    return jsonb_build_object('ok', false, 'code', 'job_age_range_invalid');
  end if;
  if v_schedule not in ('flexible','exact') or v_payment_type not in ('fixed','hourly') then
    return jsonb_build_object('ok', false, 'code', 'job_schedule_or_payment_invalid');
  end if;
  if p_publish and (char_length(v_title) < 5 or char_length(v_description) < 20
      or coalesce(v_amount_cents,0) <= 0 or v_city is null or v_region is null) then
    return jsonb_build_object('ok', false, 'code', 'job_publication_fields_required');
  end if;
  if p_publish then
    select public_marketplace_enabled, maintenance_mode into v_public_enabled, v_maintenance
    from public.mort_release_control where is_primary;
    if not coalesce(v_public_enabled, false) or coalesce(v_maintenance, true) then
      return jsonb_build_object('ok', false, 'code', 'marketplace_unavailable');
    end if;
  end if;

  select * into v_existing from public.jobs where id = p_job_id for update;
  if p_job_id is not null and (not found or v_existing.poster_id <> v_user) then
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;
  if p_job_id is not null and v_existing.status not in ('draft'::public.mort_job_status,'under_review'::public.mort_job_status,'open'::public.mort_job_status,'paused'::public.mort_job_status) then
    return jsonb_build_object('ok', false, 'code', 'job_cannot_be_edited_in_current_state');
  end if;
  if p_job_id is not null and exists (select 1 from public.job_applications ja where ja.job_id=p_job_id) then
    return jsonb_build_object('ok', false, 'code', 'job_has_applications');
  end if;
  if p_job_id is not null and not p_publish and v_existing.status in ('open'::public.mort_job_status,'paused'::public.mort_job_status) then
    return jsonb_build_object('ok', false, 'code', 'published_job_must_resubmit_for_review');
  end if;

  v_hash := md5(coalesce(p_job_id::text,'new') || '|' || v_payload::text || '|' || p_publish::text);
  select response into v_response from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  if found then
    if (select request_hash from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id) <> v_hash then
      return jsonb_build_object('ok', false, 'code', 'idempotency_key_reused');
    end if;
    if v_response is not null then return v_response || jsonb_build_object('replayed', true); end if;
  else
    insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash)
    values(v_user,p_client_request_id,'save_job',v_hash) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 0 then
      select request_hash,response into v_hash,v_response from private.mort_job_mutation_requests
      where user_id=v_user and client_request_id=p_client_request_id for update;
      if v_response is not null then return v_response || jsonb_build_object('replayed', true); end if;
      return jsonb_build_object('ok', false, 'code', 'job_save_in_progress');
    end if;
  end if;

  v_state := case when p_publish then 'under_review'::public.mort_job_status else 'draft'::public.mort_job_status end;
  perform set_config('mort.job_action', case when p_publish then 'submitted_for_review' else 'saved_draft' end, true);
  insert into public.jobs (
    id,poster_id,title,summary,description,category,status,pay_type,pay_amount,
    estimated_minutes,estimated_duration_minutes,city,region,location_text,location_notes,exact_address,
    age_min,age_max,teen_min_age,teen_max_age,remote_allowed,starts_at,ends_at,safety_review_status,
    published_at,adult_job_amount_cents,pay_amount_cents,schedule_type,payment_type,payment_method,
    payment_timing,verification_requirement,work_environment,location_type,experience_level,
    workers_needed,skills_needed,physical_requirements,equipment_provided,equipment_worker_brings,
    special_instructions,safety_notes,proof_expected,adult_supervision_present,tip_allowed,
    applications_open,deadline_at,expires_at,recurring,recurrence_rule,timezone,urgency,
    neighborhood,zip_code,travel_radius_miles,acceptable_transportation_methods,
    transportation_considerations,requires_guardian_approval,quick_accept_eligible
  ) values (
    coalesce(p_job_id,gen_random_uuid()),v_user,v_title,nullif(btrim(v_payload->>'summary'),''),v_description,
    v_category,v_state,v_payment_type,coalesce(v_amount_cents,0)::numeric/100,
    nullif(v_payload->>'estimated_duration_minutes','')::integer,
    nullif(v_payload->>'estimated_duration_minutes','')::integer,v_city,v_region,
    nullif(btrim(v_payload->>'location_text'),''),null,null,
    v_min_age,v_max_age,v_min_age,v_max_age,false,
    nullif(v_payload->>'starts_at','')::timestamptz,nullif(v_payload->>'ends_at','')::timestamptz,
    'pending',null,v_amount_cents,v_amount_cents,v_schedule,v_payment_type,
    coalesce(nullif(v_payload->>'payment_method',''),'flexible'),
    coalesce(nullif(v_payload->>'payment_timing',''),'after_completion'),
    coalesce(nullif(v_payload->>'verification_requirement',''),'none'),
    coalesce(nullif(v_payload->>'work_environment',''),'unspecified'),
    coalesce(nullif(v_payload->>'location_type',''),'unspecified'),
    coalesce(nullif(v_payload->>'experience_level',''),'any'),
    coalesce(nullif(v_payload->>'workers_needed','')::integer,1),
    case when jsonb_typeof(v_payload->'skills_needed')='array' then array(select jsonb_array_elements_text(v_payload->'skills_needed')) else '{}'::text[] end,
    case when jsonb_typeof(v_payload->'physical_requirements')='array' then array(select jsonb_array_elements_text(v_payload->'physical_requirements')) else '{}'::text[] end,
    nullif(btrim(v_payload->>'equipment_provided'),''),nullif(btrim(v_payload->>'equipment_worker_brings'),''),
    nullif(btrim(v_payload->>'special_instructions'),''),nullif(btrim(v_payload->>'safety_notes'),''),
    coalesce((v_payload->>'proof_expected')::boolean,false),
    coalesce((v_payload->>'adult_supervision_present')::boolean,false),
    coalesce((v_payload->>'tip_allowed')::boolean,false),false,
    nullif(v_payload->>'deadline_at','')::timestamptz,
    nullif(v_payload->>'deadline_at','')::timestamptz,
    coalesce((v_payload->>'recurring')::boolean,false),nullif(btrim(v_payload->>'recurrence_rule'),''),
    coalesce(nullif(v_payload->>'timezone',''),'America/Indiana/Indianapolis'),
    coalesce(nullif(v_payload->>'urgency',''),'normal'),
    nullif(btrim(v_payload->>'neighborhood'),''),nullif(btrim(v_payload->>'zip_code'),''),
    nullif(v_payload->>'travel_radius_miles','')::integer,
    case when jsonb_typeof(v_payload->'acceptable_transportation_methods')='array' then array(select jsonb_array_elements_text(v_payload->'acceptable_transportation_methods')) else array['walking','bicycle','car','public_transit','rideshare','other']::text[] end,
    nullif(btrim(v_payload->>'transportation_considerations'),''),
    coalesce((v_payload->>'requires_guardian_approval')::boolean,false),false
  ) on conflict (id) do update set
    title=excluded.title,summary=excluded.summary,description=excluded.description,category=excluded.category,
    status=excluded.status,pay_type=excluded.pay_type,pay_amount=excluded.pay_amount,
    estimated_minutes=excluded.estimated_minutes,estimated_duration_minutes=excluded.estimated_duration_minutes,
    city=excluded.city,region=excluded.region,location_text=excluded.location_text,location_notes=null,exact_address=null,
    age_min=excluded.age_min,age_max=excluded.age_max,teen_min_age=excluded.teen_min_age,teen_max_age=excluded.teen_max_age,
    remote_allowed=excluded.remote_allowed,starts_at=excluded.starts_at,ends_at=excluded.ends_at,
    safety_review_status='pending',published_at=null,adult_job_amount_cents=excluded.adult_job_amount_cents,
    pay_amount_cents=excluded.pay_amount_cents,schedule_type=excluded.schedule_type,payment_type=excluded.payment_type,
    payment_method=excluded.payment_method,payment_timing=excluded.payment_timing,
    verification_requirement=excluded.verification_requirement,work_environment=excluded.work_environment,
    location_type=excluded.location_type,experience_level=excluded.experience_level,workers_needed=excluded.workers_needed,
    skills_needed=excluded.skills_needed,physical_requirements=excluded.physical_requirements,
    equipment_provided=excluded.equipment_provided,equipment_worker_brings=excluded.equipment_worker_brings,
    special_instructions=excluded.special_instructions,safety_notes=excluded.safety_notes,proof_expected=excluded.proof_expected,
    adult_supervision_present=excluded.adult_supervision_present,tip_allowed=excluded.tip_allowed,
    applications_open=false,deadline_at=excluded.deadline_at,expires_at=excluded.expires_at,
    recurring=excluded.recurring,recurrence_rule=excluded.recurrence_rule,timezone=excluded.timezone,
    urgency=excluded.urgency,neighborhood=excluded.neighborhood,zip_code=excluded.zip_code,
    travel_radius_miles=excluded.travel_radius_miles,acceptable_transportation_methods=excluded.acceptable_transportation_methods,
    transportation_considerations=excluded.transportation_considerations,
    requires_guardian_approval=excluded.requires_guardian_approval,quick_accept_eligible=false
  where public.jobs.poster_id=v_user
  returning * into v_job;
  if not found then
    delete from private.mort_job_mutation_requests where user_id=v_user and client_request_id=p_client_request_id;
    return jsonb_build_object('ok', false, 'code', 'job_not_available');
  end if;

  v_response := jsonb_build_object('ok',true,'job',to_jsonb(v_job)-'exact_address','publication_state',case when p_publish then 'pending_review' else 'draft' end,'replayed',false);
  update private.mort_job_mutation_requests set response=v_response
  where user_id=v_user and client_request_id=p_client_request_id;
  return v_response;
end;
$function$;

create or replace function public.manage_job_v2(
  p_job_id uuid,
  p_action text,
  p_reason text default null,
  p_client_request_id uuid default null,
  p_expected_updated_at timestamptz default null
)
returns jsonb language plpgsql security definer set search_path = '' as $function$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
  v_copy public.jobs%rowtype;
  v_previous_status public.mort_job_status;
  v_response jsonb;
  v_hash text;
  v_action text := coalesce(nullif(p_action,''),'');
  v_inserted integer;
  v_request_exists boolean := false;
  v_public_enabled boolean;
  v_maintenance boolean;
begin
  if v_user is null or not private.is_active_user() or private.current_role() <> 'adult'::public.mort_role then
    return jsonb_build_object('ok',false,'code','active_adult_account_required');
  end if;
  if p_job_id is null or p_client_request_id is null or v_action not in ('pause','resume','cancel','delete_draft','duplicate') then
    return jsonb_build_object('ok',false,'code','job_action_invalid');
  end if;
  select response,request_hash into v_response,v_hash from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  v_request_exists := found;
  if found then
    if v_hash <> md5(p_job_id::text||'|'||v_action||'|'||coalesce(p_reason,'')||'|'||coalesce(p_expected_updated_at::text,'')) then
      return jsonb_build_object('ok',false,'code','idempotency_key_reused');
    end if;
    if v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
  end if;

  select * into v_job from public.jobs where id=p_job_id and poster_id=v_user for update;
  if not found then return jsonb_build_object('ok',false,'code','job_not_available'); end if;
  v_previous_status := v_job.status;
  select response,request_hash into v_response,v_hash from private.mort_job_mutation_requests
  where user_id=v_user and client_request_id=p_client_request_id;
  v_request_exists := found;
  if found and v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
  if p_expected_updated_at is not null and v_job.updated_at<>p_expected_updated_at then
    return jsonb_build_object('ok',false,'code','job_changed_refresh');
  end if;
  if v_action='cancel' and char_length(btrim(coalesce(p_reason,'')))<10 then
    return jsonb_build_object('ok',false,'code','job_cancellation_reason_required');
  end if;
  if v_action='pause' and v_job.status<>'open'::public.mort_job_status then
    return jsonb_build_object('ok',false,'code','job_not_open');
  end if;
  if v_action='cancel' and v_job.status not in ('open'::public.mort_job_status,'paused'::public.mort_job_status,'under_review'::public.mort_job_status) then
    return jsonb_build_object('ok',false,'code','job_not_cancellable');
  end if;
  if v_action='delete_draft' and (v_job.status<>'draft'::public.mort_job_status
      or exists(select 1 from public.job_applications where job_id=v_job.id)
      or exists(select 1 from public.job_assignments where job_id=v_job.id)
      or exists(select 1 from public.conversations where job_id=v_job.id)) then
    return jsonb_build_object('ok',false,'code','job_draft_not_deletable');
  end if;
  if v_action='resume' then
    select public_marketplace_enabled,maintenance_mode into v_public_enabled,v_maintenance from public.mort_release_control where is_primary;
    if not coalesce(v_public_enabled,false) or coalesce(v_maintenance,true) then
      return jsonb_build_object('ok',false,'code','marketplace_unavailable');
    end if;
    if v_job.safety_review_status<>'approved' or v_job.status<>'paused'::public.mort_job_status then
      return jsonb_build_object('ok',false,'code','job_not_resumable');
    end if;
  end if;

  v_hash := md5(p_job_id::text||'|'||v_action||'|'||coalesce(p_reason,'')||'|'||coalesce(p_expected_updated_at::text,''));
  if not v_request_exists then
    insert into private.mort_job_mutation_requests(user_id,client_request_id,operation,request_hash)
    values(v_user,p_client_request_id,'manage_job',v_hash) on conflict do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted=0 then
      select request_hash,response into v_hash,v_response from private.mort_job_mutation_requests
      where user_id=v_user and client_request_id=p_client_request_id for update;
      if v_response is not null then return v_response || jsonb_build_object('replayed',true); end if;
      return jsonb_build_object('ok',false,'code','job_action_in_progress');
    end if;
  end if;

  perform set_config('mort.job_action',v_action,true);
  if v_action='pause' then
    update public.jobs set status='paused'::public.mort_job_status,applications_open=false where id=v_job.id returning * into v_job;
  elsif v_action='resume' then
    update public.jobs set status='open'::public.mort_job_status,applications_open=true where id=v_job.id returning * into v_job;
  elsif v_action='cancel' then
    update public.jobs set status='cancelled'::public.mort_job_status,applications_open=false where id=v_job.id returning * into v_job;
    insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
    values(v_user,'job_cancelled','job',v_job.id::text,nullif(btrim(p_reason),''),jsonb_build_object('previous_status',v_previous_status));
    insert into public.notifications(user_id,notification_type,title,body,data)
    select distinct ja.applicant_id,'job_update','Job cancelled','The job poster cancelled this job.',jsonb_build_object('job_id',v_job.id)
    from public.job_applications ja where ja.job_id=v_job.id and ja.status in ('submitted'::public.mort_application_status,'shortlisted'::public.mort_application_status);
  elsif v_action='duplicate' then
    select (jsonb_populate_record(null::public.jobs,to_jsonb(v_job)||jsonb_build_object(
      'id',gen_random_uuid(),'status','draft','safety_review_status','pending','applications_open',false,
      'published_at',null,'exact_address',null,'location_notes',null,'created_at',now(),'updated_at',now()
    ))).* into v_copy;
    insert into public.jobs select v_copy.* returning * into v_copy;
    v_job := v_copy;
  elsif v_action='delete_draft' then
    insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
    values(v_user,'job_draft_deleted','job',v_job.id::text,null,jsonb_build_object('status',v_job.status));
    delete from public.jobs where id=v_job.id;
    v_response := jsonb_build_object('ok',true,'job',null,'replayed',false);
    update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id;
    return v_response;
  end if;

  v_response := jsonb_build_object('ok',true,'job',to_jsonb(v_job)-'exact_address','replayed',false);
  update private.mort_job_mutation_requests set response=v_response where user_id=v_user and client_request_id=p_client_request_id;
  return v_response;
end;
$function$;

create or replace function public.mort_review_job(
  p_job_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns uuid language plpgsql security definer set search_path = '' as $function$
declare
  v_user uuid := auth.uid();
  v_job public.jobs%rowtype;
begin
  if v_user is null or not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    raise exception 'Authorized moderation role required';
  end if;
  select * into v_job from public.jobs where id=p_job_id for update;
  if not found or v_job.status<>'under_review'::public.mort_job_status
      or v_job.safety_review_status not in ('pending','flagged') then
    raise exception 'Job is not awaiting safety review';
  end if;
  perform set_config('mort.job_action',case when p_approve then 'moderator_approved' else 'moderator_rejected' end,true);
  if p_approve then
    update public.jobs set safety_review_status='approved',
      status='open'::public.mort_job_status,applications_open=true,
      published_at=now(),updated_at=now()
    where id=p_job_id;
  else
    update public.jobs set safety_review_status='rejected',
      status='under_review'::public.mort_job_status,applications_open=false,updated_at=now()
    where id=p_job_id;
  end if;
  insert into public.admin_audit_log(actor_id,action,target_type,target_id,reason,metadata)
  values(v_user,case when p_approve then 'job_approved' else 'job_rejected' end,
    'job',p_job_id::text,nullif(btrim(p_reason),''),
    jsonb_build_object('previous_status',v_job.status,'approved',p_approve));
  return p_job_id;
end;
$function$;

revoke all on function public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean) from public,anon;
grant execute on function public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean) to authenticated;
revoke all on function public.manage_job_v2(uuid,text,text,uuid,timestamptz) from public,anon;
grant execute on function public.manage_job_v2(uuid,text,text,uuid,timestamptz) to authenticated;
revoke all on function public.mort_review_job(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.mort_review_job(uuid,boolean,text) to authenticated;
comment on function public.save_job_draft_or_publish(uuid,uuid,jsonb,boolean) is
  'Saves adult-owned job drafts or submits a complete job for moderator review; publication never bypasses safety approval.';
comment on function public.manage_job_v2(uuid,text,text,uuid,timestamptz) is
  'Performs allowlisted adult-owned job lifecycle actions with concurrency checks and idempotency.';
