-- Cover the remaining foreign-key lookups reported by the Performance Advisor.

create index if not exists poster_payment_restrictions_dispute_idx
  on public.poster_payment_restrictions(dispute_id);

create index if not exists poster_payment_restrictions_imposed_by_idx
  on public.poster_payment_restrictions(imposed_by);

create index if not exists poster_payment_restrictions_lifted_by_idx
  on public.poster_payment_restrictions(lifted_by)
  where lifted_by is not null;
