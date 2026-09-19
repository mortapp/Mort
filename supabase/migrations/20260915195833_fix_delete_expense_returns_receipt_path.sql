-- delete_my_expense deleted only the expense_records row and never touched
-- storage, even though the client-side confirmation sheet promises
-- "Attached receipts are also removed." Storage deletion cannot be atomic
-- with the Postgres delete (it is a separate system reached over its own
-- API), so the safest ordering is: delete the authoritative DB row first,
-- return its receipt_path so the caller knows what to clean up, then let the
-- caller best-effort delete the storage object -- the same non-atomic,
-- best-effort pattern set_my_expense_receipt's null-path clear already uses
-- for the symmetric "remove receipt" flow.
--
-- Corrective forward migration; 20260831120000_mort_earnings_safety_v1.sql
-- (already applied) is not edited directly.

create or replace function public.delete_my_expense(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.expense_records;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  delete from public.expense_records e
  where e.id = p_id and e.user_id = v_user
  returning * into v_row;
  if v_row is null then
    return jsonb_build_object('ok', false, 'code', 'expense_not_found');
  end if;
  return jsonb_build_object('ok', true, 'receipt_path', v_row.receipt_path);
end;
$$;
;
