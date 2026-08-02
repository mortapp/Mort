-- A server-only global daily provider budget complements the per-user cap.
-- Authenticated clients cannot consume or inspect the global counter directly.
create table public.support_global_rate_limits (
  scope text not null,
  window_started_at timestamptz not null,
  window_seconds integer not null,
  request_count integer not null default 1,
  expires_at timestamptz not null,
  primary key (scope, window_started_at),
  constraint support_global_rate_limits_scope_check check (scope ~ '^[a-z0-9_.-]{3,80}$'),
  constraint support_global_rate_limits_window_check check (window_seconds between 60 and 86400),
  constraint support_global_rate_limits_count_check check (request_count between 1 and 1000000)
);

create index support_global_rate_limits_expiry_idx
on public.support_global_rate_limits(expires_at);

alter table public.support_global_rate_limits enable row level security;
alter table public.support_global_rate_limits force row level security;
revoke all on public.support_global_rate_limits from public, anon, authenticated;
grant select, insert, update, delete on public.support_global_rate_limits to service_role;

create or replace function private.support_take_global_rate_limit(
  p_scope text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window_started_at timestamptz;
  v_allowed boolean := false;
begin
  if auth.role() <> 'service_role'
    or p_scope !~ '^[a-z0-9_.-]{3,80}$'
    or p_limit not between 1 and 1000000
    or p_window_seconds not between 60 and 86400 then
    return false;
  end if;
  v_window_started_at := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );
  insert into public.support_global_rate_limits (
    scope, window_started_at, window_seconds, request_count, expires_at
  ) values (
    p_scope,
    v_window_started_at,
    p_window_seconds,
    1,
    v_window_started_at + make_interval(secs => p_window_seconds)
  )
  on conflict (scope, window_started_at) do update
  set request_count = public.support_global_rate_limits.request_count + 1,
      expires_at = excluded.expires_at
  where public.support_global_rate_limits.request_count < p_limit
    and public.support_global_rate_limits.expires_at > now()
  returning true into v_allowed;
  return coalesce(v_allowed, false);
end;
$$;

revoke all on function private.support_take_global_rate_limit(text, integer, integer)
from public, anon, authenticated;
grant execute on function private.support_take_global_rate_limit(text, integer, integer)
to service_role;

create or replace function public.support_consume_global_provider_limit()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    return jsonb_build_object('ok', false, 'code', 'internal_authorization_required');
  end if;
  if not private.support_take_global_rate_limit('provider_request', 500, 86400) then
    return jsonb_build_object('ok', false, 'code', 'support_global_rate_limited');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.support_consume_global_provider_limit()
from public, anon, authenticated;
grant execute on function public.support_consume_global_provider_limit()
to service_role;
