
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

do $$ begin
  create type public.mort_role as enum ('pending','teen','adult','admin','moderator');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.mort_job_status as enum ('draft','open','paused','filled','in_progress','completed','cancelled','under_review');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.mort_application_status as enum ('submitted','withdrawn','shortlisted','accepted','rejected','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.mort_verification_status as enum ('not_started','pending','verified','rejected','expired','needs_review');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.mort_role not null default 'pending',
  account_status text not null default 'pending'
    check (account_status in ('pending','active','suspended','closed')),
  display_name text,
  avatar_path text,
  bio text,
  city text,
  region text,
  timezone text not null default 'America/Indiana/Indianapolis',
  date_of_birth date,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (display_name is null or char_length(display_name) between 1 and 80),
  constraint profiles_bio_length check (bio is null or char_length(bio) <= 500),
  constraint profiles_no_public_dob check (date_of_birth is null or date_of_birth <= current_date)
);

create table if not exists private.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.mort_role not null check (role in ('admin','moderator')),
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create or replace function private.has_staff_role(required_roles public.mort_role[])
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = any(required_roles)
  );
$$;
revoke all on function private.has_staff_role(public.mort_role[]) from public, anon;
grant execute on function private.has_staff_role(public.mort_role[]) to authenticated;

create or replace function private.is_active_user()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.account_status = 'active'
      and p.role in ('teen','adult','admin','moderator')
  );
$$;
revoke all on function private.is_active_user() from public, anon;
grant execute on function private.is_active_user() to authenticated;

create or replace function private.current_role()
returns public.mort_role
language sql stable security definer
set search_path = ''
as $$
  select p.role from public.profiles p where p.id = (select auth.uid());
$$;
revoke all on function private.current_role() from public, anon;
grant execute on function private.current_role() to authenticated;

create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end $$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, role, account_status)
  values (
    new.id,
    nullif(left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 80), ''),
    'pending',
    'pending'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_mort on auth.users;
create trigger on_auth_user_created_mort
after insert on auth.users
for each row execute function private.handle_new_user();

create table if not exists public.role_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_role public.mort_role not null check (requested_role in ('teen','adult')),
  status text not null default 'pending' check (status in ('pending','approved','rejected','withdrawn')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  review_note text,
  unique (user_id, id)
);

create table if not exists public.guardian_links (
  id uuid primary key default gen_random_uuid(),
  teen_user_id uuid not null references public.profiles(id) on delete cascade,
  guardian_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','active','revoked','rejected')),
  initiated_by uuid not null references public.profiles(id) on delete cascade,
  teen_consent_at timestamptz,
  guardian_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (teen_user_id <> guardian_user_id),
  unique (teen_user_id, guardian_user_id)
);

create table if not exists public.verification_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  verification_type text not null check (verification_type in ('age','identity','guardian_consent','school_email','school_id','business')),
  status public.mort_verification_status not null default 'not_started',
  provider text,
  provider_reference text,
  evidence_path text,
  reviewer_id uuid references public.profiles(id) on delete set null,
  reviewer_note text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(title) between 5 and 120),
  description text not null check (char_length(description) between 20 and 5000),
  category text not null check (category in ('yard_work','pet_care','tutoring','household_help','moving_help','tech_help','other')),
  status public.mort_job_status not null default 'draft',
  pay_type text not null default 'fixed' check (pay_type in ('fixed','hourly')),
  pay_amount numeric(10,2) not null check (pay_amount > 0 and pay_amount <= 10000),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes between 5 and 1440),
  city text not null,
  region text not null,
  location_notes text,
  exact_address text,
  age_min integer not null default 13 check (age_min between 13 and 17),
  age_max integer not null default 17 check (age_max between age_min and 17),
  remote_allowed boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  safety_review_status text not null default 'pending' check (safety_review_status in ('pending','approved','rejected','flagged')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  check (ends_at is null or starts_at is null or ends_at > starts_at),
  check (status <> 'open' or safety_review_status = 'approved')
);

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  applicant_id uuid not null references public.profiles(id) on delete restrict,
  status public.mort_application_status not null default 'submitted',
  cover_note text check (cover_note is null or char_length(cover_note) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, applicant_id)
);

