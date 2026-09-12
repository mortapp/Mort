-- Security fix: work_earning_entries.payment_status mass-assignment.
--
-- Found while forensically inventorying the Financial Safety work preserved on
-- the untouched feature/compact-onboarding-and-screen-polish checkout (which
-- has its own fix for this dated 2026-09-05); independently confirmed the
-- underlying vulnerability is real and unpatched on this branch too: the
-- work_earnings_own policy (supabase/migrations/20260719012241_mission_
-- closed_pilot_independence.sql:986, present on both branches from their
-- shared ancestor) grants "for all" access checked only on
-- (user_id = auth.uid() and current_profile_role() = 'teen') -- no
-- restriction on which payment_status value a client may write. A teen could
-- self-insert or self-update their own earning row with
-- payment_status = 'poster_confirmed' (or 'disputed'), fabricating an
-- employer confirmation that never happened. No function in this codebase
-- sets 'poster_confirmed' on this table, so direct client table access was
-- the only path to that value.
--
-- Fix: a trigger enforces that only service_role (a future trusted
-- server-side confirmation path, not the app client) may set or change
-- payment_status away from 'self_reported'. Ordinary owner-initiated
-- inserts/updates of their own row (amount, date, source_label, etc.) are
-- unaffected.

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
