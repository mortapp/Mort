alter table public.support_tickets
  alter column case_number set default (
    'MORT-' || upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 12))
  );

-- The unique index remains the final collision guard. A 48-bit random suffix
-- does not expose sequence counts or requester identity.
