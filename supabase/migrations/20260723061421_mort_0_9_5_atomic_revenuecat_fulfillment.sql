-- RevenueCat fulfillment is serialized and committed in one database transaction.
-- The Edge Function authenticates the provider request; only service_role can call
-- this RPC. Client roles cannot write provider events, product state, or credits.

alter table public.revenuecat_events
  add column if not exists event_timestamp timestamptz,
  add column if not exists payload_sha256 text;

create table if not exists public.revenuecat_product_states (
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null,
  active boolean not null default false,
  entitlements text[] not null default '{}',
  active_until timestamptz,
  last_event_id text not null,
  last_event_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, product_id),
  constraint revenuecat_product_states_product_length
    check (char_length(product_id) between 1 and 100),
  constraint revenuecat_product_states_event_length
    check (char_length(last_event_id) between 8 and 200),
  constraint revenuecat_product_states_entitlements_no_blank
    check (array_position(entitlements, '') is null)
);

alter table public.revenuecat_product_states enable row level security;

create policy revenuecat_product_states_select_own_or_admin
on public.revenuecat_product_states
for select to authenticated
using (user_id = (select auth.uid()) or public.is_admin());

create index if not exists revenuecat_product_states_active_idx
on public.revenuecat_product_states (user_id, active, last_event_at desc);

