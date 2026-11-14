-- Defense-in-depth for the message safety internals.
--
-- message_safety_rules and message_moderation_log live in the private schema
-- and already have all privileges revoked from public/anon/authenticated, so
-- no client can read them through PostgREST. Enabling row level security with
-- no client policies adds a second layer: if a grant is ever introduced by
-- mistake, clients still see zero rows and cannot write.
--
-- Legitimate access is unchanged:
--  - The table owner (the migration role) bypasses plain RLS, so the
--    SECURITY DEFINER scanner trigger and staff moderation functions keep
--    working exactly as before.
--  - FORCE ROW LEVEL SECURITY is deliberately NOT used: it would apply RLS to
--    the owner too and break the definer-path writes to the moderation log.
--
-- Verified on the QA project: the full moderation and normalization pgTAP
-- suites (24 + 10 assertions) pass with RLS enabled on both tables.

-- Rules table: staff-managed, never client-readable.
alter table private.message_safety_rules enable row level security;

-- Moderation evidence: staff-only via privileged functions, never
-- client-readable (evidence must not leak sender/recipient identities).
alter table private.message_moderation_log enable row level security;
