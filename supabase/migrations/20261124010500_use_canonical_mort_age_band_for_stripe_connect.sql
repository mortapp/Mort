-- Align the Connect authorization RPC with the canonical MORT age-band helper.
create or replace function public.stripe_server_prepare_connected_account(
  p_user_id uuid,
  p_environment text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile public.profiles%rowtype;
  control private.stripe_runtime_controls%rowtype;
  existing private.stripe_connected_accounts%rowtype;
begin
  perform private.require_stripe_service_role();
  select * into control from private.stripe_runtime_controls where singleton for share;

  if p_environment is distinct from private.stripe_environment_for_mode(control.mode) then
    raise exception 'stripe_environment_mismatch';
  end if;
  if not control.stripe_connected_onboarding_enabled or not control.connected_accounts_approved then
    raise exception 'stripe_connected_onboarding_disabled';
  end if;
  if p_environment = 'live'
     and (not control.stripe_live_mode_enabled or not control.live_owner_approved) then
    raise exception 'stripe_live_disabled';
  end if;
  if p_environment = 'test'
     and (control.mode <> 'sandbox' or not control.sandbox_provider_qa_approved
       or control.stripe_live_mode_enabled or control.live_owner_approved) then
    raise exception 'sandbox_provider_qa_not_approved';
  end if;

  select * into profile from public.profiles where id = p_user_id;
  if profile.id is null or profile.role <> 'teen' or profile.account_status <> 'active' then
    raise exception 'eligible_teen_required';
  end if;
  if profile.date_of_birth is null
     or date_part('year', age(current_date, profile.date_of_birth)) < 13
     or date_part('year', age(current_date, profile.date_of_birth)) >= 18 then
    raise exception 'teen_age_required';
  end if;

  if p_environment = 'test' and not exists (
    select 1 from auth.users u
    where u.id = p_user_id and u.email_confirmed_at is not null
      and lower(split_part(u.email, '@', 2)) = 'qa.mortapp.org'
  ) then
    raise exception 'sandbox_test_account_required';
  end if;

  select * into existing from private.stripe_connected_accounts
  where user_id = p_user_id and environment = p_environment;

  return jsonb_build_object(
    'ok', true,
    'existing', existing.id is not null,
    'provider_account_id', existing.provider_account_id,
    'role', 'teen',
    'age_band', private.mort_legal_age_band(profile.date_of_birth)
  );
end;
$$;

revoke all on function public.stripe_server_prepare_connected_account(uuid, text)
  from public, anon, authenticated;
grant execute on function public.stripe_server_prepare_connected_account(uuid, text)
  to service_role;
