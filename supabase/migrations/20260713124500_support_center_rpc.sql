drop policy if exists support_tickets_update_owner_or_admin
on public.support_tickets;
create policy support_tickets_update_admin
on public.support_tickets for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.create_support_ticket(
  p_subject text,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_subject text := btrim(coalesce(p_subject, ''));
  v_message text := btrim(coalesce(p_message, ''));
  v_ticket public.support_tickets%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'user_account_restricted');
  end if;
  if char_length(v_subject) not between 4 and 120
     or char_length(v_message) not between 10 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_ticket');
  end if;
  if not public.check_rate_limit('support_ticket_create', 5, 86400) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_limit_reached');
  end if;

  insert into public.support_tickets (requester_id, subject)
  values (auth.uid(), v_subject)
  returning * into v_ticket;

  insert into public.support_ticket_messages (ticket_id, sender_id, body)
  values (v_ticket.id, auth.uid(), v_message);

  perform public.record_rate_limit_event('support_ticket_create');

  return jsonb_build_object('ok', true, 'ticket', to_jsonb(v_ticket));
end;
$$;

create or replace function public.queue_support_ticket_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin record;
begin
  if tg_op = 'INSERT' then
    for v_admin in select id from public.profiles where role = 'admin' loop
      perform public.enqueue_notification(
        v_admin.id,
        'New support ticket',
        'A private MORT support ticket is ready for review.',
        jsonb_build_object('supportTicketId', new.id)
      );
    end loop;
  elsif old.status is distinct from new.status then
    perform public.enqueue_notification(
      new.requester_id,
      'Support ticket updated',
      'Your support ticket is now ' || new.status || '.',
      jsonb_build_object('supportTicketId', new.id, 'status', new.status)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists support_tickets_queue_notifications
on public.support_tickets;
create trigger support_tickets_queue_notifications
after insert or update of status on public.support_tickets
for each row execute function public.queue_support_ticket_notifications();

revoke execute on function public.create_support_ticket(text, text)
from public, anon;
grant execute on function public.create_support_ticket(text, text)
to authenticated, service_role;
revoke execute on function public.queue_support_ticket_notifications()
from public, anon, authenticated;

