-- Fix consume_username_change_credit ambiguity found by RevenueCat credit QA.
-- Replaces only the RPC body; no table/data changes.

create or replace function public.consume_username_change_credit()
returns table (
  token_credits integer,
  admin_credits integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_credits public.username_change_credits%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  insert into public.username_change_credits (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  select * into v_credits
  from public.username_change_credits c
  where c.user_id = v_user_id
  for update;

  if v_credits.token_credits > 0 then
    update public.username_change_credits c
    set token_credits = c.token_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  elsif v_credits.admin_credits > 0 then
    update public.username_change_credits c
    set admin_credits = c.admin_credits - 1
    where c.user_id = v_user_id
    returning * into v_credits;
  else
    raise exception 'No username change credits available.';
  end if;

  return query select v_credits.token_credits, v_credits.admin_credits;
end;
$$;

grant execute on function public.consume_username_change_credit() to authenticated, service_role;
