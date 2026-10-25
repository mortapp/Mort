begin;

create extension if not exists pgtap with schema extensions;
set local search_path = extensions, public;

select plan(8);

create temporary table push_delivery_gate_fixture (
  user_id uuid not null,
  device_id uuid not null,
  request_id uuid not null,
  status jsonb,
  registration jsonb,
  delivery_batch jsonb
) on commit drop;

insert into push_delivery_gate_fixture (user_id, device_id, request_id)
values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid());

insert into auth.users (id)
select user_id from push_delivery_gate_fixture;
insert into public.notification_preferences (user_id, push_enabled)
select user_id, true from push_delivery_gate_fixture;

-- Exercise the important split-brain case: the worker flag is on, but the
-- centrally controlled release policy still has remote push disabled.
update public.push_delivery_runtime set remote_push_enabled = true
where singleton = true;

select is(
  public.get_push_delivery_availability() ->> 'delivery_available',
  'false',
  'availability requires both the runtime switch and release policy'
);
select set_config(
  'request.jwt.claim.sub', (select user_id::text from push_delivery_gate_fixture), true
);
update push_delivery_gate_fixture set status = public.get_my_push_status_v2();
select is(
  (select status ->> 'push_preference_enabled' from push_delivery_gate_fixture),
  'true',
  'the user preference remains independently visible'
);
select is(
  (select status ->> 'remote_push_enabled' from push_delivery_gate_fixture),
  'false',
  'effective remote push is off while server delivery is unavailable'
);

update push_delivery_gate_fixture fixture set registration =
  public.register_my_push_device_v2(
    fixture.device_id,
    'fcm',
    'a-valid-fcm-registration-token-1234567890',
    'android',
    'authorized',
    '1.2.3+98',
    'en-US',
    'America/Indiana/Indianapolis',
    'production_public',
    fixture.request_id
  );
select is(
  (select registration ->> 'code' from push_delivery_gate_fixture),
  'remote_push_disabled',
  'registration is denied while effective delivery is disabled'
);
select ok(
  not exists (
    select 1 from public.push_tokens token
    join push_delivery_gate_fixture fixture
      on token.user_id = fixture.user_id and token.device_id = fixture.device_id
  ),
  'a disabled registration does not persist the FCM token'
);

select set_config('request.jwt.claim.role', 'service_role', true);
update push_delivery_gate_fixture set delivery_batch =
  public.service_claim_push_events(25, null);
select is(
  (select delivery_batch ->> 'remote_push_enabled' from push_delivery_gate_fixture),
  'false',
  'the push sender honors release policy when the runtime switch is on'
);
select ok(
  has_function_privilege('anon', 'public.get_push_delivery_availability()', 'EXECUTE'),
  'anonymous clients can read the non-sensitive availability flag before prompting'
);
select ok(
  has_function_privilege('authenticated', 'public.get_push_delivery_availability()', 'EXECUTE'),
  'authenticated clients can read the non-sensitive availability flag'
);

select * from finish();
rollback;
