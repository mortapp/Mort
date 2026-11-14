-- Protect team-hustle location instructions from unrelated authenticated accounts.
-- Public listing remains available through the allowlisted RPC, but location notes
-- are disclosed only to the poster and authorized staff.

revoke select on table public.team_hustles from authenticated;
-- Production currently has explicit per-column SELECT grants as well as a table grant.
-- Revoking the table grant alone leaves those column grants active.
revoke select (
  id, poster_id, title, description, category, pay_type, pay_amount,
  workers_needed, city, region, location_notes, age_min, age_max,
  status, created_at, updated_at
) on table public.team_hustles from authenticated;

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
        th.status, th.created_at,
        (select count(*) from public.team_hustle_members m
         where m.hustle_id = th.id)::int as joined_count,
        p.display_name as poster_display_name,
        exists(select 1 from public.team_hustle_members m
               where m.hustle_id = th.id and m.user_id = v_user) as my_membership,
        (th.poster_id = v_user) as i_am_poster
      from public.team_hustles th
      join public.profiles p on p.id = th.poster_id
      where th.created_at > now() - interval '60 days'
      order by (th.status = 'open') desc, th.created_at desc
      limit 50
    ) h
  ), '[]'::jsonb);
end;
$function$;

comment on function public.list_team_hustles_v1() is
  'Lists active team hustles; location_notes are returned only to the posting account and authorized staff. Direct authenticated table SELECT is revoked.';
