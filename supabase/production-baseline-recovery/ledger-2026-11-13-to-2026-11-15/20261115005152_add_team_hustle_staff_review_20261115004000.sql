-- Exact statements from production ledger version 20261115005152
-- New team hustles require staff review before they are listed to other users
-- or joinable. Existing posts remain approved to preserve their prior visibility.
BEGIN;

alter table public.team_hustles
  add column if not exists review_status text not null default 'approved',
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null,
  add column if not exists review_note text;

do $migration$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.team_hustles'::regclass
      and conname = 'team_hustles_review_status_check'
  ) then
    alter table public.team_hustles
      add constraint team_hustles_review_status_check
      check (review_status in ('pending','approved','rejected'));
  end if;
end;
$migration$;

alter table public.team_hustles alter column review_status set default 'pending';

create or replace function public.list_team_hustles_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.is_active_user() then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(h) order by (h.status = 'open') desc, h.created_at desc)
    from (
      select
        th.id, th.title, th.description, th.category, th.city, th.region,
        th.workers_needed, th.age_min, th.age_max, th.pay_amount, th.pay_type,
        case
          when th.poster_id = v_user
            or private.has_staff_role(array['admin','moderator']::public.mort_role[])
          then th.location_notes
          else null
        end as location_notes,
        th.status, th.review_status, th.review_note, th.created_at,
        (select count(*) from public.team_hustle_members m
         where m.hustle_id = th.id)::int as joined_count,
        p.display_name as poster_display_name,
        exists(select 1 from public.team_hustle_members m
               where m.hustle_id = th.id and m.user_id = v_user) as my_membership,
        (th.poster_id = v_user) as i_am_poster
      from public.team_hustles th
      join public.profiles p on p.id = th.poster_id
      where th.created_at > now() - interval '60 days'
        and (
          th.review_status = 'approved'
          or th.poster_id = v_user
          or private.has_staff_role(array['admin']::public.mort_role[])
        )
      order by (th.status = 'open') desc, th.created_at desc
      limit 50
    ) h
  ), '[]'::jsonb);
end;
$function$;

create or replace function public.join_team_hustle_v1(p_hustle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
  v_dob date;
  v_age integer;
  v_hustle public.team_hustles%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;

  select p.role, p.date_of_birth into v_role, v_dob
  from public.profiles p where p.id = v_user;
  v_age := case when v_dob is null then null else private.mort_age_years(v_dob) end;
  if v_role <> 'teen' or v_age is null or v_age not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_required');
  end if;

  select * into v_hustle from public.team_hustles th
  where th.id = p_hustle_id
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'not_found');
  end if;
  if v_hustle.review_status <> 'approved' then
    return jsonb_build_object('ok', false, 'code', 'staff_review_required');
  end if;
  if v_hustle.status <> 'open' then
    return jsonb_build_object('ok', false, 'code', 'hustle_closed');
  end if;
  if v_hustle.poster_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'cannot_join_own_hustle');
  end if;
  if v_age < v_hustle.age_min or v_age > v_hustle.age_max then
    return jsonb_build_object('ok', false, 'code', 'age_out_of_range');
  end if;
  if exists (select 1 from public.team_hustle_members m
             where m.hustle_id = p_hustle_id and m.user_id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'already_member');
  end if;
  if (select count(*) from public.team_hustle_members m
      where m.hustle_id = p_hustle_id) >= v_hustle.workers_needed then
    return jsonb_build_object('ok', false, 'code', 'hustle_full');
  end if;
  if (select count(*) from public.team_hustle_members m
      where m.user_id = v_user and m.joined_at > now() - interval '24 hours') >= 20 then
    return jsonb_build_object('ok', false, 'code', 'too_many_joins_today');
  end if;

  insert into public.team_hustle_members (hustle_id, user_id)
  values (p_hustle_id, v_user);
  return jsonb_build_object('ok', true);
end;
$function$;

create or replace function public.admin_review_team_hustle_v1(
  p_hustle_id uuid,
  p_decision text,
  p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_status text;
  v_reason text := nullif(btrim(coalesce(p_reason,'')), '');
begin
  if v_user is null or not private.is_active_user()
     or not private.has_staff_role(array['admin']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'admin_required');
  end if;
  if p_hustle_id is null or p_decision is null
     or p_decision not in ('approve','reject') then
    return jsonb_build_object('ok', false, 'code', 'review_decision_invalid');
  end if;
  if p_decision = 'reject' and (v_reason is null or length(v_reason) < 3) then
    return jsonb_build_object('ok', false, 'code', 'rejection_reason_required');
  end if;
  if v_reason is not null and length(v_reason) > 1000 then
    return jsonb_build_object('ok', false, 'code', 'review_reason_too_long');
  end if;

  v_status := case when p_decision = 'approve' then 'approved' else 'rejected' end;
  update public.team_hustles
  set review_status = v_status,
      reviewed_at = now(),
      reviewed_by = v_user,
      review_note = v_reason
  where id = p_hustle_id and review_status = 'pending';
  if not found then
    return jsonb_build_object('ok', false, 'code', 'team_hustle_not_pending_review');
  end if;

  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'team_hustle_reviewed', 'team_hustle', p_hustle_id::text, v_reason,
          jsonb_build_object('decision', v_status));
  return jsonb_build_object('ok', true, 'review_status', v_status);
end;
$function$;

revoke all on function public.list_team_hustles_v1() from public, anon;
grant execute on function public.list_team_hustles_v1() to authenticated, service_role;
revoke all on function public.join_team_hustle_v1(uuid) from public, anon;
grant execute on function public.join_team_hustle_v1(uuid) to authenticated, service_role;
revoke all on function public.admin_review_team_hustle_v1(uuid,text,text) from public, anon;
grant execute on function public.admin_review_team_hustle_v1(uuid,text,text) to authenticated, service_role;

COMMIT;
