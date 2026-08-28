-- Optional Guardian Mode, complete job lifecycle, structured application
-- eligibility, saved jobs, reviews, profile avatars, and test-data isolation.

alter table public.teen_profiles
  alter column guardian_approval_required set default false;

update public.teen_profiles
set guardian_approval_required = false
where guardian_approval_required = true;

alter table public.jobs
  alter column requires_guardian_approval set default false;

update public.jobs
set requires_guardian_approval = false
where requires_guardian_approval = true;

alter table public.profiles
  add column if not exists guardian_setup_status text not null default 'not_started',
  add column if not exists avatar_path text,
  add column if not exists avatar_moderation_status text not null default 'active',
  add column if not exists avatar_updated_at timestamptz,
  add column if not exists bio text,
  add column if not exists availability text,
  add column if not exists preferred_job_categories text[] not null default '{}',
  add column if not exists approximate_area text,
  add column if not exists goals text,
  add column if not exists is_test_account boolean not null default false;

alter table public.profiles
  add constraint profiles_guardian_setup_status_check
    check (guardian_setup_status in ('not_started', 'skipped', 'invite_pending', 'linked')),
  add constraint profiles_avatar_status_check
    check (avatar_moderation_status in ('active', 'pending_review', 'rejected', 'removed')),
  add constraint profiles_bio_length_check
    check (bio is null or char_length(bio) <= 500),
  add constraint profiles_avatar_path_check
    check (avatar_path is null or avatar_path like id::text || '/%');

select set_config('mort.internal_update', 'true', true);

update public.profiles p
set is_test_account = true
from auth.users u
where u.id = p.id
  and (lower(u.email) like '%.rebuild@mort.test' or lower(u.email) like '%@mort.test');

select set_config('mort.internal_update', '', true);

alter table public.guardian_connections
  add column if not exists relationship text,
  add column if not exists invited_email text,
  add column if not exists invite_code_hash bytea,
  add column if not exists invite_expires_at timestamptz,
  add column if not exists accepted_at timestamptz,
  add column if not exists unlinked_at timestamptz,
  add column if not exists canceled_at timestamptz,
  add column if not exists resend_count integer not null default 0,
  add column if not exists last_sent_at timestamptz;

update public.guardian_connections
set invite_code_hash = digest(upper(trim(invite_code)), 'sha256'),
    invite_expires_at = coalesce(invite_expires_at, created_at + interval '14 days'),
    last_sent_at = coalesce(last_sent_at, created_at)
where status = 'invited'
  and invite_code_hash is null;

update public.guardian_connections
set invite_code = upper(substr(encode(gen_random_bytes(16), 'hex'), 1, 24))
where invite_code_hash is not null;

create table public.guardian_preferences (
  link_id uuid primary key references public.guardian_connections(id) on delete cascade,
  safety_ping_alerts boolean not null default true,
  job_checkin_alerts boolean not null default true,
  accepted_job_summary boolean not null default true,
  safety_warning_alerts boolean not null default true,
  weekly_digest boolean not null default false,
  optional_job_approval_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.jurisdiction_guardian_policies (
  id uuid primary key default gen_random_uuid(),
  country_code text not null default 'US',
  region_code text,
  minimum_age integer not null default 13,
  maximum_age integer not null default 17,
  guardian_link_required boolean not null default false,
  guardian_approval_required_for_application boolean not null default false,
  guardian_approval_required_for_job boolean not null default false,
  enabled boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_until timestamptz,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jurisdiction_guardian_policy_country_check check (country_code ~ '^[A-Z]{2}$'),
  constraint jurisdiction_guardian_policy_region_check check (region_code is null or region_code ~ '^[A-Z]{2}$'),
  constraint jurisdiction_guardian_policy_age_check check (
    minimum_age >= 0 and maximum_age >= minimum_age and maximum_age <= 20
  ),
  constraint jurisdiction_guardian_policy_window_check check (
    effective_until is null or effective_until > effective_from
  )
);

create unique index jurisdiction_guardian_policy_scope_idx
on public.jurisdiction_guardian_policies (
  country_code,
  coalesce(region_code, ''),
  effective_from
);

insert into public.jurisdiction_guardian_policies (
  country_code,
  region_code,
  guardian_link_required,
  guardian_approval_required_for_application,
  guardian_approval_required_for_job,
  notes
)
select 'US', null, false, false, false,
       'Default MORT product behavior pending jurisdiction-specific legal review.'
where not exists (
  select 1
  from public.jurisdiction_guardian_policies
  where country_code = 'US' and region_code is null and enabled
);

alter table public.jobs
  add column if not exists summary text,
  add column if not exists estimated_duration_minutes integer,
  add column if not exists workers_needed integer not null default 1,
  add column if not exists experience_level text not null default 'any',
  add column if not exists skills_needed text[] not null default '{}',
  add column if not exists equipment_provided text,
  add column if not exists equipment_worker_brings text,
  add column if not exists physical_requirements text[] not null default '{}',
  add column if not exists proof_expected boolean not null default false,
  add column if not exists special_instructions text,
  add column if not exists schedule_type text not null default 'flexible',
  add column if not exists ends_at timestamptz,
  add column if not exists deadline_at timestamptz,
  add column if not exists recurring boolean not null default false,
  add column if not exists recurrence_rule text,
  add column if not exists timezone text not null default 'America/Indianapolis',
  add column if not exists urgency text not null default 'normal',
  add column if not exists neighborhood text,
  add column if not exists zip_code text,
  add column if not exists travel_radius_miles integer,
  add column if not exists work_environment text not null default 'unspecified',
  add column if not exists location_type text not null default 'unspecified',
  add column if not exists payment_type text not null default 'fixed',
  add column if not exists payment_method text not null default 'flexible',
  add column if not exists payment_timing text not null default 'after_completion',
  add column if not exists tip_allowed boolean not null default false,
  add column if not exists adult_supervision_present boolean not null default false,
  add column if not exists verification_requirement text not null default 'none',
  add column if not exists guardian_requirement_explicit boolean not null default false,
  add column if not exists safety_notes text,
  add column if not exists safety_scan_status text not null default 'clean',
  add column if not exists safety_scan_reasons text[] not null default '{}',
  add column if not exists applications_open boolean not null default true,
  add column if not exists is_test boolean not null default false,
  add column if not exists created_by_qa boolean not null default false,
  add column if not exists environment_tag text not null default 'production',
  add column if not exists client_request_id uuid,
  add column if not exists published_at timestamptz,
  add column if not exists expires_at timestamptz;

alter table public.jobs
  add constraint jobs_summary_length_check check (summary is null or char_length(summary) <= 240),
  add constraint jobs_duration_check check (
    estimated_duration_minutes is null or estimated_duration_minutes between 15 and 1440
  ),
  add constraint jobs_workers_check check (workers_needed between 1 and 10),
  add constraint jobs_experience_check check (experience_level in ('any', 'beginner', 'some', 'experienced')),
  add constraint jobs_schedule_type_check check (schedule_type in ('flexible', 'exact')),
  add constraint jobs_schedule_window_check check (ends_at is null or starts_at is null or ends_at > starts_at),
  add constraint jobs_deadline_check check (deadline_at is null or deadline_at > created_at),
  add constraint jobs_urgency_check check (urgency in ('low', 'normal', 'soon')),
  add constraint jobs_travel_radius_check check (travel_radius_miles is null or travel_radius_miles between 0 and 100),
  add constraint jobs_environment_check check (work_environment in ('indoor', 'outdoor', 'both', 'unspecified')),
  add constraint jobs_location_type_check check (location_type in ('public', 'private_residence', 'business', 'unspecified')),
  add constraint jobs_payment_type_check check (payment_type in ('fixed', 'hourly')),
  add constraint jobs_payment_method_check check (payment_method in ('cash', 'cash_app', 'square', 'flexible')),
  add constraint jobs_payment_timing_check check (payment_timing in ('after_completion', 'same_day', 'agreed_later')),
  add constraint jobs_verification_requirement_check check (verification_requirement in ('none', 'preferred', 'required')),
  add constraint jobs_safety_scan_check check (safety_scan_status in ('clean', 'flagged', 'blocked')),
  add constraint jobs_expiry_check check (expires_at is null or expires_at > created_at);

create unique index jobs_poster_client_request_idx
on public.jobs(poster_id, client_request_id)
where client_request_id is not null;

create index jobs_feed_filter_idx
on public.jobs(status, is_test, category, created_at desc);

update public.jobs
set is_test = true,
    created_by_qa = true,
    environment_tag = 'qa'
where title ~* '(^|[^a-z])(qa|test|rebuild)([^a-z]|$)';

create table public.saved_jobs (
  user_id uuid not null references public.profiles(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);

create index saved_jobs_user_created_idx
on public.saved_jobs(user_id, created_at desc);

create table public.job_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  source_job_id uuid references public.jobs(id) on delete set null,
  name text not null,
  template_data jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_templates_name_check check (char_length(btrim(name)) between 3 and 80)
);

create table public.job_status_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  from_status public.job_status,
  to_status public.job_status not null,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index job_status_events_job_idx
on public.job_status_events(job_id, created_at);

create table public.application_status_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  from_status public.application_status,
  to_status public.application_status not null,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index application_status_events_application_idx
on public.application_status_events(application_id, created_at);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  subject_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null,
  body text,
  moderation_status text not null default 'approved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(job_id, reviewer_id),
  constraint reviews_rating_check check (rating between 1 and 5),
  constraint reviews_body_check check (body is null or char_length(body) <= 500),
  constraint reviews_participants_check check (reviewer_id <> subject_id),
  constraint reviews_moderation_check check (moderation_status in ('approved', 'pending_review', 'rejected', 'removed'))
);

