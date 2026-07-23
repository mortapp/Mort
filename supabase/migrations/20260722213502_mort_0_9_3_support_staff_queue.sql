create or replace function public.support_staff_list_queue(
  p_status text default null,
  p_unassigned_only boolean default false,
  p_limit integer default 50
)
returns setof public.support_tickets
language sql
stable
security definer
set search_path = ''
as $$
  select ticket.*
  from public.support_tickets ticket
  where private.has_support_role(
      auth.uid(), array['support_agent', 'support_manager', 'safety_reviewer']
    )
    and private.can_access_support_ticket(ticket.id, auth.uid())
    and (p_status is null or ticket.status = p_status)
    and (not coalesce(p_unassigned_only, false) or ticket.assigned_support_user_id is null)
  order by
    case ticket.priority when 'urgent' then 0 when 'high' then 1 when 'normal' then 2 else 3 end,
    coalesce(ticket.last_user_message_at, ticket.created_at) asc
  limit least(greatest(coalesce(p_limit, 50), 1), 100)
$$;

create or replace function public.support_staff_get_ticket_thread(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_messages jsonb;
  v_evidence jsonb;
begin
  if not private.has_support_role(
    auth.uid(), array['support_agent', 'support_manager', 'safety_reviewer']
  ) then return jsonb_build_object('ok', false, 'code', 'support_staff_role_required'); end if;
  select * into v_ticket from public.support_tickets where id = p_ticket_id;
  if v_ticket.id is null or not private.can_access_support_ticket(v_ticket.id, auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'support_ticket_not_authorized');
  end if;
  select coalesce(jsonb_agg(to_jsonb(message) order by message.created_at), '[]'::jsonb)
  into v_messages from public.support_ticket_messages message
  where message.ticket_id = v_ticket.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', evidence.id,
    'category', evidence.evidence_category,
    'status', evidence.status,
    'processed_byte_size', evidence.processed_byte_size,
    'created_at', evidence.created_at,
    'retention_delete_at', evidence.retention_delete_at,
    'preservation_hold', evidence.preservation_hold,
    'review_status', evidence.review_status
  ) order by evidence.created_at), '[]'::jsonb)
  into v_evidence from public.support_evidence_attachments evidence
  where evidence.ticket_id = v_ticket.id and evidence.status <> 'deleted';
  return jsonb_build_object(
    'ok', true,
    'ticket', to_jsonb(v_ticket),
    'messages', v_messages,
    'evidence', v_evidence
  );
end;
$$;

revoke all on function public.support_staff_list_queue(text, boolean, integer)
from public, anon;
revoke all on function public.support_staff_get_ticket_thread(uuid)
from public, anon;
grant execute on function public.support_staff_list_queue(text, boolean, integer)
to authenticated, service_role;
grant execute on function public.support_staff_get_ticket_thread(uuid)
to authenticated, service_role;
