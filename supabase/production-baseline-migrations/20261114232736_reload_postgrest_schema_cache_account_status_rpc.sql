-- The account-status RPC existed with this signature, but PostgREST's cached
-- schema did not recognize its named arguments. Refresh the REST schema cache.
notify pgrst, 'reload schema';