create table if not exists public.job_assignments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.jobs(id) on delete restrict,
  application_id uuid not null unique references public.job_applications(id) on delete restrict,
  teen_user_id uuid not null references public.profiles(id) on delete restrict,
  adult_user_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'accepted' check (status in ('accepted','in_progress','awaiting_confirmation','completed','cancelled','disputed')),
  agreed_amount numeric(10,2) not null check (agreed_amount > 0),
  accepted_at timestamptz not null default now(),
  started_at timestamptz,
  completed_by_teen_at timestamptz,
  completed_by_adult_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs(id) on delete set null,
  assignment_id uuid references public.job_assignments(id) on delete set null,
  conversation_type text not null default 'job' check (conversation_type in ('job','support','dispute')),
  status text not null default 'active' check (status in ('active','closed','under_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  muted_at timestamptz,
  primary key (conversation_id, user_id)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 4000),
  attachment_path text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','flagged','blocked','removed')),
  moderation_reason text,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete restrict,
  reported_user_id uuid references public.profiles(id) on delete restrict,
  job_id uuid references public.jobs(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  category text not null check (category in ('harassment','unsafe_meeting','scam','inappropriate_content','privacy','underage_concern','payment','other')),
  description text not null check (char_length(description) between 10 and 4000),
  status text not null default 'open' check (status in ('open','triaged','investigating','resolved','dismissed')),
  severity text not null default 'normal' check (severity in ('low','normal','high','critical')),
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  opened_by uuid not null references public.profiles(id) on delete restrict,
  category text not null check (category in ('work_quality','nonpayment','no_show','safety','scope_change','other')),
  description text not null check (char_length(description) between 10 and 4000),
  status text not null default 'open' check (status in ('open','investigating','awaiting_evidence','resolved','dismissed')),
  resolution text,
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.evidence_files (
  id uuid primary key default gen_random_uuid(),
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  assignment_id uuid references public.job_assignments(id) on delete cascade,
  dispute_id uuid references public.disputes(id) on delete cascade,
  report_id uuid references public.safety_reports(id) on delete cascade,
  storage_path text not null unique,
  content_type text not null,
  file_size_bytes bigint not null check (file_size_bytes between 1 and 26214400),
  sha256 text,
  visibility text not null default 'participants' check (visibility in ('uploader','participants','staff_only')),
  created_at timestamptz not null default now(),
  check (num_nonnulls(assignment_id, dispute_id, report_id) = 1)
);

create table if not exists public.payment_records (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.job_assignments(id) on delete restrict,
  payer_id uuid not null references public.profiles(id) on delete restrict,
  payee_id uuid not null references public.profiles(id) on delete restrict,
  provider text not null default 'stripe' check (provider in ('stripe','manual','other')),
  provider_payment_id text unique,
  amount numeric(10,2) not null check (amount > 0),
  currency text not null default 'usd' check (currency = lower(currency) and char_length(currency) = 3),
  status text not null default 'pending' check (status in ('pending','requires_action','authorized','processing','succeeded','failed','refunded','cancelled')),
  idempotency_key text unique,
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  email_enabled boolean not null default true,
  push_enabled boolean not null default true,
  job_updates boolean not null default true,
  message_updates boolean not null default true,
  safety_alerts boolean not null default true,
  marketing_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null,
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) <= 1000),
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  consent_type text not null check (consent_type in ('terms','privacy','community_guidelines','guardian_consent','data_processing')),
  document_version text not null,
  granted boolean not null,
  recorded_at timestamptz not null default now(),
  revoked_at timestamptz,
  source text not null default 'app'
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_jobs_feed on public.jobs(status, safety_review_status, published_at desc);
create index if not exists idx_jobs_poster on public.jobs(poster_id, created_at desc);
create index if not exists idx_jobs_location on public.jobs(region, city, status);
create index if not exists idx_applications_applicant on public.job_applications(applicant_id, created_at desc);
create index if not exists idx_applications_job on public.job_applications(job_id, status);
create index if not exists idx_assignments_teen on public.job_assignments(teen_user_id, status);
create index if not exists idx_assignments_adult on public.job_assignments(adult_user_id, status);
create index if not exists idx_members_user on public.conversation_members(user_id, conversation_id);
create index if not exists idx_messages_conversation on public.messages(conversation_id, created_at);
create index if not exists idx_reports_status on public.safety_reports(status, severity, created_at);
create index if not exists idx_disputes_status on public.disputes(status, created_at);
create index if not exists idx_evidence_assignment on public.evidence_files(assignment_id);
create index if not exists idx_notifications_user_unread on public.notifications(user_id, created_at desc) where read_at is null;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles for each row execute function private.touch_updated_at();
drop trigger if exists jobs_touch_updated_at on public.jobs;
create trigger jobs_touch_updated_at before update on public.jobs for each row execute function private.touch_updated_at();
drop trigger if exists applications_touch_updated_at on public.job_applications;
create trigger applications_touch_updated_at before update on public.job_applications for each row execute function private.touch_updated_at();
drop trigger if exists guardian_links_touch_updated_at on public.guardian_links;
create trigger guardian_links_touch_updated_at before update on public.guardian_links for each row execute function private.touch_updated_at();
drop trigger if exists verification_cases_touch_updated_at on public.verification_cases;
create trigger verification_cases_touch_updated_at before update on public.verification_cases for each row execute function private.touch_updated_at();
drop trigger if exists conversations_touch_updated_at on public.conversations;
create trigger conversations_touch_updated_at before update on public.conversations for each row execute function private.touch_updated_at();
drop trigger if exists reports_touch_updated_at on public.safety_reports;
create trigger reports_touch_updated_at before update on public.safety_reports for each row execute function private.touch_updated_at();
drop trigger if exists disputes_touch_updated_at on public.disputes;
create trigger disputes_touch_updated_at before update on public.disputes for each row execute function private.touch_updated_at();
drop trigger if exists payments_touch_updated_at on public.payment_records;
create trigger payments_touch_updated_at before update on public.payment_records for each row execute function private.touch_updated_at();

create or replace function private.can_access_conversation(target_conversation uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = target_conversation and cm.user_id = (select auth.uid())
  );
$$;
revoke all on function private.can_access_conversation(uuid) from public, anon;
grant execute on function private.can_access_conversation(uuid) to authenticated;

create or replace function private.can_access_assignment(target_assignment uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.job_assignments a
    where a.id = target_assignment
      and ((select auth.uid()) = a.teen_user_id or (select auth.uid()) = a.adult_user_id
        or private.has_staff_role(array['admin','moderator']::public.mort_role[]))
  );
$$;
revoke all on function private.can_access_assignment(uuid) from public, anon;
grant execute on function private.can_access_assignment(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.role_requests enable row level security;
alter table public.guardian_links enable row level security;
alter table public.verification_cases enable row level security;
alter table public.jobs enable row level security;
alter table public.job_applications enable row level security;
alter table public.job_assignments enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.user_blocks enable row level security;
alter table public.messages enable row level security;
alter table public.safety_reports enable row level security;
alter table public.disputes enable row level security;
alter table public.evidence_files enable row level security;
alter table public.payment_records enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.consents enable row level security;
alter table public.admin_audit_log enable row level security;

-- Default deny: grant only the operations required by the client.
revoke all on all tables in schema public from anon, authenticated;
grant select, insert on public.role_requests to authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, avatar_path, bio, city, region, timezone, onboarding_completed_at, updated_at) on public.profiles to authenticated;
grant select, insert, update on public.guardian_links to authenticated;
grant select, insert on public.verification_cases to authenticated;
grant select, insert, update on public.jobs to authenticated;
grant select, insert, update on public.job_applications to authenticated;
grant select on public.job_assignments to authenticated;
grant select, insert on public.conversations to authenticated;
grant select, insert, update on public.conversation_members to authenticated;
grant select, insert, delete on public.user_blocks to authenticated;
grant select, insert, update on public.messages to authenticated;
grant select, insert on public.safety_reports to authenticated;
grant select, insert on public.disputes to authenticated;
grant select, insert on public.evidence_files to authenticated;
grant select on public.payment_records to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
grant select, insert on public.consents to authenticated;
grant select, insert on public.admin_audit_log to authenticated;

create policy profiles_select_self_or_staff on public.profiles for select to authenticated
using (id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy role_requests_select_self_or_staff on public.role_requests for select to authenticated
using (user_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy role_requests_insert_self on public.role_requests for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'pending' and reviewed_at is null and reviewed_by is null);

create policy guardian_links_select_participants_or_staff on public.guardian_links for select to authenticated
using (teen_user_id = (select auth.uid()) or guardian_user_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy guardian_links_insert_initiator on public.guardian_links for insert to authenticated
with check (initiated_by = (select auth.uid()) and status = 'pending' and ((teen_user_id = (select auth.uid())) or (guardian_user_id = (select auth.uid()))));
create policy guardian_links_update_participant on public.guardian_links for update to authenticated
using (teen_user_id = (select auth.uid()) or guardian_user_id = (select auth.uid()))
with check (teen_user_id = (select auth.uid()) or guardian_user_id = (select auth.uid()));

create policy verification_select_owner_or_staff on public.verification_cases for select to authenticated
using (user_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy verification_insert_owner on public.verification_cases for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'not_started' and reviewer_id is null and reviewed_at is null);

create policy jobs_select_visible on public.jobs for select to authenticated
using (
  poster_id = (select auth.uid())
  or private.has_staff_role(array['admin','moderator']::public.mort_role[])
  or (status = 'open' and safety_review_status = 'approved' and private.is_active_user())
);
create policy jobs_insert_adult on public.jobs for insert to authenticated
with check (
  poster_id = (select auth.uid())
  and private.current_role() = 'adult'
  and private.is_active_user()
  and status in ('draft','open')
  and safety_review_status = 'pending'
);
create policy jobs_update_owner on public.jobs for update to authenticated
using (poster_id = (select auth.uid()) and private.current_role() = 'adult')
with check (poster_id = (select auth.uid()) and private.current_role() = 'adult' and safety_review_status in ('pending','approved','flagged'));

create policy applications_select_parties on public.job_applications for select to authenticated
using (
 applicant_id = (select auth.uid())
 or exists (select 1 from public.jobs j where j.id = job_id and j.poster_id = (select auth.uid()))
 or private.has_staff_role(array['admin','moderator']::public.mort_role[])
);
create policy applications_insert_teen on public.job_applications for insert to authenticated
with check (
 applicant_id = (select auth.uid())
 and private.current_role() = 'teen'
 and private.is_active_user()
 and status = 'submitted'
 and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'open' and j.safety_review_status = 'approved' and j.poster_id <> (select auth.uid()))
);
create policy applications_update_parties on public.job_applications for update to authenticated
using (
 applicant_id = (select auth.uid())
 or exists (select 1 from public.jobs j where j.id = job_id and j.poster_id = (select auth.uid()))
)
with check (
 applicant_id = (select auth.uid())
 or exists (select 1 from public.jobs j where j.id = job_id and j.poster_id = (select auth.uid()))
);

create policy assignments_select_parties on public.job_assignments for select to authenticated
using (teen_user_id = (select auth.uid()) or adult_user_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));

create policy conversations_select_member_or_staff on public.conversations for select to authenticated
using (private.can_access_conversation(id) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy conversations_insert_authenticated on public.conversations for insert to authenticated
with check (private.is_active_user() and private.can_access_conversation(id));

create policy members_select_same_conversation on public.conversation_members for select to authenticated
using (user_id = (select auth.uid()) or private.can_access_conversation(conversation_id) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy members_insert_self on public.conversation_members for insert to authenticated
with check (user_id = (select auth.uid()) and private.is_active_user());

create policy blocks_select_participant on public.user_blocks for select to authenticated
using (blocker_id = (select auth.uid()) or blocked_id = (select auth.uid()));
create policy blocks_insert_self on public.user_blocks for insert to authenticated
with check (blocker_id = (select auth.uid()));
create policy blocks_delete_self on public.user_blocks for delete to authenticated
using (blocker_id = (select auth.uid()));

create policy messages_select_member on public.messages for select to authenticated
using (
 private.can_access_conversation(conversation_id)
 and (deleted_at is null or sender_id = (select auth.uid()))
);
create policy messages_insert_member on public.messages for insert to authenticated
with check (
 sender_id = (select auth.uid())
 and private.can_access_conversation(conversation_id)
 and private.is_active_user()
 and moderation_status = 'pending'
 and not exists (
   select 1 from public.conversation_members cm
   join public.user_blocks b on b.blocker_id = (select auth.uid()) and b.blocked_id = cm.user_id
   where cm.conversation_id = messages.conversation_id
 )
);

create policy reports_select_reporter_or_staff on public.safety_reports for select to authenticated
using (reporter_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy reports_insert_self on public.safety_reports for insert to authenticated
with check (reporter_id = (select auth.uid()) and status = 'open' and assigned_to is null and resolved_at is null);

create policy disputes_select_participant_or_staff on public.disputes for select to authenticated
using (opened_by = (select auth.uid()) or private.can_access_assignment(assignment_id) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy disputes_insert_assignment_participant on public.disputes for insert to authenticated
with check (opened_by = (select auth.uid()) and private.can_access_assignment(assignment_id) and status = 'open' and assigned_to is null);

create policy evidence_select_authorized on public.evidence_files for select to authenticated
using (
 uploaded_by = (select auth.uid())
 or (visibility <> 'staff_only' and assignment_id is not null and private.can_access_assignment(assignment_id))
 or private.has_staff_role(array['admin','moderator']::public.mort_role[])
);
create policy evidence_insert_self on public.evidence_files for insert to authenticated
with check (uploaded_by = (select auth.uid()) and (assignment_id is null or private.can_access_assignment(assignment_id)));

create policy payments_select_parties on public.payment_records for select to authenticated
using (payer_id = (select auth.uid()) or payee_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));

create policy notification_prefs_select_self on public.notification_preferences for select to authenticated using (user_id = (select auth.uid()));
create policy notification_prefs_insert_self on public.notification_preferences for insert to authenticated with check (user_id = (select auth.uid()));
create policy notification_prefs_update_self on public.notification_preferences for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy notifications_select_self on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy notifications_update_self on public.notifications for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy consents_select_self_or_staff on public.consents for select to authenticated using (user_id = (select auth.uid()) or private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy consents_insert_self on public.consents for insert to authenticated with check (user_id = (select auth.uid()));

create policy audit_select_staff on public.admin_audit_log for select to authenticated using (private.has_staff_role(array['admin','moderator']::public.mort_role[]));
create policy audit_insert_staff on public.admin_audit_log for insert to authenticated with check (private.has_staff_role(array['admin','moderator']::public.mort_role[]));

-- Keep role and verification decisions out of client-controlled metadata. The admin service
-- must explicitly grant staff roles in private.user_roles and approve role/verification cases.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
 ('profile-avatars','profile-avatars',false,5242880,array['image/jpeg','image/png','image/webp']),
 ('verification-evidence','verification-evidence',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']),
 ('job-evidence','job-evidence',false,26214400,array['image/jpeg','image/png','image/webp','application/pdf','video/mp4']),
 ('dispute-evidence','dispute-evidence',false,26214400,array['image/jpeg','image/png','image/webp','application/pdf','video/mp4']),
 ('chat-attachments','chat-attachments',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;

create policy mort_profile_avatar_upload_own_folder on storage.objects for insert to authenticated
with check (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy mort_profile_avatar_read_own_folder on storage.objects for select to authenticated
using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy mort_profile_avatar_update_own_folder on storage.objects for update to authenticated
using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy mort_profile_avatar_delete_own_folder on storage.objects for delete to authenticated
using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- These buckets intentionally have no direct client policies yet. Upload/download must be
-- mediated by authorized Edge Functions after metadata and participant checks are implemented.

commit;
