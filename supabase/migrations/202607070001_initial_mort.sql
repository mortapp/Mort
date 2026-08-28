create extension if not exists pgcrypto;

create type public.user_role as enum ('teen', 'adult', 'guardian', 'admin');
create type public.verification_status as enum ('not_started', 'pending', 'approved', 'rejected');
create type public.payment_preference as enum ('cash', 'cash_app', 'square_link', 'flexible', 'none');
create type public.account_status as enum ('active', 'suspended', 'banned');
create type public.job_status as enum ('draft', 'open', 'paused', 'filled', 'closed', 'removed');
create type public.application_status as enum (
  'submitted',
  'guardian_pending',
  'guardian_rejected',
  'adult_review',
  'accepted',
  'rejected',
  'completed',
  'disputed'
);
create type public.guardian_connection_status as enum ('invited', 'active', 'revoked');
create type public.scanner_status as enum ('clean', 'flagged', 'blocked');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
create type public.safety_ping_status as enum ('ok', 'needs_help', 'missed');
create type public.notification_event_status as enum ('pending', 'sent', 'failed');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role,
  display_name text,
  dob date,
  city text,
  state text,
  onboarding_completed boolean not null default false,
  account_status public.account_status not null default 'active',
  verification_status public.verification_status not null default 'not_started',
  payment_preference public.payment_preference not null default 'none',
  expo_push_token text,
  blocked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_state_length check (state is null or char_length(state) = 2),
  constraint profiles_completed_required_fields check (
    onboarding_completed = false
    or (
      role is not null
      and display_name is not null
      and btrim(display_name) <> ''
      and dob is not null
      and city is not null
      and btrim(city) <> ''
      and state is not null
      and char_length(state) = 2
      and date_part('year', age(dob)) >= 13
    )
  ),
  constraint profiles_teen_age_range check (
    role is distinct from 'teen'
    or dob is null
    or (
      date_part('year', age(dob)) >= 13
      and date_part('year', age(dob)) < 18
    )
  ),
  constraint profiles_adult_guardian_admin_age_range check (
    role not in ('adult', 'guardian', 'admin')
    or dob is null
    or date_part('year', age(dob)) >= 18
  )
);

create table public.teen_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  guardian_approval_required boolean not null default true,
  paused_by_guardian boolean not null default false,
  pause_reason text,
  bio text,
  skills text[] not null default '{}',
  school_year text
);

create table public.adult_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  business_name text,
  business_type text,
  verification_notes text
);

create table public.guardian_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  emergency_contact_name text,
  emergency_contact_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guardian_connections (
  id uuid primary key default gen_random_uuid(),
  teen_id uuid not null references public.profiles(id) on delete cascade,
  guardian_id uuid references public.profiles(id) on delete cascade,
  status public.guardian_connection_status not null default 'invited',
  invite_code text not null unique default upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 8)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guardian_connections_roles check (teen_id is distinct from guardian_id)
);

create unique index guardian_connections_active_pair_idx
on public.guardian_connections(teen_id, guardian_id)
where guardian_id is not null and status = 'active';

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  category text not null,
  location_text text not null,
  city text not null,
  state text not null,
  pay_amount_cents integer,
  pay_label text,
  teen_min_age integer not null default 13,
  teen_max_age integer not null default 17,
  requires_guardian_approval boolean not null default true,
  status public.job_status not null default 'open',
  starts_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint jobs_age_bounds check (teen_min_age >= 13 and teen_max_age <= 17 and teen_min_age <= teen_max_age),
  constraint jobs_pay_non_negative check (pay_amount_cents is null or pay_amount_cents >= 0),
  constraint jobs_state_length check (char_length(state) = 2)
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  teen_id uuid not null references public.profiles(id) on delete cascade,
  status public.application_status not null default 'submitted',
  note text,
  guardian_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(job_id, teen_id)
);

create table public.message_threads (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  application_id uuid unique references public.applications(id) on delete cascade,
  teen_id uuid references public.profiles(id) on delete set null,
  adult_id uuid references public.profiles(id) on delete set null,
  guardian_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  legacy_thread_id uuid unique references public.message_threads(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  application_id uuid unique references public.applications(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  scanner_status public.scanner_status not null default 'clean',
  scanner_reason text,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_user_id uuid references public.profiles(id) on delete set null,
  target_job_id uuid references public.jobs(id) on delete set null,
  target_message_id uuid references public.messages(id) on delete set null,
  reason text not null,
  details text,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

create table public.payment_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  preference public.payment_preference not null default 'none',
  cash_app_tag text,
  square_url text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_preferences_cash_app_format check (
    cash_app_tag is null or cash_app_tag ~ '^\$?[A-Za-z][A-Za-z0-9_]{1,20}$'
  ),
  constraint payment_preferences_square_url_format check (
    square_url is null or square_url ~* '^https?://'
  ),
  constraint payment_preferences_note_length check (note is null or char_length(note) <= 240)
);

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  expo_push_token text not null unique,
  platform text not null default 'unknown',
  is_active boolean not null default true,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, expo_push_token)
);

