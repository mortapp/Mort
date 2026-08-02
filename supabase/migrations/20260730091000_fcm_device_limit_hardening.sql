-- Bound per-user FCM fan-out and make same-device account changes collision-safe.
-- The client can still rotate tokens and use multiple devices, while the server
-- keeps delivery work and completion payloads within a small fixed ceiling.

drop index if exists public.push_tokens_user_device_provider_idx;
create unique index push_tokens_active_user_device_provider_idx
on public.push_tokens(user_id, device_id, provider)
where is_active;

create or replace function private.enforce_active_fcm_device_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.provider <> 'fcm' or not new.is_active then
    return new;
  end if;

  update public.push_tokens item
  set is_active = false,
      deactivated_at = now(),
      last_error = 'device_registration_replaced'
  where item.user_id = new.user_id
    and item.provider = new.provider
    and item.device_id = new.device_id
    and item.id <> new.id
    and item.is_active;

  update public.push_tokens item
  set is_active = false,
      deactivated_at = now(),
      last_error = 'active_device_limit_reached'
  where item.id in (
    select existing.id
    from public.push_tokens existing
    where existing.user_id = new.user_id
      and existing.provider = 'fcm'
      and existing.is_active
      and existing.id <> new.id
    order by existing.last_seen_at desc, existing.created_at desc
    offset 9
  );

  return new;
end;
$$;

drop trigger if exists push_tokens_enforce_device_limit on public.push_tokens;
create trigger push_tokens_enforce_device_limit
before insert or update of user_id, device_id, provider, is_active
on public.push_tokens
for each row execute function private.enforce_active_fcm_device_limit();

with ranked as (
  select item.id,
    row_number() over (
      partition by item.user_id
      order by item.last_seen_at desc, item.created_at desc
    ) as active_rank
  from public.push_tokens item
  where item.provider = 'fcm' and item.is_active
)
update public.push_tokens item
set is_active = false,
    deactivated_at = now(),
    last_error = 'active_device_limit_reached'
from ranked
where ranked.id = item.id and ranked.active_rank > 10;

comment on function private.enforce_active_fcm_device_limit() is
  'Keeps at most ten active FCM devices per user and resolves same-device account transfers.';
