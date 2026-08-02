-- Fixed MORT service fee. The mobile client submits only the adult-entered
-- amount; this server wrapper derives the teen payout and ignores any
-- client-supplied payout or fee value.

alter table public.jobs
  add column if not exists adult_job_amount_cents integer,
  add column if not exists mort_service_fee_cents integer;

update public.jobs
set adult_job_amount_cents = pay_amount_cents + 274,
    mort_service_fee_cents = 274
where pay_amount_cents is not null
  and adult_job_amount_cents is null;

alter table public.jobs
  drop constraint if exists jobs_mort_fee_breakdown_consistent,
  add constraint jobs_mort_fee_breakdown_consistent check (
    (
      adult_job_amount_cents is null
      and mort_service_fee_cents is null
      and pay_amount_cents is null
    )
    or (
      adult_job_amount_cents > 274
      and mort_service_fee_cents = 274
      and pay_amount_cents = adult_job_amount_cents - mort_service_fee_cents
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
      -- Preserve trusted legacy/server fixtures by interpreting the existing
      -- pay amount as the teen payout and deriving the gross amount.
      new.mort_service_fee_cents := 274;
      new.adult_job_amount_cents := new.pay_amount_cents + 274;
    end if;
  else
    new.mort_service_fee_cents := 274;
    new.pay_amount_cents := new.adult_job_amount_cents - 274;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_mort_job_fee_breakdown on public.jobs;
create trigger enforce_mort_job_fee_breakdown
before insert or update of adult_job_amount_cents, mort_service_fee_cents,
  pay_amount_cents
on public.jobs
for each row execute function private.enforce_mort_job_fee_breakdown();

revoke execute on function private.enforce_mort_job_fee_breakdown()
from public, anon, authenticated;

comment on column public.jobs.adult_job_amount_cents is
  'Gross amount entered by the adult, stored as integer cents.';
comment on column public.jobs.mort_service_fee_cents is
  'Fixed MORT service fee in integer cents. Currently 274.';
comment on column public.jobs.pay_amount_cents is
  'Teen payout after the MORT service fee, stored as integer cents.';

update private.stripe_runtime_controls
set adult_service_fee_bps = 0,
    adult_service_fee_fixed_cents = 274,
    updated_at = now()
where singleton;

alter function public.save_job_draft_or_publish(uuid, uuid, jsonb, boolean)
rename to save_job_draft_or_publish_without_fee_v1;

revoke execute on function public.save_job_draft_or_publish_without_fee_v1(
  uuid, uuid, jsonb, boolean
) from public, anon, authenticated;
grant execute on function public.save_job_draft_or_publish_without_fee_v1(
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
  v_adult_amount integer;
  v_teen_payout integer;
  v_service_fee constant integer := 274;
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
    v_adult_amount := nullif(
      p_payload->>'adult_job_amount_cents',
      ''
    )::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
  end;

  if v_adult_amount is not null then
    if v_adult_amount <= v_service_fee or v_adult_amount > 10000000 then
      return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
    end if;
    v_teen_payout := v_adult_amount - v_service_fee;
  elsif p_publish then
    return jsonb_build_object('ok', false, 'code', 'invalid_job_payment');
  end if;

  p_payload := (
    p_payload
    - 'pay_amount_cents'
    - 'mort_service_fee_cents'
  ) || jsonb_build_object('pay_amount_cents', v_teen_payout);

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
  set adult_job_amount_cents = v_adult_amount,
      mort_service_fee_cents = case
        when v_adult_amount is null then null
        else v_service_fee
      end,
      pay_amount_cents = v_teen_payout,
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

revoke execute on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) from public, anon;
grant execute on function public.save_job_draft_or_publish(
  uuid, uuid, jsonb, boolean
) to authenticated, service_role;