create table public.business_verifications (
  id uuid primary key default gen_random_uuid(),
  adult_id uuid not null references public.profiles(id) on delete cascade,
  business_name text not null,
  business_type text not null,
  document_storage_path text,
  notes text,
  status public.verification_status not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.proof_uploads (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  uploaded_by uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null,
  note text,
  created_at timestamptz not null default now()
);

create table public.safety_pings (
  id uuid primary key default gen_random_uuid(),
  teen_id uuid not null references public.profiles(id) on delete cascade,
  guardian_id uuid references public.profiles(id) on delete set null,
  status public.safety_ping_status not null,
  note text,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.notification_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  status public.notification_event_status not null default 'pending',
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_tickets_status check (status in ('open', 'waiting', 'resolved', 'closed'))
);

create table public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table public.admin_action_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  target_table text,
  target_id uuid,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index jobs_status_city_idx on public.jobs(status, city, state);
create index profiles_role_idx on public.profiles(role);
create index profiles_verification_status_idx on public.profiles(verification_status);
create index guardian_connections_teen_status_idx on public.guardian_connections(teen_id, status);
create index guardian_connections_guardian_status_idx on public.guardian_connections(guardian_id, status);
create index jobs_poster_created_idx on public.jobs(poster_id, created_at desc);
create index applications_job_idx on public.applications(job_id);
create index applications_teen_idx on public.applications(teen_id);
create index applications_guardian_idx on public.applications(guardian_id);
create index message_threads_participants_idx on public.message_threads(teen_id, adult_id, guardian_id);
create index message_threads_teen_idx on public.message_threads(teen_id);
create index message_threads_adult_idx on public.message_threads(adult_id);
create index message_threads_guardian_idx on public.message_threads(guardian_id);
create index conversations_application_idx on public.conversations(application_id);
create index conversation_participants_user_idx on public.conversation_participants(user_id);
create index messages_thread_created_idx on public.messages(thread_id, created_at);
create index reports_status_created_idx on public.reports(status, created_at desc);
create index reports_reporter_created_idx on public.reports(reporter_id, created_at desc);
create index reports_target_user_idx on public.reports(target_user_id);
create index reports_target_job_idx on public.reports(target_job_id);
create index reports_target_message_idx on public.reports(target_message_id);
create index blocks_blocker_idx on public.blocks(blocker_id);
create index blocks_blocked_idx on public.blocks(blocked_id);
create index push_tokens_user_idx on public.push_tokens(user_id);
create index business_verifications_adult_idx on public.business_verifications(adult_id);
create index business_verifications_status_idx on public.business_verifications(status, created_at desc);
create index proof_uploads_application_idx on public.proof_uploads(application_id, created_at desc);
create index proof_uploads_uploaded_by_idx on public.proof_uploads(uploaded_by);
create index safety_pings_teen_created_idx on public.safety_pings(teen_id, created_at desc);
create index safety_pings_guardian_created_idx on public.safety_pings(guardian_id, created_at desc);
create index notifications_recipient_created_idx on public.notifications(recipient_id, created_at desc);
create index notification_events_status_idx on public.notification_events(status, created_at);
create index support_tickets_requester_idx on public.support_tickets(requester_id, created_at desc);
create index support_ticket_messages_ticket_idx on public.support_ticket_messages(ticket_id, created_at);
create index admin_action_logs_admin_idx on public.admin_action_logs(admin_id, created_at desc);

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create trigger guardian_connections_set_updated_at before update on public.guardian_connections
for each row execute function public.set_updated_at();

create trigger guardian_profiles_set_updated_at before update on public.guardian_profiles
for each row execute function public.set_updated_at();

create trigger jobs_set_updated_at before update on public.jobs
for each row execute function public.set_updated_at();

create trigger applications_set_updated_at before update on public.applications
for each row execute function public.set_updated_at();

create trigger message_threads_set_updated_at before update on public.message_threads
for each row execute function public.set_updated_at();

create trigger conversations_set_updated_at before update on public.conversations
for each row execute function public.set_updated_at();

create trigger reports_set_updated_at before update on public.reports
for each row execute function public.set_updated_at();

create trigger business_verifications_set_updated_at before update on public.business_verifications
for each row execute function public.set_updated_at();

create trigger payment_preferences_set_updated_at before update on public.payment_preferences
for each row execute function public.set_updated_at();

create trigger push_tokens_set_updated_at before update on public.push_tokens
for each row execute function public.set_updated_at();

create trigger support_tickets_set_updated_at before update on public.support_tickets
for each row execute function public.set_updated_at();

create or replace function public.current_profile_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() = 'admin', false);
$$;

