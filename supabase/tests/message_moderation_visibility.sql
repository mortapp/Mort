do $$
declare
  v_select_policy text;
  v_page_function text;
begin
  select pg_get_expr(policy.polqual, policy.polrelid)
  into v_select_policy
  from pg_policy as policy
  where policy.polrelid = 'public.messages'::regclass
    and policy.polname = 'messages_select_member';

  if v_select_policy is null
     or v_select_policy !~* 'moderation_status\s*=\s*''approved'''
     or v_select_policy !~* 'sender_id\s*=.*auth\.uid' then
    raise exception 'message SELECT policy exposes non-approved content to other members';
  end if;

  select pg_get_functiondef(
    'public.list_thread_messages_page(uuid,timestamptz,uuid,integer)'::regprocedure
  )
  into v_page_function;

  if v_page_function !~* 'message\.moderation_status\s*=\s*''approved''\s+or\s+message\.sender_id\s*=\s*v_user_id' then
    raise exception 'message page RPC exposes non-approved content to other members';
  end if;
end;
$$;
