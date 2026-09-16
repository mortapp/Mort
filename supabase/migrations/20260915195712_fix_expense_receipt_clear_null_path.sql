-- set_my_expense_receipt rejected p_path is null as invalid_receipt_path,
-- but the client's removeReceipt call sends exactly that to mean "clear the
-- receipt". Every "Remove receipt" tap therefore deleted the storage object
-- while leaving expense_records.receipt_path pointing at the now-deleted
-- file, permanently breaking the receipt preview for that expense. The
-- ownership check on storage.foldername(p_path) only makes sense for a
-- non-null path; skip it when the caller is explicitly clearing.
--
-- This is a corrective forward migration, not an edit to the historical
-- 20260831120000_mort_earnings_safety_v1.sql migration (already applied to
-- the linked project as mort_earnings_safety_v1), per the rule against
-- rewriting already-applied migrations.

create or replace function public.set_my_expense_receipt(p_id uuid, p_path text)
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
  if p_path is not null and (storage.foldername(p_path))[1] is distinct from v_user::text then
    return jsonb_build_object('ok', false, 'code', 'invalid_receipt_path');
  end if;

  update public.expense_records e
    set receipt_path = p_path, updated_at = now()
  where e.id = p_id and e.user_id = v_user
  returning * into v_row;

  if v_row is null then
    return jsonb_build_object('ok', false, 'code', 'expense_not_found');
  end if;
  return jsonb_build_object('ok', true, 'expense', to_jsonb(v_row));
end;
$$;
;
