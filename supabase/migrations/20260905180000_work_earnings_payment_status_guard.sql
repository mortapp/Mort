-- Security fix: work_earning_entries.payment_status mass-assignment.
--
-- Found during backend security review: the existing RLS policy
-- "work_earnings_own" only checks (user_id = auth.uid() AND
-- current_profile_role() = 'teen'), with no restriction on which
-- payment_status value a client may set. A teen could therefore
-- self-insert or self-update their own earning row with
-- payment_status = 'poster_confirmed' (or 'disputed'), fabricating an
-- employer confirmation that never happened -- no existing function in
-- this codebase sets 'poster_confirmed' on this table, so the only path
-- to that value today is direct client table access.
--
-- Fix: a trigger enforces that only service_role (i.e. a future
-- trusted server-side confirmation path, not the app client) may set or
-- change payment_status away from 'self_reported'. Ordinary
-- owner-initiated inserts/updates of their own row (amount, date,
-- source_label, etc.) are unaffected.

create or replace function private.guard_work_earning_payment_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.payment_status <> 'self_reported' and auth.role() <> 'service_role' then
      raise exception 'work_earning_payment_status_requires_service_role'
        using errcode = '42501';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.payment_status is distinct from old.payment_status
       and auth.role() <> 'service_role' then
      raise exception 'work_earning_payment_status_requires_service_role'
        using errcode = '42501';
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists work_earning_entries_guard_payment_status
  on public.work_earning_entries;

create trigger work_earning_entries_guard_payment_status
  before insert or update on public.work_earning_entries
  for each row execute function private.guard_work_earning_payment_status();