create or replace function public.is_profile_active(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p_user_id
      and account_status = 'active'
      and (blocked_until is null or blocked_until < now())
  );
$$;

create or replace function public.is_verified_adult()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('adult', 'admin')
      and verification_status = 'approved'
      and public.is_profile_active(id)
  );
$$;

create or replace function public.is_application_participant(p_application_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    where a.id = p_application_id
      and (
        a.teen_id = auth.uid()
        or a.guardian_id = auth.uid()
        or j.poster_id = auth.uid()
        or public.is_admin()
      )
  );
$$;

create or replace function public.is_thread_participant(p_thread_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.message_threads mt
    where mt.id = p_thread_id
      and (
        mt.teen_id = auth.uid()
        or mt.adult_id = auth.uid()
        or mt.guardian_id = auth.uid()
        or public.is_admin()
      )
  );
$$;

create or replace function public.guardian_is_connected_to_teen(p_teen_id uuid, p_guardian_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.guardian_connections
    where teen_id = p_teen_id
      and guardian_id = p_guardian_id
      and status = 'active'
  );
$$;

create or replace function public.users_are_blocked(p_user_one uuid, p_user_two uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.blocks
    where (blocker_id = p_user_one and blocked_id = p_user_two)
       or (blocker_id = p_user_two and blocked_id = p_user_one)
  );
$$;

create or replace function public.teen_is_paused(p_teen_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teen_profiles
    where user_id = p_teen_id
      and paused_by_guardian = true
  );
$$;

create or replace function public.set_teen_pause(p_teen_id uuid, p_paused boolean, p_reason text default null)
returns public.teen_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_profile public.teen_profiles;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not (public.is_admin() or public.guardian_is_connected_to_teen(p_teen_id, auth.uid())) then
    raise exception 'Only linked guardians or admins can pause teen activity.';
  end if;

  update public.teen_profiles
  set paused_by_guardian = p_paused,
      pause_reason = nullif(left(coalesce(p_reason, ''), 240), '')
  where user_id = p_teen_id
  returning * into updated_profile;

  if updated_profile.user_id is null then
    raise exception 'Teen profile not found.';
  end if;

  return updated_profile;
end;
$$;

create or replace function public.protect_profile_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  internal_update text := current_setting('mort.internal_update', true);
begin
  if public.is_admin() or internal_update = 'true' then
    return new;
  end if;

  if new.role = 'admin' then
    raise exception 'Admin role cannot be self-assigned.';
  end if;

  if tg_op = 'UPDATE' then
    if old.role is not null and old.role is distinct from new.role then
      raise exception 'Role changes require admin review.';
    end if;

    if old.verification_status is distinct from new.verification_status then
      raise exception 'Verification status requires admin review.';
    end if;

    if old.account_status is distinct from new.account_status then
      raise exception 'Account status requires admin review.';
    end if;

    if old.blocked_until is distinct from new.blocked_until then
      raise exception 'Account restrictions require admin review.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.enforce_profile_completion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_age integer;
begin
  if new.state is not null then
    new.state = upper(new.state);
  end if;

  if new.onboarding_completed then
    if new.display_name is null or btrim(new.display_name) = '' then
      raise exception 'Display name is required to complete onboarding.';
    end if;

    if new.dob is null then
      raise exception 'Date of birth is required to complete onboarding.';
    end if;

    if new.role is null then
      raise exception 'Role is required to complete onboarding.';
    end if;

    if new.city is null or btrim(new.city) = '' then
      raise exception 'City is required to complete onboarding.';
    end if;

    if new.state is null or char_length(new.state) <> 2 then
      raise exception 'A 2-letter state is required to complete onboarding.';
    end if;

    profile_age := date_part('year', age(new.dob));

    if profile_age < 13 then
      raise exception 'MORT is available only to users age 13 and older.';
    end if;

    if new.role = 'teen' and not (profile_age >= 13 and profile_age < 18) then
      raise exception 'Teen role requires age 13 through 17.';
    end if;

    if new.role in ('adult', 'guardian', 'admin') and profile_age < 18 then
      raise exception 'Adult, guardian, and admin roles require age 18 or older.';
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_enforce_completion
before insert or update on public.profiles
for each row execute function public.enforce_profile_completion();

