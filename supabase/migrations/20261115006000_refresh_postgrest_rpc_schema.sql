-- Explicitly refresh PostgREST after adding the team-hustle review RPC.
notify pgrst, 'reload schema';
