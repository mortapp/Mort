-- School suggestions are private review data. Submission never lists a school
-- or approves an email domain, and it creates no Auth identity.
create table private.school_directory_requests (
  id uuid primary key default gen_random_uuid(),
  requested_school_name text not null
    check (char_length(btrim(requested_school_name)) between 3 and 180),
  requested_city text not null
    check (char_length(btrim(requested_city)) between 2 and 100),
  requested_state text not null check (requested_state ~ '^[A-Z]{2}$'),
  school_website text check (
    school_website is null or
    (char_length(school_website) <= 300 and school_website ~ '^https://')
  ),
  suggested_student_domain text check (
    suggested_student_domain is null or
    (char_length(suggested_student_domain) <= 253 and
     suggested_student_domain ~ '^[a-z0-9][a-z0-9.-]*[a-z0-9]$')
  ),
  status text not null default 'pending'
    check (status in ('pending', 'reviewing', 'accepted', 'rejected')),
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index school_directory_requests_unique_suggestion_idx
  on private.school_directory_requests (
    lower(btrim(requested_school_name)),
    lower(btrim(requested_city)),
    requested_state
  );
create index school_directory_requests_review_idx
  on private.school_directory_requests(status, created_at);
alter table private.school_directory_requests enable row level security;
revoke all on private.school_directory_requests from public, anon, authenticated;
grant select, insert, update, delete on private.school_directory_requests to service_role;

create or replace function public.request_school_directory_entry(
  p_school_name text,
  p_city text,
  p_state text,
  p_website text default null,
  p_student_domain text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_school_name, ''));
  v_city text := btrim(coalesce(p_city, ''));
  v_state text := upper(btrim(coalesce(p_state, '')));
  v_website text := nullif(btrim(coalesce(p_website, '')), '');
  v_domain text := nullif(lower(btrim(coalesce(p_student_domain, ''))), '');
begin
  if char_length(v_name) not between 3 and 180
     or char_length(v_city) not between 2 and 100
     or v_state !~ '^[A-Z]{2}$'
     or (v_website is not null and
         (char_length(v_website) > 300 or v_website !~ '^https://'))
     or (v_domain is not null and
         (char_length(v_domain) > 253 or
          v_domain !~ '^[a-z0-9][a-z0-9.-]*[a-z0-9]$')) then
    return jsonb_build_object('ok', false, 'code', 'invalid_school_request');
  end if;
  if exists (
    select 1 from public.schools
    where lower(btrim(official_name)) = lower(v_name)
      and lower(btrim(city)) = lower(v_city)
      and state = v_state and status = 'listed'
  ) then
    return jsonb_build_object('ok', false, 'code', 'school_already_listed');
  end if;
  insert into private.school_directory_requests (
    requested_school_name, requested_city, requested_state,
    school_website, suggested_student_domain
  ) values (v_name, v_city, v_state, v_website, v_domain)
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'code', 'request_received');
end;
$$;
revoke all on function public.request_school_directory_entry(
  text, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.request_school_directory_entry(
  text, text, text, text, text
) to anon, authenticated;

comment on table private.school_directory_requests is
  'Private, bounded pre-account school suggestions. No entry or student domain becomes eligible without independent staff review.';