create trigger profiles_protect_sensitive_fields
before insert or update on public.profiles
for each row execute function public.protect_profile_sensitive_fields();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('mort.internal_update', 'true', true);

  insert into public.profiles (id, display_name)
  values (new.id, nullif(coalesce(new.raw_user_meta_data->>'display_name', ''), ''))
  on conflict (id) do nothing;

  perform set_config('mort.internal_update', '', true);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.sync_business_verification_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('mort.internal_update', 'true', true);

  update public.profiles
  set verification_status = new.status
  where id = new.adult_id;

  perform set_config('mort.internal_update', '', true);
  return new;
end;
$$;

create trigger business_verifications_sync_profile
after insert or update of status on public.business_verifications
for each row execute function public.sync_business_verification_status();

create or replace function public.create_guardian_invite()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  invite text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if public.current_profile_role() <> 'teen' then
    raise exception 'Only teen profiles can create guardian invites.';
  end if;

  insert into public.guardian_connections (teen_id, status)
  values (auth.uid(), 'invited')
  returning invite_code into invite;

  return invite;
end;
$$;

create or replace function public.accept_guardian_invite(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  connection_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if public.current_profile_role() <> 'guardian' then
    raise exception 'Only guardian profiles can accept guardian invites.';
  end if;

  update public.guardian_connections
  set guardian_id = auth.uid(),
      status = 'active'
  where invite_code = upper(trim(p_invite_code))
    and status = 'invited'
    and guardian_id is null
  returning id into connection_id;

  if connection_id is null then
    raise exception 'Invite code was not found or already used.';
  end if;

  return connection_id;
end;
$$;

create or replace function public.ensure_message_thread_for_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  poster uuid;
begin
  select poster_id into poster from public.jobs where id = new.job_id;

  insert into public.message_threads (job_id, application_id, teen_id, adult_id, guardian_id)
  values (new.job_id, new.id, new.teen_id, poster, new.guardian_id)
  on conflict (application_id) do nothing;

  return new;
end;
$$;

create trigger applications_create_thread
after insert on public.applications
for each row execute function public.ensure_message_thread_for_application();

create or replace function public.sync_conversation_for_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
begin
  insert into public.conversations (legacy_thread_id, job_id, application_id)
  values (new.id, new.job_id, new.application_id)
  on conflict (legacy_thread_id) do update
    set job_id = excluded.job_id,
        application_id = excluded.application_id
  returning id into v_conversation_id;

  if new.teen_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.teen_id, 'teen')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  if new.adult_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.adult_id, 'adult')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  if new.guardian_id is not null then
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conversation_id, new.guardian_id, 'guardian')
    on conflict (conversation_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

create trigger message_threads_sync_conversation
after insert or update of job_id, application_id, teen_id, adult_id, guardian_id on public.message_threads
for each row execute function public.sync_conversation_for_thread();

create or replace function public.scan_message_body(p_body text)
returns text
language plpgsql
immutable
as $$
declare
  normalized text := lower(trim(coalesce(p_body, '')));
begin
  if normalized = '' then
    return 'Message cannot be empty.';
  end if;

  if p_body ~* '(\+?1[-.\s]?)?(\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}' then
    return 'Phone numbers must stay off MORT chat.';
  end if;

  if p_body ~* '[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}' then
    return 'Email addresses must stay off MORT chat.';
  end if;

  if normalized like '%cashapp%'
    or normalized ~ '\$[A-Za-z][A-Za-z0-9_]{1,20}'
    or normalized like '%venmo%'
    or normalized like '%zelle%'
    or normalized like '%paypal%'
    or normalized like '%square link%'
    or normalized like '%instagram%'
    or normalized like '% insta%'
    or normalized like '%snapchat%'
    or normalized like '%tiktok%'
    or normalized like '%discord%'
    or normalized like '%telegram%'
    or normalized like '%whatsapp%'
    or normalized like '%signal%'
    or normalized like '%kik%'
    or normalized ~ '@[A-Za-z0-9_.]{2,}'
    or normalized like '%meet alone%'
    or normalized like '%home address%'
    or normalized like '%come to my house%'
    or normalized like '%don''t tell%'
    or normalized like '%dont tell%'
    or normalized like '%keep this secret%'
    or normalized like '%off app%'
    or normalized like '%upfront fee%'
    or normalized like '%deposit first%'
    or normalized like '%sexual%'
    or normalized like '%nude%'
    or normalized like '%threat%'
    or normalized like '%secret%' then
    return 'Message includes unsafe contact or secrecy language.';
  end if;

  return null;
end;
$$;

create or replace function public.send_safe_message(p_thread_id uuid, p_body text)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  reason text;
  saved_message public.messages;
  thread_record public.message_threads;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if not public.is_profile_active(auth.uid()) then
    raise exception 'Your account is currently restricted.';
  end if;

  if not public.is_thread_participant(p_thread_id) then
    raise exception 'You are not a participant in this thread.';
  end if;

  select * into thread_record
  from public.message_threads
  where id = p_thread_id;

  if thread_record.teen_id = auth.uid() and public.teen_is_paused(thread_record.teen_id) then
    raise exception 'Guardian Mode has paused messaging for this teen account.';
  end if;

  if (thread_record.teen_id is not null and thread_record.teen_id <> auth.uid() and public.users_are_blocked(auth.uid(), thread_record.teen_id))
    or (thread_record.adult_id is not null and thread_record.adult_id <> auth.uid() and public.users_are_blocked(auth.uid(), thread_record.adult_id))
    or (thread_record.guardian_id is not null and thread_record.guardian_id <> auth.uid() and public.users_are_blocked(auth.uid(), thread_record.guardian_id)) then
    raise exception 'Messaging is unavailable because a participant is blocked.';
  end if;

  reason := public.scan_message_body(p_body);
  if reason is not null then
    insert into public.messages (thread_id, sender_id, body, scanner_status, scanner_reason)
    values (p_thread_id, auth.uid(), left(coalesce(p_body, ''), 500), 'blocked', reason)
    returning * into saved_message;
    raise exception '%', reason;
  end if;

  insert into public.messages (thread_id, sender_id, body, scanner_status)
  values (p_thread_id, auth.uid(), trim(p_body), 'clean')
  returning * into saved_message;

  return saved_message;
end;
$$;

create or replace function public.enqueue_notification(p_recipient_id uuid, p_title text, p_body text, p_data jsonb default '{}')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_id is null then
    return;
  end if;

  insert into public.notification_events (recipient_id, title, body, data)
  values (p_recipient_id, p_title, p_body, coalesce(p_data, '{}'));

  insert into public.notifications (recipient_id, title, body, data)
  values (p_recipient_id, p_title, p_body, coalesce(p_data, '{}'));
end;
$$;

create or replace function public.queue_application_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  poster uuid;
  job_title text;
begin
  select j.poster_id, j.title into poster, job_title
  from public.jobs j
  where j.id = new.job_id;

  if tg_op = 'INSERT' and new.status = 'guardian_pending' and new.guardian_id is not null then
    perform public.enqueue_notification(new.guardian_id, 'Guardian approval needed', 'A teen application needs your review.', jsonb_build_object('applicationId', new.id, 'jobId', new.job_id));
  elsif tg_op = 'INSERT' and new.status in ('submitted', 'adult_review') then
    perform public.enqueue_notification(poster, 'New MORT application', 'A teen applied to ' || job_title || '.', jsonb_build_object('applicationId', new.id, 'jobId', new.job_id));
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status = 'adult_review' then
      perform public.enqueue_notification(new.teen_id, 'Guardian approved', 'Your guardian approved the application for adult review.', jsonb_build_object('applicationId', new.id, 'jobId', new.job_id));
      perform public.enqueue_notification(poster, 'Application ready for review', 'A guardian approved a teen application for ' || job_title || '.', jsonb_build_object('applicationId', new.id, 'jobId', new.job_id));
    elsif new.status in ('accepted', 'rejected', 'guardian_rejected', 'completed', 'disputed') then
      perform public.enqueue_notification(new.teen_id, 'Application update', 'Your application status is now ' || new.status || '.', jsonb_build_object('applicationId', new.id, 'jobId', new.job_id));
    end if;
  end if;

  return new;
end;
$$;

create trigger applications_queue_notifications
after insert or update of status on public.applications
for each row execute function public.queue_application_notifications();

create or replace function public.queue_proof_upload_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  poster uuid;
begin
  select j.poster_id into poster
  from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.id = new.application_id;

  perform public.enqueue_notification(
    poster,
    'Proof submitted',
    'A teen submitted proof for your review.',
    jsonb_build_object('applicationId', new.application_id, 'proofUploadId', new.id)
  );

  return new;
end;
$$;

create trigger proof_uploads_queue_notifications
after insert on public.proof_uploads
for each row execute function public.queue_proof_upload_notifications();

create or replace function public.queue_safety_ping_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_profile record;
begin
  if new.guardian_id is not null then
    perform public.enqueue_notification(
      new.guardian_id,
      'Teen safety ping',
      'A linked teen sent a safety ping: ' || new.status || '.',
      jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'status', new.status)
    );
  else
    for admin_profile in select id from public.profiles where role = 'admin' loop
      perform public.enqueue_notification(
        admin_profile.id,
        'Unsupervised safety ping',
        'A teen sent a safety ping without a linked guardian.',
        jsonb_build_object('safetyPingId', new.id, 'teenId', new.teen_id, 'status', new.status)
      );
    end loop;
  end if;

  return new;
