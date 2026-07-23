-- Fix request_username_change ambiguity found by remote RLS QA.
-- Replaces only the RPC body; no table/data changes.

create or replace function public.request_username_change(p_new_username text)
returns table (
  username text,
  source text,
  free_changes_remaining integer,
  token_credits integer,
  admin_credits integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_new_username text := public.normalize_username(p_new_username);
  v_old_username text;
  v_reason text;
  v_credits public.username_change_credits%rowtype;
  v_source text;
  v_has_plus boolean := false;
  v_month date := date_trunc('month', now())::date;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  v_reason := public.validate_username(v_new_username);
  if v_reason is not null then
    raise exception '%', v_reason;
  end if;

  select p.username into v_old_username
  from public.profiles p
  where p.id = v_user_id;

  if v_old_username is not distinct from v_new_username then
    raise exception 'That is already your username.';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.username) = v_new_username and p.id <> v_user_id
  ) then
    raise exception 'That username is already taken.';
  end if;

  insert into public.username_change_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.username_change_credits c
  where c.user_id = v_user_id
  for update;

  select exists (
    select 1
    from public.monetization_entitlements_cache mec
    where mec.user_id = v_user_id
      and mec.entitlements && array['mort_plus', 'mort_lifetime', 'mort_premium']
  ) into v_has_plus;

  if v_credits.free_changes_used < 3 then
    v_source := 'free';
    update public.username_change_credits c
    set free_changes_used = c.free_changes_used + 1
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_has_plus and (v_credits.plus_period_start is null or v_credits.plus_period_start < v_month or v_credits.plus_changes_used < 1) then
    v_source := 'plus_allowance';
    update public.username_change_credits c
    set plus_period_start = v_month,
        plus_changes_used = case when c.plus_period_start is distinct from v_month then 1 else c.plus_changes_used + 1 end
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.token_credits > 0 then
    v_source := 'token';
    update public.username_change_credits c
    set token_credits = c.token_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.admin_credits > 0 then
    v_source := 'admin_credit';
    update public.username_change_credits c
    set admin_credits = c.admin_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  else
    raise exception 'No username changes are available. Use a token, Plus monthly allowance, or admin-approved credit.';
  end if;

  perform set_config('mort.internal_update', 'true', true);

  update public.profiles p
  set username = v_new_username
  where p.id = v_user_id;

  delete from public.username_reservations r
  where r.user_id = v_user_id or r.username = v_new_username;

  insert into public.username_reservations (username, user_id)
  values (v_new_username, v_user_id);

  perform set_config('mort.internal_update', '', true);

  insert into public.username_change_events (user_id, old_username, new_username, source)
  values (v_user_id, v_old_username, v_new_username, v_source);

  return query
  select
    v_new_username,
    v_source,
    greatest(0, 3 - v_credits.free_changes_used),
    v_credits.token_credits,
    v_credits.admin_credits;
exception
  when others then
    perform set_config('mort.internal_update', '', true);
    raise;
end;
$$;

grant execute on function public.request_username_change(text) to authenticated, service_role;
