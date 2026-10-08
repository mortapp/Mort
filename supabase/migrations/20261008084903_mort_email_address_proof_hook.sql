-- Function definition only. Hosted Auth hook configuration remains unchanged.
begin;
create or replace function mort_auth_guard.custom_access_token_hook(event jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  c mort_auth_guard.control%rowtype;g mort_auth_guard.account_generations%rowtype;
  u auth.users%rowtype;p mort_auth_guard.address_proofs%rowtype;claims jsonb:=event->'claims';
  method text:=event->>'authentication_method';recipient text;verified_oauth boolean:=false;
begin
  select * into c from mort_auth_guard.control where singleton;
  if c.enabled is not true then return jsonb_build_object('claims',claims);end if;
  -- The fixture observes these actual provider method labels. Other methods
  -- and live provider adapters require their own activation compatibility gate.
  if method not in('password','oauth','token_refresh') or method is null then raise exception 'MORT sign-in unavailable';end if;
  select * into u from auth.users where id=(event->>'user_id')::uuid;
  if not found or u.email is null or u.email_confirmed_at is null or u.deleted_at is not null or u.banned_until>clock_timestamp() then raise exception 'MORT sign-in unavailable';end if;
  recipient:=encode(extensions.digest(convert_to(u.email,'UTF8'),'sha256'),'hex');
  select * into c from mort_auth_guard.control where singleton for update;
  if c.enabled is not true then raise exception 'MORT sign-in unavailable';end if;
  select * into g from mort_auth_guard.account_generations where account_id=u.id for update;
  if method='oauth' then
    select exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='keycloak'
      and i.identity_data->>'email'=u.email and i.identity_data->>'email_verified'='true') into verified_oauth;
    if not verified_oauth then raise exception 'MORT sign-in unavailable';end if;
    if g.account_id is null then
      insert into mort_auth_guard.account_generations(account_id,recipient_hash) values(u.id,recipient) returning * into g;
    end if;
    if g.deleted_at is not null or g.recipient_hash<>recipient then raise exception 'MORT sign-in unavailable';end if;
    insert into mort_auth_guard.address_proofs(account_id,address_generation,recipient_hash,activation_generation,restore_generation,source,proved_at)
      values(u.id,g.address_generation,recipient,c.activation_generation,c.restore_generation,'provider_oauth',clock_timestamp())
      on conflict(account_id) do update set address_generation=excluded.address_generation,recipient_hash=excluded.recipient_hash,activation_generation=excluded.activation_generation,restore_generation=excluded.restore_generation,source=excluded.source,proved_at=excluded.proved_at,retired_at=null;
  end if;
  select * into p from mort_auth_guard.address_proofs where account_id=u.id;
  if not found or g.account_id is null or g.deleted_at is not null or p.retired_at is not null
    or g.recipient_hash<>recipient or p.recipient_hash<>recipient or p.address_generation<>g.address_generation
    or p.activation_generation<>c.activation_generation or p.restore_generation<>c.restore_generation then raise exception 'MORT sign-in unavailable';end if;
  if jsonb_typeof(claims->'app_metadata')='object' then
    claims:=jsonb_set(claims,'{app_metadata}',(claims->'app_metadata')-'mort_email_operation_id');
  end if;
  return jsonb_build_object('claims',claims);
end $$;
revoke all on function mort_auth_guard.custom_access_token_hook(jsonb) from public,anon,authenticated,service_role;
grant usage on schema mort_auth_guard to supabase_auth_admin;
grant execute on function mort_auth_guard.custom_access_token_hook(jsonb) to supabase_auth_admin;
commit;