end;
$$;

create trigger safety_pings_queue_notifications
after insert on public.safety_pings
for each row execute function public.queue_safety_ping_notifications();

create or replace function public.queue_verification_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status and new.status in ('approved', 'rejected') then
    perform public.enqueue_notification(
      new.adult_id,
      'Verification ' || new.status,
      'Your internal MORT verification status is now ' || new.status || '.',
      jsonb_build_object('verificationId', new.id)
    );
  end if;

  return new;
end;
$$;

create trigger business_verifications_queue_notifications
after update of status on public.business_verifications
for each row execute function public.queue_verification_notifications();

create or replace function public.queue_report_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_profile record;
begin
  for admin_profile in select id from public.profiles where role = 'admin' loop
    perform public.enqueue_notification(
      admin_profile.id,
      'Safety report submitted',
      'A MORT safety report is ready for moderation.',
      jsonb_build_object('reportId', new.id, 'targetUserId', new.target_user_id, 'targetJobId', new.target_job_id)
    );
  end loop;

  return new;
end;
$$;

create trigger reports_queue_notifications
after insert on public.reports
for each row execute function public.queue_report_notifications();

create or replace function public.log_admin_status_action()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and public.is_admin() then
    insert into public.admin_action_logs (admin_id, action, target_table, target_id, details)
    values (
      auth.uid(),
      tg_table_name || '_status_update',
      tg_table_name,
      new.id,
      jsonb_build_object('oldStatus', old.status, 'newStatus', new.status)
    );
  end if;

  return new;