create or replace function public.process_revenuecat_provider_event(
  p_event_id text,
  p_app_user_id uuid,
  p_event_type text,
  p_product_id text,
  p_entitlement_ids text[],
  p_active_until timestamptz,
  p_event_timestamp timestamptz,
  p_payload_sha256 text,
  p_normalized_event jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_event_row_id uuid;
  v_existing_hash text;
  v_user_exists boolean := false;
  v_persistent_entitlements text[] := '{}';
  v_next_entitlements text[] := '{}';
  v_next_active_until timestamptz;
  v_current_product_id text;
  v_is_addition boolean := false;
  v_is_removal boolean := false;
  v_state_changed boolean := false;
  v_processing_action text := 'revenuecat_event_recorded';
begin
  if p_event_id is null
    or p_event_id !~ '^[A-Za-z0-9._:-]{8,200}$'
    or p_event_type is null
    or p_event_type !~ '^[a-z_]{3,80}$'
    or p_event_timestamp is null
    or p_payload_sha256 !~ '^[0-9a-f]{64}$'
    or p_normalized_event is null
    or jsonb_typeof(p_normalized_event) <> 'object'
  then
    raise exception using errcode = '22023', message = 'Invalid RevenueCat event envelope.';
  end if;

  if p_event_type <> all (array[
    'billing_issue', 'cancellation', 'expiration', 'initial_purchase',
    'invoice_issuance', 'non_renewing_purchase', 'product_change', 'refund',
    'renewal', 'revocation', 'subscription_extended', 'subscription_paused',
    'temporary_entitlement_grant', 'temporary_entitlement_grant_expired',
    'test', 'transfer', 'uncancellation', 'virtual_currency_transaction'
  ]::text[]) then
    raise exception using errcode = '22023', message = 'Unsupported RevenueCat event type.';
  end if;

  if p_product_id is not null and p_product_id <> all (array[
    'mort_plus_monthly', 'mort_plus_yearly', 'mort_plus_lifetime',
    'mort_ad_free_lifetime', 'mort_username_change_token_1',
    'mort_profile_style_pack', 'mort_adult_pro_monthly',
    'mort_guardian_plus_monthly', 'mort_job_boost_1'
  ]::text[]) then
    raise exception using errcode = '22023', message = 'Unsupported RevenueCat product.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_entitlement_ids, '{}'::text[])) as entitlement(value)
    where entitlement.value <> all (array[
      'mort_plus', 'mort_ad_free', 'mort_adult_pro', 'mort_guardian_plus',
      'mort_lifetime', 'mort_profile_style_pack',
      'mort_username_change_token', 'mort_job_boost'
    ]::text[])
  ) then
    raise exception using errcode = '22023', message = 'Unsupported RevenueCat entitlement.';
  end if;

  select exists (
    select 1 from public.profiles where id = p_app_user_id
  ) into v_user_exists;

  insert into public.revenuecat_events (
    revenuecat_event_id,
    app_user_id,
    event_type,
    product_id,
    entitlement_ids,
    raw_event,
    event_timestamp,
    payload_sha256
  ) values (
    p_event_id,
    case when v_user_exists then p_app_user_id else null end,
    p_event_type,
    p_product_id,
    coalesce(p_entitlement_ids, '{}'::text[]),
    p_normalized_event,
    p_event_timestamp,
    p_payload_sha256
  )
  on conflict (revenuecat_event_id) do nothing
  returning id into v_event_row_id;

  if v_event_row_id is null then
    select payload_sha256
    into v_existing_hash
    from public.revenuecat_events
    where revenuecat_event_id = p_event_id;

    return jsonb_build_object(
      'ok', v_existing_hash is null or v_existing_hash = p_payload_sha256,
      'processed', false,
      'code', case
        when v_existing_hash is not null and v_existing_hash <> p_payload_sha256
          then 'duplicate_payload_mismatch'
        else 'duplicate_event'
      end
    );
  end if;

  if not v_user_exists then
    update public.revenuecat_events
    set processed_at = now(),
        processing_error = 'RevenueCat app_user_id did not match a MORT profile.'
    where id = v_event_row_id;

    return jsonb_build_object(
      'ok', true,
      'processed', false,
      'code', 'invalid_app_user_id'
    );
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_app_user_id::text, 0));

  v_persistent_entitlements := case p_product_id
    when 'mort_plus_monthly' then array['mort_plus', 'mort_ad_free']
    when 'mort_plus_yearly' then array['mort_plus', 'mort_ad_free']
    when 'mort_plus_lifetime' then array['mort_plus', 'mort_ad_free', 'mort_lifetime']
    when 'mort_ad_free_lifetime' then array['mort_ad_free']
    when 'mort_profile_style_pack' then array['mort_profile_style_pack']
    when 'mort_adult_pro_monthly' then array['mort_adult_pro']
    when 'mort_guardian_plus_monthly' then array['mort_guardian_plus']
    else '{}'::text[]
  end;

  v_is_addition := p_event_type = any (array[
    'initial_purchase', 'non_renewing_purchase', 'product_change', 'renewal',
    'subscription_extended', 'temporary_entitlement_grant', 'uncancellation'
  ]::text[]);
  v_is_removal := p_event_type = any (array[
    'expiration', 'refund', 'revocation', 'temporary_entitlement_grant_expired'
  ]::text[]);

  if p_product_id is not null
    and cardinality(v_persistent_entitlements) > 0
    and (v_is_addition or v_is_removal)
  then
    insert into public.revenuecat_product_states (
      user_id,
      product_id,
      active,
      entitlements,
      active_until,
      last_event_id,
      last_event_at
    ) values (
      p_app_user_id,
      p_product_id,
      v_is_addition,
      v_persistent_entitlements,
      case when v_is_addition then p_active_until else null end,
      p_event_id,
      p_event_timestamp
    )
    on conflict (user_id, product_id) do update
    set active = excluded.active,
        entitlements = excluded.entitlements,
        active_until = excluded.active_until,
        last_event_id = excluded.last_event_id,
        last_event_at = excluded.last_event_at,
        updated_at = now()
    where excluded.last_event_at >= public.revenuecat_product_states.last_event_at
    returning true into v_state_changed;
  end if;

  if v_state_changed then
    select
      coalesce(
        array_agg(distinct expanded.entitlement order by expanded.entitlement)
          filter (where expanded.entitlement is not null),
        '{}'::text[]
      ),
      max(state.active_until)
    into v_next_entitlements, v_next_active_until
    from public.revenuecat_product_states state
    left join lateral unnest(state.entitlements) as expanded(entitlement) on true
    where state.user_id = p_app_user_id
      and state.active
      and (state.active_until is null or state.active_until > now());

    select state.product_id
    into v_current_product_id
    from public.revenuecat_product_states state
    where state.user_id = p_app_user_id
      and state.active
      and (state.active_until is null or state.active_until > now())
    order by state.last_event_at desc, state.product_id
    limit 1;

    insert into public.monetization_entitlements_cache (
      user_id,
      entitlements,
      active_until,
      source,
      last_revenuecat_event_id,
      refreshed_at
    ) values (
      p_app_user_id,
      v_next_entitlements,
      v_next_active_until,
      'revenuecat',
      p_event_id,
      now()
    )
    on conflict (user_id) do update
    set entitlements = excluded.entitlements,
        active_until = excluded.active_until,
        source = excluded.source,
        last_revenuecat_event_id = excluded.last_revenuecat_event_id,
        refreshed_at = excluded.refreshed_at;

    insert into public.user_subscription_status (
      user_id,
      premium_active,
      ad_free_active,
      adult_pro_active,
      business_boost_active,
      guardian_plus_active,
      current_product_id,
      current_period_ends_at,
      source
    ) values (
      p_app_user_id,
      v_next_entitlements && array['mort_plus', 'mort_lifetime'],
      v_next_entitlements && array['mort_ad_free', 'mort_plus', 'mort_lifetime'],
      'mort_adult_pro' = any(v_next_entitlements),
      false,
      'mort_guardian_plus' = any(v_next_entitlements),
      v_current_product_id,
      v_next_active_until,
      'revenuecat'
    )
    on conflict (user_id) do update
    set premium_active = excluded.premium_active,
        ad_free_active = excluded.ad_free_active,
        adult_pro_active = excluded.adult_pro_active,
        business_boost_active = excluded.business_boost_active,
        guardian_plus_active = excluded.guardian_plus_active,
        current_product_id = excluded.current_product_id,
        current_period_ends_at = excluded.current_period_ends_at,
        source = excluded.source;

    v_processing_action := case
      when v_is_removal then 'revenuecat_entitlement_removed'
      else 'revenuecat_event_processed'
    end;
  end if;

  if p_event_type = 'non_renewing_purchase'
    and p_product_id = 'mort_username_change_token_1'
  then
    insert into public.username_change_credits (user_id, token_credits)
    values (p_app_user_id, 1)
    on conflict (user_id) do update
    set token_credits = public.username_change_credits.token_credits + 1;
    v_processing_action := 'username_change_token_granted';
  elsif p_event_type = 'non_renewing_purchase'
    and p_product_id = 'mort_job_boost_1'
  then
    insert into public.job_boost_credits (
      user_id,
      available_credits,
      last_revenuecat_event_id
    ) values (
      p_app_user_id,
      1,
      p_event_id
    )
    on conflict (user_id) do update
    set available_credits = public.job_boost_credits.available_credits + 1,
        last_revenuecat_event_id = excluded.last_revenuecat_event_id;
    v_processing_action := 'job_boost_credit_granted';
  elsif p_event_type = 'non_renewing_purchase'
    and p_product_id = 'mort_profile_style_pack'
  then
    insert into public.profile_theme_unlocks (user_id, theme_key, source)
    values (p_app_user_id, 'mort_profile_style_pack', 'revenuecat')
    on conflict (user_id, theme_key) do nothing;
    v_processing_action := 'profile_style_pack_granted';
  end if;

  insert into public.purchase_audit_logs (
    user_id,
    source,
    action,
    product_id,
    entitlement_id,
    details
  ) values (
    p_app_user_id,
    'revenuecat',
    v_processing_action,
    p_product_id,
    v_persistent_entitlements[1],
    jsonb_build_object(
      'revenuecat_event_id', p_event_id,
      'event_type', p_event_type,
      'state_changed', v_state_changed
    )
  );

  update public.revenuecat_events
  set processed_at = now(), processing_error = null
  where id = v_event_row_id;

  return jsonb_build_object(
    'ok', true,
    'processed', true,
    'code', 'processed',
    'state_changed', v_state_changed,
    'action', v_processing_action
  );
end;
$$;

revoke all on public.revenuecat_product_states from public, anon;
grant select on public.revenuecat_product_states to authenticated;
grant select, insert, update, delete on public.revenuecat_product_states to service_role;

revoke all on function public.process_revenuecat_provider_event(
  text, uuid, text, text, text[], timestamptz, timestamptz, text, jsonb
) from public, anon, authenticated;
grant execute on function public.process_revenuecat_provider_event(
  text, uuid, text, text, text[], timestamptz, timestamptz, text, jsonb
) to service_role;
