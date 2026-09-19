-- Retry-safe reconciliation leases. Existing insert-only reconciliation remains
-- compatible; new workers should claim by request id and complete with the
-- returned lease token.

alter table private.stripe_reconciliation_runs
  add column if not exists request_id uuid,
  add column if not exists processing_lease_token uuid,
  add column if not exists processing_lease_until timestamptz,
  add column if not exists attempt_count integer not null default 0
    check (attempt_count between 0 and 1000),
  add column if not exists updated_at timestamptz not null default statement_timestamp();

create unique index if not exists stripe_reconciliation_runs_environment_request_idx
  on private.stripe_reconciliation_runs(environment, request_id)
  where request_id is not null;

create index if not exists stripe_reconciliation_runs_lease_queue_idx
  on private.stripe_reconciliation_runs(environment, status, processing_lease_until, started_at);

create or replace function public.stripe_server_claim_reconciliation_v1(
  p_request_id uuid, p_environment text, p_scope text,
  p_subject_reference uuid default null, p_lease_seconds integer default 120
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_run private.stripe_reconciliation_runs%rowtype;
  v_token uuid;
  v_now timestamptz := clock_timestamp();
begin
  perform private.require_stripe_service_role();
  if p_request_id is null or p_environment not in ('test','live')
     or p_scope not in ('payment','connected_account','payout','stale_records')
     or p_lease_seconds not between 30 and 900 then
    raise exception 'reconciliation_claim_invalid';
  end if;
  select * into v_run from private.stripe_reconciliation_runs
   where environment=p_environment and request_id=p_request_id for update;
  if v_run.id is not null then
    if v_run.scope <> p_scope or v_run.subject_reference is distinct from p_subject_reference then
      raise exception 'reconciliation_request_conflict';
    end if;
    if v_run.status <> 'started' then
      return jsonb_build_object('ok',true,'claimed',false,'terminal',true,
        'run_id',v_run.id,'status',v_run.status,'attempt_count',v_run.attempt_count);
    end if;
    if v_run.processing_lease_token is not null and v_run.processing_lease_until > v_now then
      return jsonb_build_object('ok',true,'claimed',false,'terminal',false,
        'run_id',v_run.id,'status',v_run.status,'attempt_count',v_run.attempt_count,
        'retry_after_seconds',greatest(1,ceil(extract(epoch from (v_run.processing_lease_until-v_now)))::integer));
    end if;
    v_token := gen_random_uuid();
    update private.stripe_reconciliation_runs
       set processing_lease_token=v_token,
           processing_lease_until=v_now+make_interval(secs=>p_lease_seconds),
           attempt_count=attempt_count+1,
           updated_at=v_now
     where id=v_run.id returning * into v_run;
  else
    v_token := gen_random_uuid();
    insert into private.stripe_reconciliation_runs(
      environment,scope,subject_reference,status,request_id,
      processing_lease_token,processing_lease_until,attempt_count,started_at,updated_at
    ) values (
      p_environment,p_scope,p_subject_reference,'started',p_request_id,
      v_token,v_now+make_interval(secs=>p_lease_seconds),1,v_now,v_now
    ) returning * into v_run;
  end if;
  insert into private.stripe_financial_audit_events(
    environment,event_type,subject_type,subject_id,safe_reason_code,field_names
  ) values (
    p_environment,'reconciliation_lease_claimed','reconciliation',v_run.id,
    case when v_run.attempt_count>1 then 'stale_lease_reclaimed' else 'lease_claimed' end,
    array['scope','attempt_count','processing_lease_until']
  );
  return jsonb_build_object('ok',true,'claimed',true,'terminal',false,
    'run_id',v_run.id,'lease_token',v_token,'lease_until',v_run.processing_lease_until,
    'attempt_count',v_run.attempt_count);
end;
$$;

create or replace function public.stripe_server_complete_reconciliation_v1(
  p_run_id uuid, p_lease_token uuid, p_status text, p_safe_result_code text
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_run private.stripe_reconciliation_runs%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  perform private.require_stripe_service_role();
  if p_run_id is null or p_lease_token is null
     or p_status not in ('matched','corrected','needs_review','failed')
     or p_safe_result_code is null or p_safe_result_code !~ '^[a-z][a-z0-9_]{2,63}$' then
    raise exception 'reconciliation_completion_invalid';
  end if;
  select * into v_run from private.stripe_reconciliation_runs where id=p_run_id for update;
  if v_run.id is null then raise exception 'reconciliation_run_not_found'; end if;
  if v_run.status <> 'started' then
    return jsonb_build_object('ok',true,'idempotent',true,'run_id',v_run.id,'status',v_run.status);
  end if;
  if v_run.processing_lease_token is distinct from p_lease_token
     or v_run.processing_lease_until is null or v_run.processing_lease_until <= v_now then
    raise exception 'reconciliation_lease_invalid';
  end if;
  update private.stripe_reconciliation_runs
     set status=p_status,safe_result_code=p_safe_result_code,completed_at=v_now,
         processing_lease_token=null,processing_lease_until=null,updated_at=v_now
   where id=p_run_id returning * into v_run;
  insert into private.stripe_financial_audit_events(
    environment,event_type,subject_type,subject_id,safe_reason_code,field_names
  ) values (
    v_run.environment,'reconciliation_completed','reconciliation',v_run.id,
    p_safe_result_code,array['scope','status','attempt_count','completed_at']
  );
  return jsonb_build_object('ok',true,'idempotent',false,'run_id',v_run.id,
    'status',v_run.status,'attempt_count',v_run.attempt_count);
end;
$$;

revoke all on function public.stripe_server_claim_reconciliation_v1(
  uuid,text,text,uuid,integer
) from public,anon,authenticated;
grant execute on function public.stripe_server_claim_reconciliation_v1(
  uuid,text,text,uuid,integer
) to service_role;
revoke all on function public.stripe_server_complete_reconciliation_v1(
  uuid,uuid,text,text
) from public,anon,authenticated;
grant execute on function public.stripe_server_complete_reconciliation_v1(
  uuid,uuid,text,text
) to service_role;