end;
$$;

create trigger reports_log_admin_status
after update of status on public.reports
for each row
when (old.status is distinct from new.status)
execute function public.log_admin_status_action();

create trigger jobs_log_admin_status
after update of status on public.jobs
for each row
when (old.status is distinct from new.status)
execute function public.log_admin_status_action();

create trigger business_verifications_log_admin_status
after update of status on public.business_verifications
for each row
when (old.status is distinct from new.status)
execute function public.log_admin_status_action();

alter table public.profiles enable row level security;
alter table public.teen_profiles enable row level security;
alter table public.adult_profiles enable row level security;
alter table public.guardian_profiles enable row level security;
alter table public.guardian_connections enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.message_threads enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.payment_preferences enable row level security;
alter table public.push_tokens enable row level security;
alter table public.business_verifications enable row level security;
alter table public.proof_uploads enable row level security;
alter table public.safety_pings enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_events enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
alter table public.admin_action_logs enable row level security;

create policy profiles_select_visible on public.profiles
for select using (
  id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.guardian_connections gc
    where gc.status = 'active'
      and ((gc.teen_id = profiles.id and gc.guardian_id = auth.uid()) or (gc.guardian_id = profiles.id and gc.teen_id = auth.uid()))
  )
  or exists (
    select 1
    from public.applications a
    join public.jobs j on j.id = a.job_id
    where a.teen_id = profiles.id
      and j.poster_id = auth.uid()
  )
);

create policy profiles_insert_self on public.profiles
for insert with check (id = auth.uid());

create policy profiles_update_self_or_admin on public.profiles
for update using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

create policy teen_profiles_select on public.teen_profiles
for select using (
  user_id = auth.uid()
  or public.is_admin()
  or public.guardian_is_connected_to_teen(user_id)
);

create policy teen_profiles_upsert_self on public.teen_profiles
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy adult_profiles_select on public.adult_profiles
for select using (user_id = auth.uid() or public.is_admin());

create policy adult_profiles_upsert_self on public.adult_profiles
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy guardian_profiles_select on public.guardian_profiles
for select using (user_id = auth.uid() or public.is_admin());

create policy guardian_profiles_upsert_self on public.guardian_profiles
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy guardian_connections_select on public.guardian_connections
for select using (
  teen_id = auth.uid()
  or guardian_id = auth.uid()
  or public.is_admin()
);

create policy guardian_connections_insert_teen on public.guardian_connections
for insert with check (teen_id = auth.uid() and guardian_id is null and public.current_profile_role() = 'teen');

