-- support_ticket_messages_select_authorized invokes this helper directly for
-- staff-visible rows. The private schema remains inaccessible to clients.
grant execute on function private.has_support_role(uuid, text[])
to authenticated;
