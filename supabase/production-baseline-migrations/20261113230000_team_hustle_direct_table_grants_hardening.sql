-- Team-hustle writes and membership are exposed only through SECURITY DEFINER RPCs.
-- Keep the authenticated read path for the public team-hustle listing, but remove
-- unused direct table grants and all anonymous table privileges.
revoke all privileges on table public.team_hustles from anon;
revoke all privileges on table public.team_hustle_members from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.team_hustles from authenticated;
