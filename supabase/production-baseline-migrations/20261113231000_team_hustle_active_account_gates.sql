-- Team-hustle discovery and participation are limited to active accounts.
create or replace function public.create_team_hustle_v1(
  p_title text,
  p_description text,
  p_category text,
  p_pay_type text,
  p_pay_amount numeric,
  p_workers_needed integer,
  p_city text,
  p_region text,
  p_location_notes text
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
  v_role public.mort_role;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not private.is_active_user() then
    return jsonb_build_object('ok', false, 'code', 'active_account_required');
  end if;
  select p.role into v_role from public.profiles p where p.id = v_user;
  if v_role is distinct from 'adult'::public.mort_role
     and not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'adult_required');
  end if;
  -- Serialize per-user quota checks so concurrent create requests cannot exceed limits.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text, 0));
  if p_title is null or length(btrim(p_title)) < 3 or length(btrim(p_title)) > 120 then
    return jsonb_build_object('ok', false, 'code', 'invalid_title');
  end if;
  if p_description is null or length(btrim(p_description)) < 10 or length(btrim(p_description)) > 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_description');
  end if;
  if p_pay_type is null or p_pay_type not in ('per_person','total_split') then
    return jsonb_build_object('ok', false, 'code', 'invalid_pay_type');
  end if;
  if p_pay_amount is not null and (p_pay_amount < 1 or p_pay_amount > 10000) then
    return jsonb_build_object('ok', false, 'code', 'invalid_pay_amount');
  end if;
  if p_workers_needed is null or p_workers_needed < 2 or p_workers_needed > 10 then
    return jsonb_build_object('ok', false, 'code', 'invalid_workers_needed');
  end if;
  if p_region is not null and length(btrim(p_region)) <> 2 then
    return jsonb_build_object('ok', false, 'code', 'invalid_region');
  end if;
  if (select count(*) from public.team_hustles th where th.poster_id = v_user and th.status = 'open') >= 10 then
    return jsonb_build_object('ok', false, 'code', 'too_many_open_hustles');
  end if;
  if (select count(*) from public.team_hustles th where th.poster_id = v_user and th.created_at > now() - interval '24 hours') >= 5 then
    return jsonb_build_object('ok', false, 'code', 'too_many_posts_today');
  end if;
  insert into public.team_hustles (
    poster_id, title, description, category, pay_type, pay_amount,
    workers_needed, city, region, location_notes
  ) values (
    v_user, btrim(p_title), btrim(p_description), nullif(btrim(coalesce(p_category,'')),''),
    p_pay_type, p_pay_amount, p_workers_needed,
    nullif(btrim(coalesce(p_city,'')),''), upper(nullif(btrim(coalesce(p_region,'')),'')),
    nullif(btrim(coalesce(p_location_notes,'')),'')
  );
  insert into public.admin_audit_log (actor_id, action, target_type, target_id, reason, metadata)
  values (v_user, 'team_hustle_created', 'team_hustle', p_title, null,
          jsonb_build_object('workers_needed', p_workers_needed, 'pay_type', p_pay_type));
  return jsonb_build_object('ok', true);
end;
$function$;

create or replace function public.join_team_hustle_v1(p_hustle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
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
  select p.role, p.date_of_birth into v_role, v_dob from public.profiles p where p.id = v_user;
  v_age := case when v_dob is null then null else private.mort_age_years(v_dob) end;
  if v_role <> 'teen' or v_age is null or v_age not between 13 and 17 then
    return jsonb_build_object('ok', false, 'code', 'teen_required');
  end if;
  -- Serialize this teen's daily join quota across different hustles.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text, 0));
  -- Lock the target hustle so concurrent joins cannot overfill its capacity.
  select * into v_hustle from public.team_hustles th where th.id = p_hustle_id for update;
  if not found then return jsonb_build_object('ok', false, 'code', 'not_found'); end if;
  if v_hustle.status <> 'open' then return jsonb_build_object('ok', false, 'code', 'hustle_closed'); end if;
  if v_hustle.poster_id = v_user then return jsonb_build_object('ok', false, 'code', 'cannot_join_own_hustle'); end if;
  if v_age < v_hustle.age_min or v_age > v_hustle.age_max then return jsonb_build_object('ok', false, 'code', 'age_out_of_range'); end if;
  if exists (select 1 from public.team_hustle_members m where m.hustle_id = p_hustle_id and m.user_id = v_user) then
    return jsonb_build_object('ok', false, 'code', 'already_member');
  end if;
  if (select count(*) from public.team_hustle_members m where m.hustle_id = p_hustle_id) >= v_hustle.workers_needed then
    return jsonb_build_object('ok', false, 'code', 'hustle_full');
  end if;
  if (select count(*) from public.team_hustle_members m where m.user_id = v_user and m.joined_at > now() - interval '24 hours') >= 20 then
    return jsonb_build_object('ok', false, 'code', 'too_many_joins_today');
  end if;
  insert into public.team_hustle_members (hustle_id, user_id) values (p_hustle_id, v_user);
  return jsonb_build_object('ok', true);
end;
$function$;

create or replace function public.list_team_hustles_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not private.is_active_user() then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(row_to_json(h) order by (h.status = 'open') desc, h.created_at desc)
    from (
      select th.id, th.title, th.description, th.category, th.city, th.region,
        th.workers_needed, th.age_min, th.age_max, th.pay_amount, th.pay_type,
        th.status, th.created_at,
        (select count(*) from public.team_hustle_members m where m.hustle_id = th.id)::int as joined_count,
        p.display_name as poster_display_name,
        exists(select 1 from public.team_hustle_members m where m.hustle_id = th.id and m.user_id = v_user) as my_membership,
        (th.poster_id = v_user) as i_am_poster
      from public.team_hustles th join public.profiles p on p.id = th.poster_id
      where th.created_at > now() - interval '60 days'
      order by (th.status = 'open') desc, th.created_at desc
      limit 50
    ) h
  ), '[]'::jsonb);
end;
$function$;

alter policy team_hustles_select_authenticated
on public.team_hustles
using (private.is_active_user());
