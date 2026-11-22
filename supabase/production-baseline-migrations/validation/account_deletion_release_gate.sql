-- Read-only. Run first against isolated QA; against production use only under
-- the relevant read-only change ticket. The FK catalogue emits no user records.
begin read only;
select
  to_regclass('public.account_deletion_requests') is not null as queue_present,
  to_regprocedure('public.get_account_deletion_receipt_status(text)') is not null as receipt_present,
  to_regprocedure('public.service_assert_account_deletion_lease(uuid,uuid)') is not null as lease_present,
  to_regprocedure('public.service_complete_account_deletion_request(uuid,uuid,text)') is not null as completion_present,
  to_regclass('private.account_deletion_legal_holds') is not null as hold_present;

select target, actor, has_function_privilege(actor, to_regprocedure(target), 'EXECUTE') as allowed
from (values
  ('public.get_account_deletion_receipt_status(text)', 'anon'),
  ('public.issue_my_account_deletion_receipt(uuid)', 'anon'),
  ('public.issue_my_account_deletion_receipt(uuid)', 'authenticated'),
  ('public.service_claim_account_deletion_request(uuid)', 'authenticated'),
  ('public.service_claim_account_deletion_request(uuid)', 'service_role'),
  ('public.service_assert_account_deletion_lease(uuid,uuid)', 'authenticated'),
  ('public.service_complete_account_deletion_request(uuid,uuid,text)', 'anon')
) v(target, actor);

select c.conrelid::regclass::text as child_relation, c.conname,
  c.confrelid::regclass::text as parent_relation, pg_get_constraintdef(c.oid) as definition
from pg_constraint c
where c.contype = 'f' and c.confrelid in ('auth.users'::regclass, 'public.profiles'::regclass)
order by parent_relation, child_relation, c.conname;
rollback;
