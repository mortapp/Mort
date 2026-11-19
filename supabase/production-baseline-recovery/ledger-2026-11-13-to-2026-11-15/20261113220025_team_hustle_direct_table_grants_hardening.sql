-- Exact statements from production ledger version 20261113220025
revoke all privileges on table public.team_hustles from anon;
revoke all privileges on table public.team_hustle_members from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.team_hustles from authenticated;
