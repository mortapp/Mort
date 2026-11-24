-- Production-baseline migration: server-enforced password attestation.
--
-- Why: the project is on the Supabase Free plan. Native leaked-password
-- protection (HIBP) is a Pro feature and the Password Verification hook
-- requires Teams; the Before User Created hook payload carries no password.
-- The previous client-side check called an Edge Function that required a JWT
-- at signup (401) and the Flutter client failed open, so there was no
-- effective protection and a direct GoTrue signup/password update bypassed
-- it entirely.
--
-- What: every non-empty password write to auth.users must carry a
-- single-use, short-lived HMAC attestation minted by the password-guard Edge
-- Function after it enforced the MORT password policy and the HIBP check
-- (fail closed). The attestation travels in raw_user_meta_data on the same
-- Auth request, is verified here against the Vault secret
-- `mort_password_attestation_secret`, consumed (nonce recorded), and stripped
-- before the row is stored. Direct Auth API calls cannot obtain a token, so
-- they are rejected.
--
--   INSERT (signup):          BEFORE INSERT trigger, subject = lower(email)
--   UPDATE (password change): deferred constraint trigger, subject = user id.
--                             GoTrue writes encrypted_password and then
--                             raw_user_meta_data in one transaction
--                             (internal/api/user.go UserUpdate), so the check
--                             runs at commit against the final row.
--
-- Not affected: OAuth/Apple/Google users (no password), clearing a password
-- (NULL/''), metadata-only updates, sign-in (hashes are bcrypt cost 10 and
-- DB hash encryption is off in production, so GoTrue does not rewrite
-- encrypted_password on sign-in).
-- Staff provisioning: use passwordless Auth invitations, then have the
-- recipient set their password through password-guard after accepting the
-- invite. Password-bearing dashboard/admin creation and admin password
-- resets are intentionally blocked; magic-link/OTP auto-signup is also
-- blocked when GoTrue generates a password without an attestation.
--
-- Fails closed when the Vault secret is missing.
-- No RLS is disabled, no grants are broadened. Stripe objects are untouched.

begin;

create table if not exists private.password_attestation_uses (
  nonce text primary key check (nonce ~ '^[0-9a-f]{32}$'),
  purpose text not null check (purpose in ('signup', 'update_password')),
  subject text not null,
  used_at timestamptz not null default now(),
  expires_at timestamptz not null
);
alter table private.password_attestation_uses enable row level security;
revoke all on table private.password_attestation_uses from public, anon, authenticated;
drop policy if exists mort_private_deny_all on private.password_attestation_uses;
create policy mort_private_deny_all on private.password_attestation_uses
  as restrictive for all to authenticated, anon, public using (false) with check (false);

create or replace function private.mort_password_attestation_secret()
 returns text
 language sql
 stable security definer
 set search_path to ''
as $function$
  select ds.decrypted_secret
  from vault.decrypted_secrets ds
  where ds.name = 'mort_password_attestation_secret'
  order by ds.created_at desc
  limit 1;
$function$;
revoke all on function private.mort_password_attestation_secret() from public, anon, authenticated;

create or replace function private.mort_consume_password_attestation(p_token text, p_purpose text, p_subject text)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_parts text[];
  v_secret text;
  v_exp bigint;
  v_now bigint := floor(extract(epoch from clock_timestamp()));
  v_expected text;
begin
  if p_token is null or p_subject is null or btrim(p_subject) = '' then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_REQUIRED',
      hint = 'Set passwords through the password-guard function.';
  end if;

  v_parts := string_to_array(p_token, '.');
  if array_length(v_parts, 1) <> 5
     or v_parts[1] <> 'v1'
     or v_parts[2] <> p_purpose
     or v_parts[3] !~ '^[0-9a-f]{32}$'
     or v_parts[4] !~ '^[0-9]{1,12}$'
     or v_parts[5] !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_INVALID';
  end if;

  v_exp := v_parts[4]::bigint;
  if v_exp < v_now or v_exp > v_now + 900 then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_EXPIRED';
  end if;

  v_secret := private.mort_password_attestation_secret();
  if v_secret is null or length(v_secret) < 32 then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_UNCONFIGURED';
  end if;

  v_expected := encode(extensions.hmac(
    convert_to('v1|' || p_purpose || '|' || p_subject || '|' || v_parts[3] || '|' || v_parts[4], 'UTF8'),
    convert_to(v_secret, 'UTF8'),
    'sha256'), 'hex');
  if v_expected <> v_parts[5] then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_INVALID';
  end if;

  insert into private.password_attestation_uses (nonce, purpose, subject, expires_at)
  values (v_parts[3], p_purpose, p_subject, to_timestamp(v_exp))
  on conflict (nonce) do nothing;
  if not found then
    raise exception using errcode = '42501', message = 'MORT_PASSWORD_ATTESTATION_REPLAYED';
  end if;

  delete from private.password_attestation_uses where expires_at < now() - interval '1 day';
