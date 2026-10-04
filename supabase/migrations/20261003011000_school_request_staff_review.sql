-- Staff may triage private suggestions. This workflow cannot list a school,
-- approve a student domain, or mark a suggestion accepted.
create table private.school_directory_request_review_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references private.school_directory_requests(id)
    on delete restrict,
  reviewer_id uuid references public.profiles(id) on delete set null,
  previous_status text not null,
  next_status text not null check (next_status in ('reviewing', 'rejected')),
  review_note text not null check (char_length(review_note) between 10 and 1000),
  created_at timestamptz not null default now()
);
create index school_directory_request_review_events_request_idx
  on private.school_directory_request_review_events(request_id, created_at);
alter table private.school_directory_request_review_events enable row level security;
revoke all on private.school_directory_request_review_events
  from public, anon, authenticated;
grant select, insert on private.school_directory_request_review_events
  to service_role;

create function public.admin_list_school_directory_requests(
  p_status text default 'pending',
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_items jsonb;
begin
  if v_actor is null or auth.role() is distinct from 'authenticated'
     or not public.is_admin()
     or not public.is_profile_active(v_actor) then
    return jsonb_build_object('ok', false, 'code', 'admin_required');
  end if;
  if p_status is null
     or p_status not in ('pending', 'reviewing', 'rejected', 'accepted')
     or p_limit is null or p_limit not between 1 and 100
     or p_offset is null or p_offset not between 0 and 100000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_filter');
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(item) order by item.created_at desc, item.id desc),
    '[]'::jsonb
  )
    into v_items
  from (
    select id, requested_school_name, requested_city, requested_state,
           school_website, suggested_student_domain, status, review_notes,
           reviewed_at, created_at
    from private.school_directory_requests
    where status = p_status
    order by created_at desc, id desc
    limit p_limit
    offset p_offset
  ) as item;
  return jsonb_build_object('ok', true, 'items', v_items);
end;
$$;
revoke all on function public.admin_list_school_directory_requests(
  text, integer, integer
)
  from public, anon, authenticated;
grant execute on function public.admin_list_school_directory_requests(
  text, integer, integer
)
  to authenticated;

create function public.admin_triage_school_directory_request(
  p_request_id uuid,
  p_decision text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_previous text;
  v_note text := btrim(coalesce(p_note, ''));
begin
  if v_actor is null or auth.role() is distinct from 'authenticated'
     or not public.is_admin()
     or not public.is_profile_active(v_actor) then
    return jsonb_build_object('ok', false, 'code', 'admin_required');
  end if;
  if p_request_id is null or p_decision is null
     or p_decision not in ('reviewing', 'rejected')
     or char_length(v_note) not between 10 and 1000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_review');
  end if;

  select status into v_previous
  from private.school_directory_requests
  where id = p_request_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'request_not_found');
  end if;
  if v_previous not in ('pending', 'reviewing') then
    return jsonb_build_object('ok', false, 'code', 'request_closed');
  end if;

  update private.school_directory_requests
  set status = p_decision,
      review_notes = v_note,
      reviewed_by = v_actor,
      reviewed_at = pg_catalog.clock_timestamp(),
      updated_at = pg_catalog.clock_timestamp()
  where id = p_request_id;
  insert into private.school_directory_request_review_events (
    request_id, reviewer_id, previous_status, next_status, review_note
  ) values (p_request_id, v_actor, v_previous, p_decision, v_note);
  return jsonb_build_object('ok', true, 'code', 'review_recorded');
end;
$$;
revoke all on function public.admin_triage_school_directory_request(
  uuid, text, text
) from public, anon, authenticated;
grant execute on function public.admin_triage_school_directory_request(
  uuid, text, text
) to authenticated;
