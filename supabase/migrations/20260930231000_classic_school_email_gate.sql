-- Teen school email is bound to the confirmed primary Auth email and an
-- independently reviewed exact school/domain assignment. Public directory
-- entries never approve a domain. No production assignments are seeded here.
create table private.school_domain_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  domain_id uuid not null references public.school_domains(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'suspended', 'rejected', 'retired')),
  student_allowed boolean not null default false,
  evidence_source_url text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, domain_id),
  check (
    status <> 'approved' or
    (student_allowed and evidence_source_url ~ '^https://' and reviewed_at is not null)
  )
);
create index school_domain_assignments_domain_idx
  on private.school_domain_assignments(domain_id, status);
alter table private.school_domain_assignments enable row level security;
revoke all on private.school_domain_assignments from public, anon, authenticated;
grant select, insert, update, delete on private.school_domain_assignments to service_role;

create table private.teen_school_email_bindings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete restrict,
  domain_id uuid not null references public.school_domains(id) on delete restrict,
  status text not null default 'verified' check (status in ('verified', 'revoked')),
  verified_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index teen_school_email_bindings_school_idx
  on private.teen_school_email_bindings(school_id, status);
alter table private.teen_school_email_bindings enable row level security;
revoke all on private.teen_school_email_bindings from public, anon, authenticated;
grant select, insert, update, delete on private.teen_school_email_bindings to service_role;

create or replace function private.school_domain_id_for_email(
  p_school_id uuid,
  p_email text,
  p_environment public.verification_environment
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select domain.id
  from public.schools school
  join private.school_domain_assignments assignment
    on assignment.school_id = school.id
  join public.school_domains domain on domain.id = assignment.domain_id
  where school.id = p_school_id
    and school.status = 'listed'
    and domain.environment = p_environment
    and domain.status = 'approved'
    and (domain.expires_at is null or domain.expires_at > now())
    and assignment.status = 'approved'
    and assignment.student_allowed
    and (assignment.expires_at is null or assignment.expires_at > now())
    and lower(domain.normalized_domain) = lower(split_part(btrim(p_email), '@', 2))
    and split_part(btrim(p_email), '@', 3) = ''
    and position('@' in btrim(p_email)) > 1
  order by assignment.reviewed_at desc, domain.id
  limit 1;
$$;
revoke all on function private.school_domain_id_for_email(
  uuid, text, public.verification_environment
) from public, anon, authenticated;

create or replace function public.check_school_email_for_signup(
  p_school_id uuid,
  p_email text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_environment public.verification_environment := 'production';
  v_domain_id uuid;
begin
  if auth.uid() is not null then
    v_environment := private.user_trust_environment(auth.uid());
  end if;
  v_domain_id := private.school_domain_id_for_email(
    p_school_id, p_email, v_environment
  );
  return jsonb_build_object(
    'eligible', v_domain_id is not null,
    'code', case when v_domain_id is not null then 'school_email_eligible'
                 else 'school_email_not_eligible' end
  );
end;
$$;
revoke all on function public.check_school_email_for_signup(uuid, text)
  from public, anon, authenticated;
grant execute on function public.check_school_email_for_signup(uuid, text)
  to anon, authenticated;

create or replace function public.verify_my_school_email(
  p_school_id uuid,
  p_school_email text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_email text;
  v_confirmed_at timestamptz;
  v_domain_id uuid;
  v_environment public.verification_environment;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_profile from public.profiles where id = auth.uid();
  if v_profile.id is null or v_profile.dob is null
     or extract(year from age(current_date, v_profile.dob)) not between 13 and 17
     or (v_profile.role is not null and v_profile.role <> 'teen') then
    return jsonb_build_object('ok', false, 'code', 'teen_age_required');
  end if;
  select lower(btrim(email)), email_confirmed_at
    into v_email, v_confirmed_at
  from auth.users where id = auth.uid() and deleted_at is null;
  if v_email is null or v_confirmed_at is null then
    return jsonb_build_object('ok', false, 'code', 'school_email_not_confirmed');
  end if;
  if lower(btrim(coalesce(p_school_email, ''))) <> v_email then
    return jsonb_build_object('ok', false, 'code', 'school_email_must_match_confirmed_account_email');
  end if;
  v_environment := private.user_trust_environment(auth.uid());
  v_domain_id := private.school_domain_id_for_email(
    p_school_id, v_email, v_environment
  );
  if v_domain_id is null then
    return jsonb_build_object('ok', false, 'code', 'school_email_not_eligible');
  end if;

  insert into private.teen_school_email_bindings (
    user_id, school_id, domain_id, status, verified_at, updated_at, revoked_at
  ) values (
    auth.uid(), p_school_id, v_domain_id, 'verified', now(), now(), null
  ) on conflict (user_id) do update
    set school_id = excluded.school_id,
        domain_id = excluded.domain_id,
        status = 'verified',
        verified_at = now(),
        updated_at = now(),
        revoked_at = null;
  return jsonb_build_object('ok', true, 'code', 'school_email_verified');
end;
$$;
revoke all on function public.verify_my_school_email(uuid, text)
  from public, anon, authenticated;
grant execute on function public.verify_my_school_email(uuid, text) to authenticated;

create or replace function private.has_current_teen_school_email(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.teen_school_email_bindings binding
    join public.profiles profile on profile.id = binding.user_id
    join auth.users auth_user on auth_user.id = binding.user_id
    join public.school_domains domain on domain.id = binding.domain_id
    join private.school_domain_assignments assignment
      on assignment.school_id = binding.school_id
     and assignment.domain_id = binding.domain_id
    join public.schools school on school.id = binding.school_id
    where binding.user_id = p_user_id
      and profile.dob is not null
      and extract(year from age(current_date, profile.dob)) between 13 and 17
      and (profile.role is null or profile.role = 'teen')
      and binding.status = 'verified'
      and binding.revoked_at is null
      and auth_user.deleted_at is null
      and auth_user.email_confirmed_at is not null
      and lower(split_part(auth_user.email, '@', 2)) = domain.normalized_domain
      and domain.environment = private.user_trust_environment(p_user_id)
      and domain.status = 'approved'
      and (domain.expires_at is null or domain.expires_at > now())
      and assignment.status = 'approved'
      and assignment.student_allowed
      and (assignment.expires_at is null or assignment.expires_at > now())
      and school.status = 'listed'
  );
$$;
revoke all on function private.has_current_teen_school_email(uuid)
  from public, anon, authenticated;

comment on table private.school_domain_assignments is
  'Private independently reviewed school/student-domain assignments; directory listing alone grants no eligibility.';
comment on table private.teen_school_email_bindings is
  'Private verified school selection linked to the current confirmed primary Auth email; no public school disclosure.';