end;
$function$;
revoke all on function private.mort_consume_password_attestation(text, text, text) from public, anon, authenticated;

create or replace function private.mort_auth_users_password_attestation_on_insert()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if coalesce(new.encrypted_password, '') <> '' then
    perform private.mort_consume_password_attestation(
      new.raw_user_meta_data ->> 'mort_password_attestation',
      'signup',
      lower(btrim(new.email)));
    perform set_config('mort.pw_attested_' || replace(new.id::text, '-', ''), '1', true);
  end if;
  new.raw_user_meta_data := coalesce(new.raw_user_meta_data, '{}'::jsonb) - 'mort_password_attestation';
  return new;
end;
$function$;
revoke all on function private.mort_auth_users_password_attestation_on_insert() from public, anon, authenticated;

create or replace function private.mort_auth_users_password_attestation_on_update()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_flag text := 'mort.pw_attested_' || replace(new.id::text, '-', '');
  v_meta jsonb;
  v_password text;
begin
  -- Deferred: evaluate the row as it stands at commit.
  select u.raw_user_meta_data, u.encrypted_password into v_meta, v_password
  from auth.users u where u.id = new.id;
  if not found or coalesce(v_password, '') = '' then
    return null;
  end if;
  if coalesce(current_setting(v_flag, true), '') = '1' then
    return null; -- this transaction already presented a valid attestation for this user
  end if;

  perform private.mort_consume_password_attestation(
    v_meta ->> 'mort_password_attestation', 'update_password', new.id::text);
  perform set_config(v_flag, '1', true);

  update auth.users
     set raw_user_meta_data = raw_user_meta_data - 'mort_password_attestation'
   where id = new.id and raw_user_meta_data ? 'mort_password_attestation';
  return null;
end;
$function$;
revoke all on function private.mort_auth_users_password_attestation_on_update() from public, anon, authenticated;

-- GoTrue re-writes user metadata from the identity later in the signup
-- transaction (models.User.RemoveUnconfirmedIdentities). Once this
-- transaction has consumed an attestation for the user, strip the token from
-- any further metadata write. (Not before: the deferred update check must
-- still see the token GoTrue writes after the password.)
create or replace function private.mort_auth_users_strip_consumed_attestation()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if new.raw_user_meta_data ? 'mort_password_attestation'
     and coalesce(current_setting('mort.pw_attested_' || replace(new.id::text, '-', ''), true), '') = '1' then
    new.raw_user_meta_data := new.raw_user_meta_data - 'mort_password_attestation';
  end if;
  return new;
end;
$function$;
revoke all on function private.mort_auth_users_strip_consumed_attestation() from public, anon, authenticated;

-- GoTrue copies signup metadata into the email identity; never persist the token there.
create or replace function private.mort_auth_identities_strip_password_attestation()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  new.identity_data := coalesce(new.identity_data, '{}'::jsonb) - 'mort_password_attestation';
  return new;
end;
$function$;
revoke all on function private.mort_auth_identities_strip_password_attestation() from public, anon, authenticated;

drop trigger if exists mort_password_attestation_on_insert on auth.users;
create trigger mort_password_attestation_on_insert
  before insert on auth.users
  for each row execute function private.mort_auth_users_password_attestation_on_insert();

drop trigger if exists mort_password_attestation_on_password_change on auth.users;
create constraint trigger mort_password_attestation_on_password_change
  after update of encrypted_password on auth.users
  deferrable initially deferred
  for each row
  when (new.encrypted_password is distinct from old.encrypted_password
        and coalesce(new.encrypted_password, '') <> '')
  execute function private.mort_auth_users_password_attestation_on_update();

drop trigger if exists mort_strip_consumed_password_attestation on auth.users;
create trigger mort_strip_consumed_password_attestation
  before update of raw_user_meta_data on auth.users
  for each row execute function private.mort_auth_users_strip_consumed_attestation();

drop trigger if exists mort_strip_password_attestation on auth.identities;
create trigger mort_strip_password_attestation
  before insert or update of identity_data on auth.identities
  for each row execute function private.mort_auth_identities_strip_password_attestation();



-- Shared signup throttling. A process-local Edge Function Map is not a
-- global limit: Supabase Auth sees the function egress IP, and concurrent
-- isolates/regions can otherwise exceed Auth's per-IP signup ceiling.
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

  -- Bounded cleanup; only expired buckets are removed.
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