create trigger guardian_preferences_set_updated_at
before update on public.guardian_preferences
for each row execute function public.set_updated_at();

create trigger jurisdiction_guardian_policies_set_updated_at
before update on public.jurisdiction_guardian_policies
for each row execute function public.set_updated_at();

create trigger job_templates_set_updated_at
before update on public.job_templates
for each row execute function public.set_updated_at();

create trigger reviews_set_updated_at
before update on public.reviews
for each row execute function public.set_updated_at();

alter table public.guardian_preferences enable row level security;
alter table public.jurisdiction_guardian_policies enable row level security;
alter table public.saved_jobs enable row level security;
alter table public.job_templates enable row level security;
alter table public.job_status_events enable row level security;
alter table public.application_status_events enable row level security;
alter table public.reviews enable row level security;

create policy guardian_preferences_select_participants
on public.guardian_preferences for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections gc
    where gc.id = link_id
      and gc.status = 'active'
      and auth.uid() in (gc.teen_id, gc.guardian_id)
  )
);

create policy guardian_preferences_update_teen
on public.guardian_preferences for update to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections gc
    where gc.id = link_id and gc.teen_id = auth.uid() and gc.status = 'active'
  )
)
with check (
  public.is_admin()
  or exists (
    select 1 from public.guardian_connections gc
    where gc.id = link_id and gc.teen_id = auth.uid() and gc.status = 'active'
  )
);

create policy jurisdiction_guardian_policies_select
on public.jurisdiction_guardian_policies for select to authenticated
using (enabled or public.is_admin());

create policy jurisdiction_guardian_policies_admin_write
on public.jurisdiction_guardian_policies for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy saved_jobs_select_own
on public.saved_jobs for select to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy saved_jobs_insert_own
on public.saved_jobs for insert to authenticated
with check (
  user_id = auth.uid()
  and public.current_profile_role() = 'teen'
  and exists (
    select 1 from public.jobs j
    where j.id = job_id and j.status = 'open' and not j.is_test
  )
);

create policy saved_jobs_delete_own
on public.saved_jobs for delete to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy job_templates_owner
on public.job_templates for all to authenticated
using (owner_id = auth.uid() or public.is_admin())
with check (owner_id = auth.uid() or public.is_admin());

create policy job_status_events_participant_select
on public.job_status_events for select to authenticated
using (
  public.is_admin()
  or exists (
    select 1 from public.jobs j
    where j.id = job_id
      and (
        j.poster_id = auth.uid()
        or exists (
          select 1 from public.applications a
          where a.job_id = j.id and a.teen_id = auth.uid()
        )
      )
  )
);

create policy application_status_events_participant_select
on public.application_status_events for select to authenticated
using (public.is_admin() or public.is_application_participant(application_id));

create policy reviews_select_visible
on public.reviews for select to authenticated
using (
  moderation_status = 'approved'
  or reviewer_id = auth.uid()
  or subject_id = auth.uid()
  or public.is_admin()
);

create policy reviews_insert_participant
on public.reviews for insert to authenticated
with check (
  reviewer_id = auth.uid()
  and exists (
    select 1
    from public.jobs j
    join public.applications a on a.job_id = j.id and a.status = 'completed'
    where j.id = job_id
      and j.status = 'completed'
      and (
        (reviewer_id = j.poster_id and subject_id = a.teen_id)
        or (reviewer_id = a.teen_id and subject_id = j.poster_id)
      )
  )
);

create policy reviews_admin_moderate
on public.reviews for update to authenticated
using (public.is_admin()) with check (public.is_admin());

alter table public.applications
  add column if not exists availability_confirmed boolean not null default false,
  add column if not exists portfolio_ids uuid[] not null default '{}',
  add column if not exists submitted_at timestamptz not null default now(),
  add column if not exists viewed_at timestamptz,
  add column if not exists withdrawn_at timestamptz;

