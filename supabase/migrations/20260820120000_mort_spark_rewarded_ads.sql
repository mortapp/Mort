-- MORT Spark: a purely cosmetic, non-financial reward a user may optionally
-- unlock by watching a rewarded ad to completion. No job ranking, Quick
-- Accept, leaderboard, safety, moderation, marketplace-priority, or job
-- eligibility effect -- profile decoration only. Server-authoritative so
-- the state is correct across devices and cannot be forged client-side;
-- the grant is only ever recorded after the Google Mobile Ads SDK's real
-- onUserEarnedReward callback fires, never on tap.

create table public.mort_spark_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_request_id uuid not null,
  granted_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create unique index mort_spark_grants_request_unique_idx
on public.mort_spark_grants (user_id, client_request_id);

create index mort_spark_grants_user_recent_idx
on public.mort_spark_grants (user_id, granted_at desc);

alter table public.mort_spark_grants enable row level security;

create policy mort_spark_grants_select on public.mort_spark_grants
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

comment on table public.mort_spark_grants is
'Cosmetic-only rewarded-ad grant ledger. No marketplace, safety, ranking, or eligibility effect. Writes only via grant_mort_spark_reward (security definer); no direct insert/update/delete policy exists for any role.';

create or replace function public.grant_mort_spark_reward(
  p_client_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_existing record;
  v_last_granted_at timestamptz;
  v_next_eligible_at timestamptz;
  v_new_id uuid;
  v_new_expires_at timestamptz;
  v_reward_duration constant interval := interval '24 hours';
  v_cooldown constant interval := interval '24 hours';
begin
  if v_user_id is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_client_request_id is null then
    return jsonb_build_object('ok', false, 'code', 'client_request_id_required');
  end if;

  -- Idempotent replay of an already-recorded grant: return it unchanged,
  -- do not re-check cooldown (it is the same event, not a new one).
  select id, expires_at
  into v_existing
  from public.mort_spark_grants
  where user_id = v_user_id
    and client_request_id = p_client_request_id;

  if found then
    return jsonb_build_object(
      'ok', true,
      'grant_id', v_existing.id,
      'expires_at', v_existing.expires_at,
      'replayed', true
    );
  end if;

  if not public.check_rate_limit('mort_spark_reward', 5, 3600) then
    return jsonb_build_object('ok', false, 'code', 'rate_limited');
  end if;

  select granted_at
  into v_last_granted_at
  from public.mort_spark_grants
  where user_id = v_user_id
  order by granted_at desc
  limit 1;

  if v_last_granted_at is not null and v_last_granted_at > now() - v_cooldown then
    v_next_eligible_at := v_last_granted_at + v_cooldown;
    return jsonb_build_object(
      'ok', false,
      'code', 'cooldown_active',
      'next_eligible_at', v_next_eligible_at
    );
  end if;

  perform public.record_rate_limit_event('mort_spark_reward', null);

  insert into public.mort_spark_grants (
    user_id,
    client_request_id,
    granted_at,
    expires_at
  ) values (
    v_user_id,
    p_client_request_id,
    now(),
    now() + v_reward_duration
  )
  on conflict (user_id, client_request_id) do nothing
  returning id, expires_at into v_new_id, v_new_expires_at;

  if v_new_id is null then
    select id, expires_at
    into v_new_id, v_new_expires_at
    from public.mort_spark_grants
    where user_id = v_user_id
      and client_request_id = p_client_request_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'grant_id', v_new_id,
    'expires_at', v_new_expires_at,
    'replayed', false
  );
end;
$$;

revoke all on function public.grant_mort_spark_reward(uuid)
from public, anon;
grant execute on function public.grant_mort_spark_reward(uuid)
to authenticated;

comment on function public.grant_mort_spark_reward(uuid) is
'Grants the caller a 24h cosmetic MORT Spark accent after a real rewarded-ad watch. Idempotent via client_request_id, cooldown-limited to one new grant per 24h, no marketplace/safety/ranking effect.';