create policy guardian_connections_update_guardian_or_admin on public.guardian_connections
for update using (
  public.is_admin()
  or teen_id = auth.uid()
  or (status = 'invited' and guardian_id is null and public.current_profile_role() = 'guardian')
  or guardian_id = auth.uid()
)
with check (
  public.is_admin()
  or teen_id = auth.uid()
  or guardian_id = auth.uid()
);

create policy jobs_select_visible on public.jobs
for select using (
  status = 'open'
  or poster_id = auth.uid()
  or public.is_admin()
  or exists (select 1 from public.applications a where a.job_id = jobs.id and public.is_application_participant(a.id))
);

create policy jobs_insert_verified_adult on public.jobs
for insert with check (poster_id = auth.uid() and public.is_verified_adult());

create policy jobs_update_poster_or_admin on public.jobs
for update using (poster_id = auth.uid() or public.is_admin())
with check (poster_id = auth.uid() or public.is_admin());

create policy applications_select_participant on public.applications
for select using (public.is_application_participant(id));

create policy applications_insert_teen on public.applications
for insert with check (
  teen_id = auth.uid()
  and public.current_profile_role() = 'teen'
  and public.is_profile_active(auth.uid())
  and not public.teen_is_paused(teen_id)
  and exists (
    select 1 from public.jobs j
    where j.id = job_id
      and j.status = 'open'
  )
  and (
    guardian_id is null
    or public.guardian_is_connected_to_teen(teen_id, guardian_id)
  )
);

create policy applications_update_participants on public.applications
for update using (
  public.is_admin()
  or (guardian_id = auth.uid() and status = 'guardian_pending')
  or exists (select 1 from public.jobs j where j.id = applications.job_id and j.poster_id = auth.uid())
)
with check (
  public.is_admin()
  or (guardian_id = auth.uid() and status in ('adult_review', 'guardian_rejected'))
  or exists (select 1 from public.jobs j where j.id = applications.job_id and j.poster_id = auth.uid())
);

create policy message_threads_select_participant on public.message_threads
for select using (public.is_thread_participant(id));

create policy message_threads_insert_application_participant on public.message_threads
for insert with check (
  public.is_admin()
  or (
    teen_id = auth.uid()
    and application_id is not null
    and public.is_application_participant(application_id)
  )
);

create policy message_threads_update_participant on public.message_threads
for update using (public.is_thread_participant(id))
with check (public.is_thread_participant(id));

create policy conversations_select_participant on public.conversations
for select using (
  public.is_admin()
  or exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversations.id
      and cp.user_id = auth.uid()
  )
);

create policy conversation_participants_select_self_or_admin on public.conversation_participants
for select using (
  user_id = auth.uid()
  or public.is_admin()
  or exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = conversation_participants.conversation_id
      and cp.user_id = auth.uid()
  )
);

create policy messages_select_thread_participant on public.messages
for select using (public.is_thread_participant(thread_id));

create policy reports_insert_reporter on public.reports
for insert with check (reporter_id = auth.uid());

create policy reports_select_reporter_or_admin on public.reports
for select using (reporter_id = auth.uid() or public.is_admin());

create policy reports_update_admin on public.reports
for update using (public.is_admin())
with check (public.is_admin());

create policy blocks_insert_self on public.blocks
for insert with check (blocker_id = auth.uid());

create policy blocks_select_self_or_admin on public.blocks
for select using (blocker_id = auth.uid() or blocked_id = auth.uid() or public.is_admin());

create policy payment_preferences_select_owner_or_admin on public.payment_preferences
for select using (user_id = auth.uid() or public.is_admin());

create policy payment_preferences_upsert_owner on public.payment_preferences
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy push_tokens_select_owner_or_admin on public.push_tokens
for select using (user_id = auth.uid() or public.is_admin());

create policy push_tokens_upsert_owner on public.push_tokens
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy business_verifications_insert_adult on public.business_verifications
for insert with check (adult_id = auth.uid() and public.current_profile_role() = 'adult');

create policy business_verifications_select_owner_or_admin on public.business_verifications
for select using (adult_id = auth.uid() or public.is_admin());

create policy business_verifications_update_admin on public.business_verifications
for update using (public.is_admin())
with check (public.is_admin());

create policy proof_uploads_insert_accepted_teen on public.proof_uploads
for insert with check (
  uploaded_by = auth.uid()
  and exists (
    select 1
    from public.applications a
    where a.id = application_id
      and a.teen_id = auth.uid()
      and a.status = 'accepted'
  )
);