alter table public.applications
  add constraint applications_note_length_check
    check (note is null or char_length(note) <= 500);

create or replace function public.get_guardian_policy_for_user(p_user_id uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy public.jurisdiction_guardian_policies%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  if p_user_id <> auth.uid() and not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  select * into v_profile from public.profiles where id = p_user_id;

  select * into v_policy
  from public.jurisdiction_guardian_policies
  where enabled
    and country_code = 'US'
    and (region_code = v_profile.state or region_code is null)
    and effective_from <= now()
    and (effective_until is null or effective_until > now())
  order by (region_code is not null) desc, effective_from desc
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'country_code', 'US',
    'region_code', v_profile.state,
    'guardian_link_required', coalesce(v_policy.guardian_link_required, false),
    'guardian_approval_required_for_application', coalesce(v_policy.guardian_approval_required_for_application, false),
    'guardian_approval_required_for_job', coalesce(v_policy.guardian_approval_required_for_job, false),
    'source', case when v_policy.id is null then 'product_default' else 'jurisdiction_policy' end
  );
end;
$$;

create or replace function public.ensure_guardian_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'active' then
    insert into public.guardian_preferences (link_id)
    values (new.id)
    on conflict (link_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger guardian_connections_ensure_preferences
after insert or update of status on public.guardian_connections
for each row execute function public.ensure_guardian_preferences();

insert into public.guardian_preferences (link_id)
select id from public.guardian_connections where status = 'active'
on conflict (link_id) do nothing;

create or replace function public.create_guardian_invite_v2(p_invite_email text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_link_id uuid;
  v_expires_at timestamptz := now() + interval '14 days';
  v_email text := nullif(lower(btrim(coalesce(p_invite_email, ''))), '');
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if public.current_profile_role() <> 'teen' or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if v_email is not null and v_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_invite_email');
  end if;
  if not public.check_rate_limit('guardian_invite', 5, 86400) then
    return jsonb_build_object('ok', false, 'code', 'application_limit_reached');
  end if;
  if (
    select count(*) from public.guardian_connections
    where teen_id = auth.uid() and status = 'invited' and invite_expires_at > now()
  ) >= 3 then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_limit_reached');
  end if;

  v_code := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
  insert into public.guardian_connections (
    teen_id,
    status,
    invite_code,
    invite_code_hash,
    invited_email,
    invite_expires_at,
    last_sent_at
  ) values (
    auth.uid(),
    'invited',
    upper(substr(encode(gen_random_bytes(16), 'hex'), 1, 24)),
    digest(v_code, 'sha256'),
    v_email,
    v_expires_at,
    now()
  ) returning id into v_link_id;

  update public.profiles
  set guardian_setup_status = 'invite_pending'
  where id = auth.uid();

  perform public.record_rate_limit_event('guardian_invite');
  return jsonb_build_object(
    'ok', true,
    'link_id', v_link_id,
    'invite_code', v_code,
    'expires_at', v_expires_at,
    'delivery', case when v_email is null then 'copy_code' else 'email_delivery_external_setup_required' end
  );
end;
$$;

create or replace function public.create_guardian_invite()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  v_result := public.create_guardian_invite_v2(null);
  if coalesce((v_result->>'ok')::boolean, false) is not true then
    raise exception '%', coalesce(v_result->>'code', 'guardian_invite_failed');
  end if;
  return v_result->>'invite_code';
end;
$$;

create or replace function public.accept_guardian_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_connection public.guardian_connections%rowtype;
  v_email text := lower(coalesce(auth.jwt()->>'email', ''));
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if public.current_profile_role() <> 'guardian' or not public.is_profile_active(auth.uid()) then
    raise exception 'user_role_not_allowed';
  end if;

  update public.guardian_connections
  set guardian_id = auth.uid(),
      status = 'active',
      accepted_at = now(),
      updated_at = now()
  where invite_code_hash = digest(upper(trim(p_invite_code)), 'sha256')
    and status = 'invited'
    and guardian_id is null
    and invite_expires_at > now()
    and (invited_email is null or lower(invited_email) = v_email)
  returning * into v_connection;

  if v_connection.id is null then
    raise exception 'guardian_invite_invalid_or_expired';
  end if;

  update public.profiles set guardian_setup_status = 'linked' where id = v_connection.teen_id;
  perform public.enqueue_notification(
    v_connection.teen_id,
    'Guardian linked',
    'Guardian Mode is now linked. You remain in control of shared alerts.',
    jsonb_build_object('linkId', v_connection.id)
  );
  return v_connection.id;
end;
$$;

create or replace function public.cancel_guardian_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated uuid;
begin
  update public.guardian_connections
  set status = 'canceled', canceled_at = now(), updated_at = now()
  where id = p_link_id and teen_id = auth.uid() and status = 'invited'
  returning id into v_updated;
  if v_updated is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_not_found');
  end if;
  if not exists (
    select 1 from public.guardian_connections
    where teen_id = auth.uid() and status in ('invited', 'active')
  ) then
    update public.profiles set guardian_setup_status = 'skipped' where id = auth.uid();
  end if;
  return jsonb_build_object('ok', true, 'link_id', v_updated);
end;
$$;

create or replace function public.resend_guardian_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 8));
  v_updated uuid;
  v_expires_at timestamptz := now() + interval '14 days';
begin
  if not public.check_rate_limit('guardian_invite', 5, 86400) then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_limit_reached');
  end if;
  update public.guardian_connections
  set invite_code_hash = digest(v_code, 'sha256'),
      invite_expires_at = v_expires_at,
      resend_count = resend_count + 1,
      last_sent_at = now(),
      updated_at = now()
  where id = p_link_id and teen_id = auth.uid() and status = 'invited'
  returning id into v_updated;
  if v_updated is null then
    return jsonb_build_object('ok', false, 'code', 'guardian_invite_not_found');
  end if;
  perform public.record_rate_limit_event('guardian_invite');
  return jsonb_build_object('ok', true, 'link_id', v_updated, 'invite_code', v_code, 'expires_at', v_expires_at);
end;
$$;

