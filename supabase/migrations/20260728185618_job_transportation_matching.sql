alter table public.jobs
  add column if not exists acceptable_transportation_methods text[] not null
    default array[
      'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
    ]::text[],
  add column if not exists transportation_considerations text;

alter table public.jobs
  drop constraint if exists jobs_acceptable_transportation_allowed,
  add constraint jobs_acceptable_transportation_allowed check (
    cardinality(acceptable_transportation_methods) between 1 and 6
    and acceptable_transportation_methods <@ array[
      'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
    ]::text[]
  ),
  drop constraint if exists jobs_transportation_considerations_length,
  add constraint jobs_transportation_considerations_length check (
    transportation_considerations is null
    or char_length(transportation_considerations) <= 500
  );

comment on column public.jobs.acceptable_transportation_methods is
  'General travel methods compatible with the job. Never a transportation guarantee.';
comment on column public.jobs.transportation_considerations is
  'Public general travel guidance only. Exact addresses and contact details are prohibited.';

create or replace function public.save_job_draft_or_publish(
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
  v_transportation_methods text[];
  v_transportation_notes text;
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

  if p_payload ? 'acceptable_transportation_methods' then
    if jsonb_typeof(p_payload->'acceptable_transportation_methods') <> 'array'
       or jsonb_array_length(p_payload->'acceptable_transportation_methods')
          not between 1 and 6 then
      return jsonb_build_object(
        'ok', false,
        'code', 'job_transportation_invalid'
      );
    end if;
    select coalesce(array_agg(method order by method), array[]::text[])
    into v_transportation_methods
    from (
      select distinct lower(btrim(item #>> '{}')) as method
      from jsonb_array_elements(
        p_payload->'acceptable_transportation_methods'
      ) item
      where jsonb_typeof(item) = 'string'
        and btrim(item #>> '{}') <> ''
    ) normalized;
  else
    v_transportation_methods := array[
      'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
    ]::text[];
  end if;

  if cardinality(v_transportation_methods) not between 1 and 6
     or exists (
       select 1 from unnest(v_transportation_methods) method
       where method not in (
         'walking', 'bicycle', 'car', 'public_transit', 'rideshare', 'other'
       )
     ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'job_transportation_invalid'
    );
  end if;

  v_transportation_notes := nullif(
    btrim(p_payload->>'transportation_considerations'),
    ''
  );
  if v_transportation_notes is not null and (
    char_length(v_transportation_notes) > 500
    or lower(v_transportation_notes) ~* '([a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}|\+?[0-9][0-9() .\-]{8,}[0-9]|@[a-z0-9_]{2,}|\$[a-z][a-z0-9_]*)'
  ) then
    return jsonb_build_object(
      'ok', false,
      'code', 'job_transportation_invalid'
    );
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
      acceptable_transportation_methods = v_transportation_methods,
      transportation_considerations = v_transportation_notes,
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