create policy proof_uploads_select_participant on public.proof_uploads
for select using (public.is_application_participant(application_id));

create policy safety_pings_insert_teen on public.safety_pings
for insert with check (
  teen_id = auth.uid()
  and public.current_profile_role() = 'teen'
  and (guardian_id is null or public.guardian_is_connected_to_teen(teen_id, guardian_id))
);

create policy safety_pings_select_participant on public.safety_pings
for select using (
  teen_id = auth.uid()
  or guardian_id = auth.uid()
  or public.is_admin()
);

create policy notifications_select_recipient_or_admin on public.notifications
for select using (recipient_id = auth.uid() or public.is_admin());

create policy notifications_update_recipient_or_admin on public.notifications
for update using (recipient_id = auth.uid() or public.is_admin())
with check (recipient_id = auth.uid() or public.is_admin());

create policy notification_events_select_recipient_or_admin on public.notification_events
for select using (recipient_id = auth.uid() or public.is_admin());

create policy notification_events_update_admin on public.notification_events
for update using (public.is_admin())
with check (public.is_admin());

create policy support_tickets_insert_self on public.support_tickets
for insert with check (requester_id = auth.uid());

create policy support_tickets_select_owner_or_admin on public.support_tickets
for select using (requester_id = auth.uid() or public.is_admin());

create policy support_tickets_update_owner_or_admin on public.support_tickets
for update using (requester_id = auth.uid() or public.is_admin())
with check (requester_id = auth.uid() or public.is_admin());

create policy support_ticket_messages_insert_participant on public.support_ticket_messages
for insert with check (
  sender_id = auth.uid()
  and (
    public.is_admin()
    or exists (
      select 1 from public.support_tickets st
      where st.id = ticket_id and st.requester_id = auth.uid()
    )
  )
);

create policy support_ticket_messages_select_participant on public.support_ticket_messages
for select using (
  public.is_admin()
  or exists (
    select 1 from public.support_tickets st
    where st.id = ticket_id and st.requester_id = auth.uid()
  )
);

create policy admin_action_logs_select_admin on public.admin_action_logs
for select using (public.is_admin());

create policy admin_action_logs_insert_admin on public.admin_action_logs
for insert with check (public.is_admin() and admin_id = auth.uid());

create or replace view public.guardian_links
with (security_invoker = true)
as select * from public.guardian_connections;

create or replace view public.job_applications
with (security_invoker = true)
as select * from public.applications;

create or replace view public.blocked_users
with (security_invoker = true)
as select * from public.blocks;

create or replace view public.adult_verifications
with (security_invoker = true)
as select * from public.business_verifications;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('proof-uploads', 'proof-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('verification-uploads', 'verification-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('report-uploads', 'report-uploads', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy storage_mort_owner_insert on storage.objects
for insert with check (
  bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy storage_mort_owner_select on storage.objects
for select using (
  bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or (
      bucket_id = 'proof-uploads'
      and exists (
        select 1
        from public.proof_uploads pu
        where pu.storage_path = storage.objects.name
          and public.is_application_participant(pu.application_id)
      )
    )
  )
);

create policy storage_mort_owner_update on storage.objects
for update using (
  bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
  and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
)
with check (
  bucket_id in ('proof-uploads', 'verification-uploads', 'report-uploads')
  and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
);

revoke execute on all functions in schema public from public, anon;

grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;
grant select on public.guardian_links to authenticated, service_role;
grant select on public.job_applications to authenticated, service_role;
grant select on public.blocked_users to authenticated, service_role;
grant select on public.adult_verifications to authenticated, service_role;
grant execute on function public.current_profile_role() to authenticated, service_role;
grant execute on function public.is_admin() to authenticated, service_role;
grant execute on function public.is_profile_active(uuid) to authenticated, service_role;
grant execute on function public.is_verified_adult() to authenticated, service_role;
grant execute on function public.is_application_participant(uuid) to authenticated, service_role;
grant execute on function public.is_thread_participant(uuid) to authenticated, service_role;
grant execute on function public.guardian_is_connected_to_teen(uuid, uuid) to authenticated, service_role;
grant execute on function public.users_are_blocked(uuid, uuid) to authenticated, service_role;
grant execute on function public.teen_is_paused(uuid) to authenticated, service_role;
grant execute on function public.create_guardian_invite() to authenticated, service_role;
grant execute on function public.accept_guardian_invite(text) to authenticated, service_role;
grant execute on function public.send_safe_message(uuid, text) to authenticated, service_role;
grant execute on function public.set_teen_pause(uuid, boolean, text) to authenticated, service_role;