create or replace function public.unlink_guardian(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.guardian_connections%rowtype;
  v_other uuid;
begin
  select * into v_link from public.guardian_connections where id = p_link_id;
  if v_link.id is null
     or auth.uid() not in (v_link.teen_id, v_link.guardian_id)
     or v_link.status <> 'active' then
    return jsonb_build_object('ok', false, 'code', 'guardian_link_not_found');
  end if;
  update public.guardian_connections
  set status = 'revoked', unlinked_at = now(), updated_at = now()
  where id = p_link_id;
  update public.profiles set guardian_setup_status = 'skipped' where id = v_link.teen_id;
  v_other := case when auth.uid() = v_link.teen_id then v_link.guardian_id else v_link.teen_id end;
  if v_other is not null then
    perform public.enqueue_notification(
      v_other,
      'Guardian Mode unlinked',
      'This Guardian Mode connection was unlinked. The teen account and safety tools remain available.',
      jsonb_build_object('linkId', p_link_id)
    );
  end if;
  return jsonb_build_object('ok', true, 'link_id', p_link_id);
end;
$$;

create or replace function public.set_guardian_setup_skipped()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_profile_role() <> 'teen' then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  update public.profiles set guardian_setup_status = 'skipped' where id = auth.uid();
  return jsonb_build_object('ok', true, 'guardian_setup_status', 'skipped');
end;
$$;

drop policy if exists guardian_connections_select on public.guardian_connections;
create policy guardian_connections_select
on public.guardian_connections for select to authenticated
using (
  teen_id = auth.uid()
  or guardian_id = auth.uid()
  or (
    status = 'invited'
    and invited_email is not null
    and lower(invited_email) = lower(coalesce(auth.jwt()->>'email', ''))
  )
  or public.is_admin()
);

drop policy if exists guardian_connections_insert_teen on public.guardian_connections;
create policy guardian_connections_insert_admin_only
on public.guardian_connections for insert to authenticated
with check (public.is_admin());

drop policy if exists guardian_connections_update_guardian_or_admin on public.guardian_connections;
create policy guardian_connections_update_admin_only
on public.guardian_connections for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create or replace function public.log_job_status_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or old.status is distinct from new.status then
    insert into public.job_status_events (job_id, from_status, to_status, actor_id)
    values (
      new.id,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create trigger jobs_log_status_event
after insert or update of status on public.jobs
for each row execute function public.log_job_status_event();

create or replace function public.log_application_status_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or old.status is distinct from new.status then
    insert into public.application_status_events (
      application_id,
      from_status,
      to_status,
      actor_id
    ) values (
      new.id,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create trigger applications_log_status_event
after insert or update of status on public.applications
for each row execute function public.log_application_status_event();

create or replace function public.save_job_draft_or_publish(
  p_job_id uuid,
  p_client_request_id uuid,
  p_payload jsonb,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_title text := btrim(coalesce(p_payload->>'title', ''));
  v_summary text := btrim(coalesce(p_payload->>'summary', ''));
  v_description text := btrim(coalesce(p_payload->>'description', ''));
  v_category text := lower(btrim(coalesce(p_payload->>'category', '')));
  v_area text := btrim(coalesce(p_payload->>'location_text', ''));
  v_city text := btrim(coalesce(p_payload->>'city', ''));
  v_state text := upper(btrim(coalesce(p_payload->>'state', '')));
  v_schedule_type text := lower(coalesce(nullif(p_payload->>'schedule_type', ''), 'flexible'));
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_deadline_at timestamptz;
  v_expires_at timestamptz;
  v_pay integer;
  v_guardian_explicit boolean := coalesce((p_payload->>'requires_guardian_approval')::boolean, false);
  v_guardian_policy boolean := false;
  v_is_new boolean := false;
  v_was_published boolean := false;
  v_content text;
  v_blocked_terms text[] := '{}';
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role not in ('adult', 'admin') then
    return jsonb_build_object('ok', false, 'code', 'user_role_not_allowed');
  end if;
  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if p_job_id is null and p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_client_request');
  end if;

  begin
    v_starts_at := nullif(p_payload->>'starts_at', '')::timestamptz;
    v_ends_at := nullif(p_payload->>'ends_at', '')::timestamptz;
    v_deadline_at := nullif(p_payload->>'deadline_at', '')::timestamptz;
    v_expires_at := nullif(p_payload->>'expires_at', '')::timestamptz;
    v_pay := nullif(p_payload->>'pay_amount_cents', '')::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_values');
  end;

  if p_job_id is not null then
    select * into v_job from public.jobs where id = p_job_id;
    if v_job.id is null then
      return jsonb_build_object('ok', false, 'code', 'job_not_found');
    end if;
    if v_job.poster_id <> auth.uid() and not public.is_admin() then
      return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
    end if;
    if v_job.status not in ('draft', 'open', 'paused') then
      return jsonb_build_object('ok', false, 'code', 'job_not_editable');
    end if;
    v_was_published := v_job.published_at is not null;
  elsif p_client_request_id is not null then
    select * into v_job
    from public.jobs
    where poster_id = auth.uid() and client_request_id = p_client_request_id;
  end if;

  if p_publish then
    if v_profile.verification_status <> 'approved' and not public.is_admin() then
      return jsonb_build_object('ok', false, 'code', 'poster_verification_required');
    end if;
    if char_length(v_title) not between 5 and 80 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_title');
    end if;
    if char_length(v_summary) not between 10 and 240 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_summary');
    end if;
    if char_length(v_description) not between 20 and 4000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_description');
    end if;
    if v_category not in (
      'cleaning', 'lawn care', 'dog walking', 'pet care', 'snow removal',
      'trash and recycling', 'moving/light lifting', 'tutoring',
      'technology help', 'organization', 'errands', 'event setup',
      'car washing', 'painting/light maintenance',
      'delivery where legally appropriate', 'other safe local work'
    ) then
      return jsonb_build_object('ok', false, 'code', 'unsafe_job_category');
    end if;
    if v_city = '' or v_state !~ '^[A-Z]{2}$' or v_area = '' then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_location');
    end if;
    if v_pay is null or v_pay <= 0 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
    end if;
    if v_schedule_type = 'exact' and v_starts_at is null then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_schedule');
    end if;
    if v_starts_at is not null and v_starts_at <= now() then
      return jsonb_build_object('ok', false, 'code', 'job_start_time_passed');
    end if;
    if v_ends_at is not null and (v_starts_at is null or v_ends_at <= v_starts_at) then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_schedule');
    end if;
    if v_deadline_at is not null and v_deadline_at <= now() then
      return jsonb_build_object('ok', false, 'code', 'job_expired');
    end if;

    v_content := lower(v_title || ' ' || v_summary || ' ' || v_description || ' ' || coalesce(p_payload->>'special_instructions', ''));
    if v_content ~ '(roof|firearm|\mgun\M|hazardous chemical|adult entertainment|gift card|cryptocurrency|crypto payment|illegal activity|overnight work|alcohol handling|drug handling)' then
      v_blocked_terms := array['prohibited_or_high_risk_work'];
    end if;
    if v_content ~* '([a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}|\+?[0-9][0-9() .\-]{8,}[0-9]|@[a-z0-9_]{2,}|\$[a-z][a-z0-9_]*)' then
      v_blocked_terms := array_append(v_blocked_terms, 'private_contact_or_payment_handle');
    end if;
    if cardinality(v_blocked_terms) > 0 then
      insert into public.ai_moderation_events (
        user_id, resource_type, resource_id, content, detected_flags,
        fallback_used, status
      ) values (
        auth.uid(), 'job_draft', coalesce(v_job.id::text, p_client_request_id::text),
        left(v_content, 4000), v_blocked_terms, true, 'blocked'
      );
      return jsonb_build_object('ok', false, 'code', 'unsafe_job_content', 'reasons', v_blocked_terms);
    end if;

    if not v_was_published and not public.is_action_allowed('job_post_create') then
      return jsonb_build_object('ok', false, 'code', 'application_limit_reached');
    end if;

    select coalesce(jgp.guardian_approval_required_for_job, false)
    into v_guardian_policy
    from public.jurisdiction_guardian_policies jgp
    where jgp.enabled
      and jgp.country_code = 'US'
      and (jgp.region_code = v_state or jgp.region_code is null)
      and jgp.effective_from <= now()
      and (jgp.effective_until is null or jgp.effective_until > now())
    order by (jgp.region_code is not null) desc, jgp.effective_from desc
    limit 1;
  end if;

  if v_job.id is null then
    v_is_new := true;
    insert into public.jobs (
      poster_id, title, summary, description, category, location_text, city, state,
      pay_amount_cents, pay_label, teen_min_age, teen_max_age,
      requires_guardian_approval, guardian_requirement_explicit, status,
      estimated_duration_minutes, workers_needed, experience_level, skills_needed,
      equipment_provided, equipment_worker_brings, physical_requirements,
      proof_expected, special_instructions, schedule_type, starts_at, ends_at,
      deadline_at, recurring, recurrence_rule, timezone, urgency, neighborhood,
      zip_code, travel_radius_miles, work_environment, location_type, payment_type,
      payment_method, payment_timing, tip_allowed, adult_supervision_present,
      verification_requirement, safety_notes, safety_scan_status,
      safety_scan_reasons, applications_open, is_test, created_by_qa,
      environment_tag, client_request_id, published_at, expires_at
    ) values (
      auth.uid(), coalesce(nullif(v_title, ''), 'Untitled draft'),
      nullif(v_summary, ''), coalesce(nullif(v_description, ''), 'Draft details not completed.'),
      coalesce(nullif(v_category, ''), 'other safe local work'),
      coalesce(nullif(v_area, ''), 'General area'),
      coalesce(nullif(v_city, ''), coalesce(v_profile.city, 'Draft city')),
      case when v_state ~ '^[A-Z]{2}$' then v_state else coalesce(v_profile.state, 'IN') end,
      v_pay, p_payload->>'pay_label',
      coalesce((p_payload->>'teen_min_age')::integer, 13),
      coalesce((p_payload->>'teen_max_age')::integer, 17),
      case when p_publish then v_guardian_explicit or v_guardian_policy else v_guardian_explicit end,
      v_guardian_explicit,
      case when p_publish then 'open'::public.job_status else 'draft'::public.job_status end,
      nullif(p_payload->>'estimated_duration_minutes', '')::integer,
      coalesce((p_payload->>'workers_needed')::integer, 1),
      coalesce(nullif(p_payload->>'experience_level', ''), 'any'),
      array(select jsonb_array_elements_text(coalesce(p_payload->'skills_needed', '[]'::jsonb))),
      nullif(p_payload->>'equipment_provided', ''),
      nullif(p_payload->>'equipment_worker_brings', ''),
      array(select jsonb_array_elements_text(coalesce(p_payload->'physical_requirements', '[]'::jsonb))),
      coalesce((p_payload->>'proof_expected')::boolean, false),
      nullif(p_payload->>'special_instructions', ''), v_schedule_type,
      v_starts_at, v_ends_at, v_deadline_at,
      coalesce((p_payload->>'recurring')::boolean, false),
      nullif(p_payload->>'recurrence_rule', ''),
      coalesce(nullif(p_payload->>'timezone', ''), 'America/Indianapolis'),
      coalesce(nullif(p_payload->>'urgency', ''), 'normal'),
      nullif(p_payload->>'neighborhood', ''), nullif(p_payload->>'zip_code', ''),
      nullif(p_payload->>'travel_radius_miles', '')::integer,
      coalesce(nullif(p_payload->>'work_environment', ''), 'unspecified'),
      coalesce(nullif(p_payload->>'location_type', ''), 'unspecified'),
      coalesce(nullif(p_payload->>'payment_type', ''), 'fixed'),
      coalesce(nullif(p_payload->>'payment_method', ''), 'flexible'),
      coalesce(nullif(p_payload->>'payment_timing', ''), 'after_completion'),
      coalesce((p_payload->>'tip_allowed')::boolean, false),
      coalesce((p_payload->>'adult_supervision_present')::boolean, false),
      coalesce(nullif(p_payload->>'verification_requirement', ''), 'none'),
      nullif(p_payload->>'safety_notes', ''), 'clean', '{}', p_publish,
      v_profile.is_test_account, v_profile.is_test_account,
      case when v_profile.is_test_account then 'qa' else 'production' end,
      p_client_request_id,
      case when p_publish then now() else null end,
      v_expires_at
    ) returning * into v_job;
  else
    update public.jobs
    set title = coalesce(nullif(v_title, ''), title),
        summary = nullif(v_summary, ''),
        description = coalesce(nullif(v_description, ''), description),
        category = coalesce(nullif(v_category, ''), category),
        location_text = coalesce(nullif(v_area, ''), location_text),
        city = coalesce(nullif(v_city, ''), city),
        state = case when v_state ~ '^[A-Z]{2}$' then v_state else state end,
        pay_amount_cents = v_pay,
        pay_label = nullif(p_payload->>'pay_label', ''),
        teen_min_age = coalesce((p_payload->>'teen_min_age')::integer, teen_min_age),
        teen_max_age = coalesce((p_payload->>'teen_max_age')::integer, teen_max_age),
        requires_guardian_approval = case when p_publish then v_guardian_explicit or v_guardian_policy else v_guardian_explicit end,
        guardian_requirement_explicit = v_guardian_explicit,
        status = case when p_publish then 'open'::public.job_status else status end,
        estimated_duration_minutes = nullif(p_payload->>'estimated_duration_minutes', '')::integer,
        workers_needed = coalesce((p_payload->>'workers_needed')::integer, workers_needed),
        experience_level = coalesce(nullif(p_payload->>'experience_level', ''), experience_level),
        skills_needed = array(select jsonb_array_elements_text(coalesce(p_payload->'skills_needed', '[]'::jsonb))),
        equipment_provided = nullif(p_payload->>'equipment_provided', ''),
        equipment_worker_brings = nullif(p_payload->>'equipment_worker_brings', ''),
        physical_requirements = array(select jsonb_array_elements_text(coalesce(p_payload->'physical_requirements', '[]'::jsonb))),
        proof_expected = coalesce((p_payload->>'proof_expected')::boolean, proof_expected),
        special_instructions = nullif(p_payload->>'special_instructions', ''),
        schedule_type = v_schedule_type, starts_at = v_starts_at, ends_at = v_ends_at,
        deadline_at = v_deadline_at,
        recurring = coalesce((p_payload->>'recurring')::boolean, recurring),
        recurrence_rule = nullif(p_payload->>'recurrence_rule', ''),
        timezone = coalesce(nullif(p_payload->>'timezone', ''), timezone),
        urgency = coalesce(nullif(p_payload->>'urgency', ''), urgency),
        neighborhood = nullif(p_payload->>'neighborhood', ''),
        zip_code = nullif(p_payload->>'zip_code', ''),
        travel_radius_miles = nullif(p_payload->>'travel_radius_miles', '')::integer,
        work_environment = coalesce(nullif(p_payload->>'work_environment', ''), work_environment),
        location_type = coalesce(nullif(p_payload->>'location_type', ''), location_type),
        payment_type = coalesce(nullif(p_payload->>'payment_type', ''), payment_type),
        payment_method = coalesce(nullif(p_payload->>'payment_method', ''), payment_method),
        payment_timing = coalesce(nullif(p_payload->>'payment_timing', ''), payment_timing),
        tip_allowed = coalesce((p_payload->>'tip_allowed')::boolean, tip_allowed),
        adult_supervision_present = coalesce((p_payload->>'adult_supervision_present')::boolean, adult_supervision_present),
        verification_requirement = coalesce(nullif(p_payload->>'verification_requirement', ''), verification_requirement),
        safety_notes = nullif(p_payload->>'safety_notes', ''),
        safety_scan_status = 'clean', safety_scan_reasons = '{}',
        applications_open = case when p_publish then true else applications_open end,
        published_at = case when p_publish then coalesce(published_at, now()) else published_at end,
        expires_at = v_expires_at,
        updated_at = now()
    where id = v_job.id
    returning * into v_job;
  end if;

  if p_publish and not v_was_published then
    perform public.record_rate_limit_event('job_post_create');
  end if;

  return jsonb_build_object(
    'ok', true,
    'created', v_is_new,
    'published', p_publish,
    'job', to_jsonb(v_job)
  );
exception when unique_violation then
  select * into v_job
  from public.jobs
  where poster_id = auth.uid() and client_request_id = p_client_request_id;
  return jsonb_build_object('ok', true, 'created', false, 'published', v_job.status = 'open', 'job', to_jsonb(v_job));
end;
$$;

create or replace function public.manage_job(p_job_id uuid, p_action text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job public.jobs%rowtype;
  v_copy public.jobs%rowtype;
  v_action text := lower(btrim(p_action));
begin
  select * into v_job from public.jobs where id = p_job_id;
  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'job_not_found');
  end if;
  if v_job.poster_id <> auth.uid() and not public.is_admin() then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  if v_action = 'pause' and v_job.status = 'open' then
    update public.jobs set status = 'paused', applications_open = false where id = p_job_id returning * into v_job;
  elsif v_action = 'resume' and v_job.status = 'paused' then
    update public.jobs set status = 'open', applications_open = true where id = p_job_id returning * into v_job;
  elsif v_action = 'close_applications' and v_job.status = 'open' then
    update public.jobs set applications_open = false where id = p_job_id returning * into v_job;
  elsif v_action = 'cancel' and v_job.status in ('open', 'paused', 'assigned', 'in_progress') then
    update public.jobs set status = 'canceled', applications_open = false where id = p_job_id returning * into v_job;
  elsif v_action = 'delete_draft' and v_job.status = 'draft' then
    delete from public.jobs where id = p_job_id;
    return jsonb_build_object('ok', true, 'deleted', true, 'job_id', p_job_id);
  elsif v_action = 'duplicate' then
    insert into public.jobs (
      poster_id, title, summary, description, category, location_text, city, state,
      pay_amount_cents, pay_label, teen_min_age, teen_max_age,
      requires_guardian_approval, guardian_requirement_explicit, status,
      estimated_duration_minutes, workers_needed, experience_level, skills_needed,
      equipment_provided, equipment_worker_brings, physical_requirements,
      proof_expected, special_instructions, schedule_type, recurring,
      timezone, urgency, neighborhood, zip_code, travel_radius_miles,
      work_environment, location_type, payment_type, payment_method,
      payment_timing, tip_allowed, adult_supervision_present,
      verification_requirement, safety_notes, is_test, created_by_qa,
      environment_tag, client_request_id
    ) select
      poster_id, left(title || ' copy', 80), summary, description, category,
      location_text, city, state, pay_amount_cents, pay_label, teen_min_age,
      teen_max_age, false, false, 'draft', estimated_duration_minutes,
      workers_needed, experience_level, skills_needed, equipment_provided,
      equipment_worker_brings, physical_requirements, proof_expected,
      special_instructions, 'flexible', false, timezone, 'normal', neighborhood,
      zip_code, travel_radius_miles, work_environment, location_type,
      payment_type, payment_method, payment_timing, tip_allowed,
      adult_supervision_present, verification_requirement, safety_notes,
      is_test, created_by_qa, environment_tag, gen_random_uuid()
    from public.jobs where id = p_job_id
    returning * into v_copy;
    return jsonb_build_object('ok', true, 'job', to_jsonb(v_copy));
  else
    return jsonb_build_object('ok', false, 'code', 'invalid_job_transition');
  end if;

  return jsonb_build_object('ok', true, 'job', to_jsonb(v_job));
end;
$$;

drop policy if exists jobs_select_visible on public.jobs;
create policy jobs_select_visible
on public.jobs for select to authenticated
using (
  (
    status = 'open'
    and (not is_test or poster_id = auth.uid() or public.is_admin())
  )
  or poster_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.applications a
    where a.job_id = jobs.id and public.is_application_participant(a.id)
  )
);

drop policy if exists jobs_insert_verified_adult on public.jobs;
create policy jobs_insert_admin_only
on public.jobs for insert to authenticated
with check (public.is_admin());

drop policy if exists jobs_update_poster_or_admin on public.jobs;
create policy jobs_update_admin_only
on public.jobs for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy jobs_delete_admin_only
on public.jobs for delete to authenticated
using (public.is_admin());

alter function public.is_application_participant(uuid) volatile;

create or replace function public.get_job_application_eligibility(p_job_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_profile public.profiles%rowtype;
  v_poster public.profiles%rowtype;
  v_job public.jobs%rowtype;
  v_age integer;
  v_guardian_id uuid;
  v_policy jsonb;
  v_guardian_required boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible', false, 'code', 'authentication_required', 'message', 'Sign in before applying.');
  end if;

  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.role <> 'teen' then
    return jsonb_build_object('eligible', false, 'code', 'user_role_not_allowed', 'message', 'Only teen accounts can apply for jobs.');
  end if;
  if not public.is_profile_active(auth.uid()) or public.teen_is_paused(auth.uid()) then
    return jsonb_build_object('eligible', false, 'code', 'user_account_restricted', 'message', 'Your account is currently restricted. Check your account status or contact support.');
  end if;

  select * into v_job from public.jobs where id = p_job_id;
  if v_job.id is null then
    return jsonb_build_object('eligible', false, 'code', 'job_not_open', 'message', 'This job is no longer accepting applications.');
  end if;
  if v_job.is_test and not v_profile.is_test_account then
    return jsonb_build_object('eligible', false, 'code', 'job_not_open', 'message', 'This job is not available in the production feed.');
  end if;
  if v_job.poster_id = auth.uid() then
    return jsonb_build_object('eligible', false, 'code', 'applicant_is_job_owner', 'message', 'You cannot apply to your own job.');
  end if;
  if v_job.status in ('assigned', 'in_progress', 'proof_submitted') then
    return jsonb_build_object('eligible', false, 'code', 'job_already_assigned', 'message', 'This job has already been assigned.');
  end if;
  if v_job.status <> 'open' or not v_job.applications_open then
    return jsonb_build_object('eligible', false, 'code', 'job_not_open', 'message', 'This job is no longer accepting applications.');
  end if;
  if v_job.expires_at is not null and v_job.expires_at <= now() then
    return jsonb_build_object('eligible', false, 'code', 'job_expired', 'message', 'This job has expired.');
  end if;
  if v_job.schedule_type = 'exact' and v_job.starts_at is not null and v_job.starts_at <= now() then
    return jsonb_build_object('eligible', false, 'code', 'job_start_time_passed', 'message', 'The start time for this job has already passed.');
  end if;

  select * into v_poster from public.profiles where id = v_job.poster_id;
  if v_poster.verification_status <> 'approved' then
    return jsonb_build_object('eligible', false, 'code', 'poster_verification_required', 'message', 'This job is not accepting applications until the poster finishes verification.');
  end if;

  if exists (
    select 1 from public.applications
    where job_id = p_job_id and teen_id = auth.uid()
  ) then
    return jsonb_build_object('eligible', false, 'code', 'application_already_exists', 'message', 'You already applied to this job.');
  end if;

  if v_profile.dob is null then
    return jsonb_build_object('eligible', false, 'code', 'applicant_age_not_allowed', 'message', 'Complete your date of birth before applying.');
  end if;
  v_age := date_part('year', age(current_date, v_profile.dob));
  if v_age < v_job.teen_min_age or v_age > v_job.teen_max_age then
    return jsonb_build_object('eligible', false, 'code', 'applicant_age_not_allowed', 'message', 'Your age does not match this job range.');
  end if;
  if v_job.verification_requirement = 'required' and v_profile.verification_status <> 'approved' then
    return jsonb_build_object('eligible', false, 'code', 'applicant_verification_required', 'message', 'This poster requires verified applicants for this job.');
  end if;
  if (
    select count(*) from public.applications
    where teen_id = auth.uid()
      and status in ('submitted', 'guardian_pending', 'adult_review', 'viewed', 'accepted', 'in_progress', 'proof_submitted')
  ) >= 20 then
    return jsonb_build_object('eligible', false, 'code', 'application_limit_reached', 'message', 'You have reached the active application limit. Finish or withdraw an application before adding another.');
  end if;

  v_policy := public.get_guardian_policy_for_user(auth.uid());
  v_guardian_required := v_job.requires_guardian_approval
    or coalesce((v_policy->>'guardian_link_required')::boolean, false)
    or coalesce((v_policy->>'guardian_approval_required_for_application')::boolean, false);

  select guardian_id into v_guardian_id
  from public.guardian_connections
  where teen_id = auth.uid() and status = 'active' and guardian_id is not null
  order by accepted_at desc nulls last
  limit 1;

  if v_guardian_required and v_guardian_id is null then
    return jsonb_build_object(
      'eligible', false,
      'code', 'guardian_link_required',
      'message', 'This job requires guardian approval. Link a guardian or choose another job.',
      'guardian_required_for_this_job', true
    );
  end if;

  return jsonb_build_object(
    'eligible', true,
    'code', 'eligible',
    'message', 'You can apply to this job.',
    'guardian_required_for_this_job', v_guardian_required,
    'guardian_linked', v_guardian_id is not null,
    'verification_requirement', v_job.verification_requirement,
    'schedule_type', v_job.schedule_type
  );
end;
$$;

create or replace function public.submit_job_application(
  p_job_id uuid,
  p_note text default null,
  p_availability_confirmed boolean default false,
  p_portfolio_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eligibility jsonb;
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_guardian_id uuid;
  v_guardian_required boolean;
begin
  v_eligibility := public.get_job_application_eligibility(p_job_id);
  if not coalesce((v_eligibility->>'eligible')::boolean, false) then
    return v_eligibility || jsonb_build_object('ok', false);
  end if;
  if not public.is_action_allowed('job_application_create') then
    return jsonb_build_object('ok', false, 'eligible', false, 'code', 'application_limit_reached', 'message', 'You have submitted too many applications today. Try again tomorrow.');
  end if;

  v_guardian_required := coalesce((v_eligibility->>'guardian_required_for_this_job')::boolean, false);
  if v_guardian_required then
    select guardian_id into v_guardian_id
    from public.guardian_connections
    where teen_id = auth.uid() and status = 'active' and guardian_id is not null
    order by accepted_at desc nulls last
    limit 1;
  end if;

  insert into public.applications (
    job_id,
    teen_id,
    status,
    note,
    guardian_id,
    availability_confirmed,
    portfolio_ids
  ) values (
    p_job_id,
    auth.uid(),
    case when v_guardian_required then 'guardian_pending'::public.application_status else 'adult_review'::public.application_status end,
    nullif(left(btrim(coalesce(p_note, '')), 500), ''),
    v_guardian_id,
    p_availability_confirmed,
    coalesce(p_portfolio_ids, '{}')
  ) returning * into v_application;

  select * into v_job from public.jobs where id = p_job_id;
  perform public.record_rate_limit_event('job_application_create');
  return jsonb_build_object(
    'ok', true,
    'eligible', true,
    'code', 'application_submitted',
    'message', case when v_guardian_required then 'Application sent for guardian approval.' else 'Application submitted to the poster.' end,
    'application', to_jsonb(v_application) || jsonb_build_object('jobs', to_jsonb(v_job))
  );
exception when unique_violation then
  return jsonb_build_object('ok', false, 'eligible', false, 'code', 'application_already_exists', 'message', 'You already applied to this job.');
end;
$$;

create or replace function public.update_application_status_v2(
  p_application_id uuid,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_application public.applications%rowtype;
  v_job public.jobs%rowtype;
  v_action text := lower(btrim(p_action));
begin
  select * into v_application from public.applications where id = p_application_id;
  if v_application.id is null then
    return jsonb_build_object('ok', false, 'code', 'application_not_found');
  end if;
  select * into v_job from public.jobs where id = v_application.job_id;

  if v_action in ('adult_review', 'guardian_rejected')
     and v_application.guardian_id = auth.uid()
     and v_application.status = 'guardian_pending'
     and public.guardian_is_connected_to_teen(v_application.teen_id, auth.uid()) then
    update public.applications
    set status = v_action::public.application_status
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'viewed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review') then
    update public.applications
    set status = 'viewed', viewed_at = now()
    where id = p_application_id
    returning * into v_application;
  elsif v_action = 'accepted'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed')
     and v_job.status = 'open' and v_job.applications_open then
    update public.applications set status = 'accepted' where id = p_application_id returning * into v_application;
    update public.applications
    set status = 'rejected'
    where job_id = v_job.id and id <> p_application_id
      and status in ('submitted', 'adult_review', 'viewed');
    update public.jobs set status = 'assigned', applications_open = false where id = v_job.id returning * into v_job;
  elsif v_action = 'rejected'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('submitted', 'adult_review', 'viewed') then
    update public.applications set status = 'rejected' where id = p_application_id returning * into v_application;
  elsif v_action = 'withdrawn'
     and v_application.teen_id = auth.uid()
     and v_application.status in ('submitted', 'guardian_pending', 'adult_review', 'viewed') then
    update public.applications set status = 'withdrawn', withdrawn_at = now() where id = p_application_id returning * into v_application;
  elsif v_action = 'in_progress'
     and v_application.teen_id = auth.uid()
     and v_application.status = 'accepted'
     and v_job.status = 'assigned' then
    update public.applications set status = 'in_progress' where id = p_application_id returning * into v_application;
    update public.jobs set status = 'in_progress' where id = v_job.id returning * into v_job;
  elsif v_action = 'proof_submitted'
     and v_application.teen_id = auth.uid()
     and v_application.status = 'in_progress' then
    update public.applications set status = 'proof_submitted' where id = p_application_id returning * into v_application;
    update public.jobs set status = 'proof_submitted' where id = v_job.id returning * into v_job;
  elsif v_action = 'completed'
     and v_job.poster_id = auth.uid()
     and v_application.status in ('in_progress', 'proof_submitted')
     and v_job.status in ('in_progress', 'proof_submitted') then
    update public.applications set status = 'completed' where id = p_application_id returning * into v_application;
    update public.jobs set status = 'completed' where id = v_job.id returning * into v_job;
  else
    return jsonb_build_object('ok', false, 'code', 'invalid_application_transition');
  end if;

  return jsonb_build_object('ok', true, 'application', to_jsonb(v_application), 'job', to_jsonb(v_job));
end;
$$;

drop policy if exists applications_insert_teen on public.applications;
create policy applications_insert_admin_only
on public.applications for insert to authenticated
with check (public.is_admin());

drop policy if exists applications_update_participants on public.applications;
create policy applications_update_admin_only
on public.applications for update to authenticated
using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy storage_profile_avatars_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy storage_profile_avatars_select_owner_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'profile-avatars'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
  )
);

create policy storage_profile_avatars_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'profile-avatars'
  and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
)
with check (
  bucket_id = 'profile-avatars'
  and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
);

create policy storage_profile_avatars_delete_own
on storage.objects for delete to authenticated
using (
  bucket_id = 'profile-avatars'
  and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
);

grant select, insert, update on public.guardian_preferences to authenticated;
grant select on public.jurisdiction_guardian_policies to authenticated;
grant select, insert, delete on public.saved_jobs to authenticated;
grant select, insert, update, delete on public.job_templates to authenticated;
grant select on public.job_status_events, public.application_status_events to authenticated;
grant select, insert on public.reviews to authenticated;

grant all on public.guardian_preferences,
  public.jurisdiction_guardian_policies,
  public.saved_jobs,
  public.job_templates,
  public.job_status_events,
  public.application_status_events,
  public.reviews to service_role;

revoke execute on function public.get_guardian_policy_for_user(uuid) from public, anon;
revoke execute on function public.create_guardian_invite_v2(text) from public, anon;
revoke execute on function public.create_guardian_invite() from public, anon;
revoke execute on function public.accept_guardian_invite(text) from public, anon;
revoke execute on function public.cancel_guardian_invite(uuid) from public, anon;
revoke execute on function public.resend_guardian_invite(uuid) from public, anon;
revoke execute on function public.unlink_guardian(uuid) from public, anon;
revoke execute on function public.set_guardian_setup_skipped() from public, anon;
revoke execute on function public.save_job_draft_or_publish(uuid, uuid, jsonb, boolean) from public, anon;
revoke execute on function public.manage_job(uuid, text) from public, anon;
revoke execute on function public.get_job_application_eligibility(uuid) from public, anon;
revoke execute on function public.submit_job_application(uuid, text, boolean, uuid[]) from public, anon;
revoke execute on function public.update_application_status_v2(uuid, text) from public, anon;
revoke execute on function public.ensure_guardian_preferences() from public, anon, authenticated;
revoke execute on function public.log_job_status_event() from public, anon, authenticated;
revoke execute on function public.log_application_status_event() from public, anon, authenticated;

grant execute on function public.get_guardian_policy_for_user(uuid) to authenticated, service_role;
grant execute on function public.create_guardian_invite_v2(text) to authenticated, service_role;
grant execute on function public.create_guardian_invite() to authenticated, service_role;
grant execute on function public.accept_guardian_invite(text) to authenticated, service_role;
grant execute on function public.cancel_guardian_invite(uuid) to authenticated, service_role;
grant execute on function public.resend_guardian_invite(uuid) to authenticated, service_role;
grant execute on function public.unlink_guardian(uuid) to authenticated, service_role;
grant execute on function public.set_guardian_setup_skipped() to authenticated, service_role;
grant execute on function public.save_job_draft_or_publish(uuid, uuid, jsonb, boolean) to authenticated, service_role;
grant execute on function public.manage_job(uuid, text) to authenticated, service_role;
grant execute on function public.get_job_application_eligibility(uuid) to authenticated, service_role;
grant execute on function public.submit_job_application(uuid, text, boolean, uuid[]) to authenticated, service_role;
grant execute on function public.update_application_status_v2(uuid, text) to authenticated, service_role;
