-- mort_payments_disabled_zero_fee
-- MORT's closed pilot records an offered job amount but does not process money,
-- collect a platform fee, or store personal payment handles. Future payment
-- infrastructure remains server-only and disabled by runtime controls.

update private.runtime_feature_controls
set payments_disabled = true,
    public_marketplace_closed = true,
    update_reason = 'Production-readiness 0.9.7 keeps payments and public marketplace disabled.',
    updated_at = now()
where singleton;

update private.stripe_runtime_controls
set adult_service_fee_bps = 0,
    adult_service_fee_fixed_cents = 0,
    updated_at = now()
where singleton;

update public.jobs
set adult_job_amount_cents = coalesce(adult_job_amount_cents, pay_amount_cents),
    mort_service_fee_cents = case
      when coalesce(adult_job_amount_cents, pay_amount_cents) is null then null
      else 0
    end,
    pay_amount_cents = coalesce(adult_job_amount_cents, pay_amount_cents)
where adult_job_amount_cents is not null
   or pay_amount_cents is not null;

alter table public.jobs
  drop constraint if exists jobs_mort_fee_breakdown_consistent,
  add constraint jobs_mort_fee_breakdown_consistent check (
    (
      adult_job_amount_cents is null
      and mort_service_fee_cents is null
      and pay_amount_cents is null
    )
    or (
      adult_job_amount_cents > 0
      and mort_service_fee_cents = 0
      and pay_amount_cents = adult_job_amount_cents
    )
  );

create or replace function private.enforce_mort_job_fee_breakdown()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.adult_job_amount_cents is null then
    if new.pay_amount_cents is null then
      new.mort_service_fee_cents := null;
    else
      new.adult_job_amount_cents := new.pay_amount_cents;
      new.mort_service_fee_cents := 0;
    end if;
  else
    new.mort_service_fee_cents := 0;
    new.pay_amount_cents := new.adult_job_amount_cents;
  end if;
  return new;
end;
$$;

comment on column public.jobs.adult_job_amount_cents is
  'Offered job amount in integer cents. MORT does not process or guarantee payment.';
comment on column public.jobs.mort_service_fee_cents is
  'MORT platform fee in integer cents. Zero while marketplace payments are disabled.';
comment on column public.jobs.pay_amount_cents is
  'Offered compensation shown to the applicant; equal to the offered job amount while payments are disabled.';

alter function public.save_job_draft_or_publish(uuid, uuid, jsonb, boolean)
rename to save_job_draft_or_publish_fixed_fee_v2;

revoke all on function public.save_job_draft_or_publish_fixed_fee_v2(
  uuid, uuid, jsonb, boolean
) from public, anon, authenticated;
grant execute on function public.save_job_draft_or_publish_fixed_fee_v2(
  uuid, uuid, jsonb, boolean
) to service_role;

create function public.save_job_draft_or_publish(
  p_job_id uuid,
  p_client_request_id uuid,
  p_payload jsonb,
  p_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_offered_amount integer;
  v_result jsonb;
  v_job_id uuid;
  v_job public.jobs%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_values');
  end if;

  begin
    v_offered_amount := nullif(
      p_payload->>'adult_job_amount_cents',
      ''
    )::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
  end;

  if v_offered_amount is not null then
    if v_offered_amount <= 0 or v_offered_amount > 10000000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
    end if;
  elsif p_publish then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
  end if;

  p_payload := (
    p_payload
    - 'pay_amount_cents'
    - 'mort_service_fee_cents'
  ) || jsonb_build_object('pay_amount_cents', v_offered_amount);

  v_result := public.save_job_draft_or_publish_without_fee_v1(
    p_job_id,
    p_client_request_id,
    p_payload,
    p_publish
  );
  if coalesce((v_result->>'ok')::boolean, false) is not true then
    return v_result;
  end if;

  begin
    v_job_id := (v_result#>>'{job,id}')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_response');
  end;

  update public.jobs
  set adult_job_amount_cents = v_offered_amount,
      mort_service_fee_cents = case
        when v_offered_amount is null then null
        else 0
      end,
      pay_amount_cents = v_offered_amount,
      updated_at = now()
  where id = v_job_id
    and (poster_id = auth.uid() or public.is_admin())
  returning * into v_job;

  if v_job.id is null then
    return jsonb_build_object('ok', false, 'code', 'unknown_permission_failure');
  end if;

  return (v_result - 'job') || jsonb_build_object('job', to_jsonb(v_job));
end;
$$;

revoke all on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) from public, anon;
grant execute on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) to authenticated, service_role;

-- Existing personal handles are deliberately redacted after the private backup.
update public.payment_preferences
set preference = 'none',
    cash_app_tag = null,
    square_url = null,
    note = null,
    updated_at = now()
where preference <> 'none'
   or cash_app_tag is not null
   or square_url is not null
   or note is not null;

update public.profiles
set payment_preference = 'none',
    updated_at = now()
where payment_preference <> 'none';

drop policy if exists payment_preferences_upsert_owner
on public.payment_preferences;

revoke insert, update, delete on public.payment_preferences
from authenticated;

alter table public.payment_preferences
  drop constraint if exists payment_preferences_disabled_no_handles,
  add constraint payment_preferences_disabled_no_handles check (
    preference = 'none'
    and cash_app_tag is null
    and square_url is null
    and note is null
  );
