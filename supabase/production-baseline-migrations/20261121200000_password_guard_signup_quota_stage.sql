-- Stage independently of the Auth triggers. Does not change Auth writes.
-- New version: never rewrite the earlier QA-applied migration ledger.
begin;

create table if not exists private.password_guard_rate_limits (
  bucket_key text not null check (length(bucket_key) between 1 and 128),
  window_started_at timestamptz not null,
  hit_count integer not null check (hit_count > 0),
  primary key (bucket_key, window_started_at)
);
alter table private.password_guard_rate_limits enable row level security;
revoke all on table private.password_guard_rate_limits from public, anon, authenticated;

create or replace function public.mort_consume_password_guard_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_window_start timestamptz;
  v_hits integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'service_role_required';
  end if;
  if p_bucket_key is null or length(p_bucket_key) not between 1 and 128
     or p_limit is null or p_limit not between 1 and 1000
     or p_window_seconds is null or p_window_seconds not between 60 and 86400 then
    raise exception using errcode = '22023', message = 'invalid_rate_limit_arguments';
  end if;

  v_window_start := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / p_window_seconds) * p_window_seconds
  );

  insert into private.password_guard_rate_limits (bucket_key, window_started_at, hit_count)
  values (p_bucket_key, v_window_start, 1)
  on conflict (bucket_key, window_started_at)
  do update set hit_count = private.password_guard_rate_limits.hit_count + 1
  returning hit_count into v_hits;

  delete from private.password_guard_rate_limits
  where window_started_at < clock_timestamp() - interval '2 days';

  return v_hits <= p_limit;
end;
$function$;
revoke all on function public.mort_consume_password_guard_rate_limit(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.mort_consume_password_guard_rate_limit(text, integer, integer)
  to service_role;

commit;
