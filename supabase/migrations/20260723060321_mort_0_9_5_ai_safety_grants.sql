-- The AI safety Edge Function needs server-only writes while authenticated
-- users may read only their own RLS-filtered moderation result.

revoke all on table public.ai_moderation_events from public, anon;
grant select on table public.ai_moderation_events to authenticated;
grant select, insert, update, delete on table public.ai_moderation_events
to service_role;
