-- Align team-hustle administrative authorization with the canonical staff grant table.
-- Adult users retain their existing create permission; admin access requires an active
-- private.user_roles grant through private.has_staff_role().

create or replace function public.close_team_hustle_v1(p_hustle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  update public.team_hustles th
  set status = 'closed', updated_at = now()
  where th.id = p_hustle_id
    and (
      th.poster_id = v_user
      or private.has_staff_role(array['admin','moderator']::public.mort_role[])
    );
  if not found then
    return jsonb_build_object('ok', false, 'code', 'not_found_or_not_poster');
  end if;
  return jsonb_build_object('ok', true);
end;
$function$;

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

  select p.role into v_role from public.profiles p where p.id = v_user;
  if v_role is distinct from 'adult'::public.mort_role
     and not private.has_staff_role(array['admin','moderator']::public.mort_role[]) then
    return jsonb_build_object('ok', false, 'code', 'adult_required');
  end if;

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

  if (select count(*) from public.team_hustles th
      where th.poster_id = v_user and th.status = 'open') >= 10 then
    return jsonb_build_object('ok', false, 'code', 'too_many_open_hustles');
  end if;
  if (select count(*) from public.team_hustles th
      where th.poster_id = v_user and th.created_at > now() - interval '24 hours') >= 5 then
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
