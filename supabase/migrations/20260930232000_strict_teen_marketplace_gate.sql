-- Replaces the existing function in place so all RLS policies and RPCs keep
-- calling the same function OID and inherit the strict teen school gate.
create or replace function private.has_marketplace_identity(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_policy private.trust_policy_versions%rowtype;
  v_required_level smallint;
  v_current_level smallint;
  v_is_business boolean := false;
begin
  select * into v_profile
  from public.profiles profile
  where profile.id = p_user_id;
  if v_profile.id is null or v_profile.account_status <> 'active'
     or (v_profile.blocked_until is not null and v_profile.blocked_until > now()) then
    return false;
  end if;

  if v_profile.role = 'admin' then
    return true;
  end if;

  if v_profile.role is null then
    return false;
  end if;

  if v_profile.role = 'teen'
     and (v_profile.dob is null
          or extract(year from age(current_date, v_profile.dob)) < 18)
     and not private.has_current_teen_school_email(p_user_id) then
    return false;
  end if;

  if v_profile.is_test_account then
    return private.has_current_sandbox_identity(p_user_id);
  end if;

  select * into v_policy from private.current_trust_policy();
  if v_policy.id is null or not v_policy.production_marketplace_enabled then
    return false;
  end if;

  if cardinality(v_policy.pilot_account_allowlist) > 0
     and not (p_user_id = any(v_policy.pilot_account_allowlist)) then
    return false;
  end if;
  if v_policy.pilot_region is not null
     and upper(coalesce(v_profile.state, '')) <> upper(v_policy.pilot_region) then
    return false;
  end if;

  select exists (
    select 1 from public.adult_profiles adult
    where adult.user_id = p_user_id
      and nullif(btrim(adult.business_name), '') is not null
  ) into v_is_business;

  v_required_level := case
    when v_profile.role = 'teen' then v_policy.minimum_teen_trust_level
    when v_is_business then v_policy.minimum_business_trust_level
    else v_policy.minimum_adult_trust_level
  end;
  v_current_level := private.compute_account_trust_level(p_user_id);

  if v_current_level < v_required_level then
    return false;
  end if;
  if v_policy.require_provider_verification
     and not private.has_current_production_identity(p_user_id) then
    return false;
  end if;
  if v_policy.require_digital_government_id and not exists (
    select 1 from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.signal_type = 'digital_government_id'
      and signal.environment = 'production'
      and signal.status = 'verified'
      and signal.revoked_at is null
      and (signal.expires_at is null or signal.expires_at > now())
  ) then
    return false;
  end if;
  if v_policy.require_enhanced_adult_screening
     and v_profile.role in ('adult', 'guardian')
     and not exists (
       select 1 from public.trust_signal_events signal
       where signal.user_id = p_user_id
         and signal.signal_type = 'enhanced_adult_screening'
         and signal.environment = 'production'
         and signal.status = 'verified'
         and signal.revoked_at is null
         and (signal.expires_at is null or signal.expires_at > now())
     ) then
    return false;
  end if;
  if v_policy.require_business_registry_match and v_is_business and not exists (
    select 1 from public.trust_signal_events signal
    where signal.user_id = p_user_id
      and signal.signal_type = 'business_registry_match'
      and signal.environment = 'production'
      and signal.status = 'verified'
      and signal.revoked_at is null
      and (signal.expires_at is null or signal.expires_at > now())
  ) then
    return false;
  end if;

  return true;
end;
$$;
