-- Disposable fixture-only method observations. No claims or account identifiers.
create table if not exists mort_fixture.hook_methods(method text primary key,hits integer not null);
revoke all on mort_fixture.hook_methods from public,anon,authenticated;
create or replace function mort_fixture.record_access_token(event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare observed_method text:=event->>'authentication_method';result jsonb;
begin
  if observed_method in('password','oauth','token_refresh','otp','magiclink','recovery','invite','email/signup','email_change','totp','sso/saml','anonymous') then
    -- Fixed allowlisted method names survive transaction rollback; no claims,
    -- identifiers, credentials, recipients or request bodies are emitted.
    raise log 'MORT fixture auth method %',observed_method;
    insert into mort_fixture.hook_methods values(observed_method,1) on conflict(method) do update set hits=mort_fixture.hook_methods.hits+1;
  end if;
  if to_regprocedure('mort_auth_guard.custom_access_token_hook(jsonb)') is not null then
    execute 'select mort_auth_guard.custom_access_token_hook($1)' into result using event;return result;
  end if;
  return jsonb_build_object('claims',event->'claims');
end $$;
grant usage on schema mort_fixture to supabase_auth_admin;
revoke all on function mort_fixture.record_access_token(jsonb) from public,anon,authenticated;
grant execute on function mort_fixture.record_access_token(jsonb) to supabase_auth_admin;
