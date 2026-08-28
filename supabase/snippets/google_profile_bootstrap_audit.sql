select pg_catalog.jsonb_build_object(
  'auth_users', (select count(*) from auth.users),
  'profiles', (select count(*) from public.profiles),
  'missing_profiles', (
    select count(*)
    from auth.users as auth_user
    left join public.profiles as profile on profile.id = auth_user.id
    where profile.id is null
  ),
  'google_users', (
    select count(distinct identity.user_id)
    from auth.identities as identity
    where identity.provider = 'google'
  ),
  'google_users_missing_profiles', (
    select count(distinct identity.user_id)
    from auth.identities as identity
    left join public.profiles as profile on profile.id = identity.user_id
    where identity.provider = 'google'
      and profile.id is null
  ),
  'users_with_duplicate_google_identities', (
    select count(*)
    from (
      select identity.user_id
      from auth.identities as identity
      where identity.provider = 'google'
      group by identity.user_id
      having count(*) > 1
    ) as duplicate_google
  ),
  'profiles_with_admin_role', (
    select count(*) from public.profiles as profile where profile.role = 'admin'
  ),
  'bootstrap_trigger_count', (
    select count(*)
    from pg_catalog.pg_trigger
    where tgname = 'on_auth_user_created'
      and tgrelid = 'auth.users'::regclass
      and not tgisinternal
  ),
  'ensure_function_count', (
    select count(*)
    from pg_catalog.pg_proc as procedure
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'ensure_my_profile'
      and procedure.pronargs = 0
  ),
  'profile_repair_events', (
    select count(*)
    from public.account_security_events as event
    where event.event_type in (
      'auth_profile_bootstrap_repaired',
      'auth_profile_backfill_repaired'
    )
  ),
  'repaired_profiles_with_role', (
    select count(*)
    from public.account_security_events as event
    join public.profiles as profile on profile.id = event.user_id
    where event.event_type in (
      'auth_profile_bootstrap_repaired',
      'auth_profile_backfill_repaired'
    )
      and profile.role is not null
  ),
  'repaired_profiles_with_completed_onboarding', (
    select count(*)
    from public.account_security_events as event
    join public.profiles as profile on profile.id = event.user_id
    where event.event_type in (
      'auth_profile_bootstrap_repaired',
      'auth_profile_backfill_repaired'
    )
      and profile.onboarding_completed
  ),
  'repaired_profiles_with_elevated_verification', (
    select count(*)
    from public.account_security_events as event
    join public.profiles as profile on profile.id = event.user_id
    where event.event_type in (
      'auth_profile_bootstrap_repaired',
      'auth_profile_backfill_repaired'
    )
      and profile.verification_status <> 'not_started'
  ),
  'repaired_profiles_with_nonactive_status', (
    select count(*)
    from public.account_security_events as event
    join public.profiles as profile on profile.id = event.user_id
    where event.event_type in (
      'auth_profile_bootstrap_repaired',
      'auth_profile_backfill_repaired'
    )
      and profile.account_status <> 'active'
  )
) as google_profile_bootstrap_audit;
