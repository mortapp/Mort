-- Provider spend protection is independent from deterministic safety triage.
create or replace function public.support_consume_endpoint_limit(p_scope text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer;
  v_window integer;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select setting.request_limit, setting.window_seconds
  into v_limit, v_window
  from (values
    ('kb_search', 30, 600),
    ('provider_request', 5, 86400),
    ('ticket_create', 5, 3600),
    ('tool_execute', 20, 600),
    ('feedback', 20, 3600),
    ('upload_authorize', 8, 3600),
    ('attachment_submit', 12, 3600),
    ('attachment_download', 30, 300),
    ('admin_copilot', 30, 600)
  ) as setting(scope, request_limit, window_seconds)
  where setting.scope = p_scope;
  if v_limit is null then
    return jsonb_build_object('ok', false, 'code', 'invalid_rate_limit_scope');
  end if;
  if not private.support_take_rate_limit(auth.uid(), p_scope, v_limit, v_window) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.support_consume_endpoint_limit(text) from public, anon;
grant execute on function public.support_consume_endpoint_limit(text) to authenticated, service_role;
