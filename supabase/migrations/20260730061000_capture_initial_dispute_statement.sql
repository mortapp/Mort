create or replace function private.capture_initial_payment_dispute_statement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.payment_dispute_statements(
    dispute_id, author_id, author_role, statement, client_request_id, created_at
  ) values (
    new.id, new.worker_id, 'worker', new.worker_statement,
    gen_random_uuid(), new.opened_at
  );
  return new;
end;
$$;

drop trigger if exists payment_disputes_capture_initial_statement
on public.payment_disputes;
create trigger payment_disputes_capture_initial_statement
after insert on public.payment_disputes
for each row execute function private.capture_initial_payment_dispute_statement();

revoke all on function private.capture_initial_payment_dispute_statement()
from public, anon, authenticated;
grant execute on function private.capture_initial_payment_dispute_statement()
to service_role;
