-- The previous participant policy queried conversation_participants from
-- inside its own predicate. PostgreSQL correctly rejected that recursive RLS
-- evaluation. A participant only needs their own membership row; admins retain
-- visibility for moderation.
alter policy conversation_participants_select_self_or_admin
on public.conversation_participants
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_admin()
);
