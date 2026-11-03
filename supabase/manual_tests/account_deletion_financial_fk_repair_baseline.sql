create schema auth;
create schema private;

create table auth.users (
  id uuid primary key
);

create table private.financial_documents (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete restrict
);

create table private.stripe_job_funding_quotes (
  id uuid primary key,
  payer_id uuid not null references auth.users(id) on delete restrict,
  worker_id uuid not null references auth.users(id) on delete restrict
);

create table private.stripe_tip_attempts (
  id uuid primary key,
  payer_id uuid not null references auth.users(id) on delete restrict,
  worker_id uuid not null references auth.users(id) on delete restrict
);
