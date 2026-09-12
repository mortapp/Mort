-- ============================================================================
-- MORT EARNINGS SAFETY v1
-- ----------------------------------------------------------------------------
-- Purpose: family-safe earnings recordkeeping, expense ledger, receipts,
-- personal targets, versioned financial-rule engine, and benefit-aware
-- information architecture. MORT Earnings Safety helps teens KEEP EARNING
-- while understanding, documenting, and responding to potential tax,
-- recordkeeping, and public-benefit consequences.
--
-- Absolute safety rules encoded here:
--   * Reaching a financial threshold NEVER blocks work, applications,
--     messaging, or any marketplace surface. Alerts are informational.
--   * No compensation category is ever treated as "not counted". Cash,
--     electronic, processed, gift-card, and other noncash compensation all
--     count toward tracked gross compensation.
--   * No SSN or tax-identity data is collected or stored anywhere in this
--     migration.
--   * MORT never performs individualized tax or benefits eligibility
--     determinations. Rules are versioned references to official sources;
--     stale rules fail closed.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Financial preferences (one row per user)
-- ----------------------------------------------------------------------------
create table public.financial_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  alerts_enabled boolean not null default true,
  benefit_programs text[] not null default '{}'::text[],
  guardian_financial_visibility boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_preferences_programs_check check (
    benefit_programs <@ array['SNAP','MEDICAID','CHIP','TANF','SSI','HOUSING_ASSISTANCE']::text[]
  )
);

-- ----------------------------------------------------------------------------
-- Expense ledger
-- ----------------------------------------------------------------------------
create table public.expense_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount_cents integer not null,
  spent_on date not null,
  category text not null,
  merchant text not null default '',
  description text not null default '',
  job_id uuid references public.jobs(id) on delete set null,
  receipt_path text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_records_amount_check check (amount_cents > 0 and amount_cents <= 100000000),
  constraint expense_records_category_check check (
    category in ('SUPPLIES','FUEL','TOOLS','EQUIPMENT','MAINTENANCE','TRANSPORTATION','PHONE_OR_SERVICE','OTHER')
  ),
  constraint expense_records_date_check check (
    spent_on between date '2019-01-01' and (current_date + interval '366 days')
  )
);

create index expense_records_user_year_idx
  on public.expense_records(user_id, spent_on);

-- ----------------------------------------------------------------------------
-- Personal earning targets (voluntary; never a government threshold)
-- ----------------------------------------------------------------------------
create table public.financial_personal_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  year integer not null,
  amount_cents integer not null,
  label text not null default 'Personal earning target',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_personal_targets_amount_check check (amount_cents > 0),
  constraint financial_personal_targets_year_check check (year between 2019 and 2100),
  constraint financial_personal_targets_unique_user_year unique (user_id, year)
);

-- ----------------------------------------------------------------------------
-- Versioned financial rule engine (server authoritative)
-- ----------------------------------------------------------------------------
create table public.financial_rule_versions (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null,
  category text not null,
  program text not null default '',
  jurisdiction text not null default 'US',
  federal_or_state text not null default 'federal',
  state_code text,
  age_min integer,
  age_max integer,
  student_status_requirement text,
  income_type text,
  gross_or_net_basis text,
  threshold_cents bigint,
  transaction_count_condition text,
  effective_from date not null,
  effective_to date,
  last_reviewed_at timestamptz not null default now(),
  source_url text not null,
  source_agency text not null,
  rule_version text not null,
  status text not null default 'active',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_rule_versions_category_check check (
    category in ('TAX_INFORMATION_REPORTING','SELF_EMPLOYMENT','BENEFIT_PROGRAM','PERSONAL_TARGET','RECORDKEEPING_NOTICE')
  ),
  constraint financial_rule_versions_status_check check (status in ('active','retired','draft')),
  constraint financial_rule_versions_level_check check (federal_or_state in ('federal','state')),
  constraint financial_rule_versions_reviewed_check check (source_url like 'https://%')
);

create unique index financial_rule_versions_key_version_idx
  on public.financial_rule_versions(rule_key, rule_version);
create index financial_rule_versions_active_idx
  on public.financial_rule_versions(status, category) where status = 'active';

-- ----------------------------------------------------------------------------
-- Financial alert events (audit log of activated checks; informational only)
-- ----------------------------------------------------------------------------
create table public.financial_alert_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  year integer not null,
  rule_key text not null,
  level text not null,
  percent integer not null,
  created_at timestamptz not null default now(),
  constraint financial_alert_events_level_check check (
    level in ('HEADS_UP','FINANCIAL_CHECK','REVIEW_RECOMMENDED','THRESHOLD_REACHED')
  ),
  constraint financial_alert_events_year_check check (year between 2019 and 2100)
);

create index financial_alert_events_user_year_idx
  on public.financial_alert_events(user_id, year);

-- ----------------------------------------------------------------------------
-- RLS: strict owner-only access. No SSN columns exist anywhere above.
-- ----------------------------------------------------------------------------
alter table public.financial_preferences enable row level security;
alter table public.expense_records enable row level security;
alter table public.financial_personal_targets enable row level security;
alter table public.financial_rule_versions enable row level security;
alter table public.financial_alert_events enable row level security;

create policy financial_preferences_select_own on public.financial_preferences
  for select using (user_id = auth.uid());
create policy financial_preferences_insert_own on public.financial_preferences
  for insert with check (user_id = auth.uid());
create policy financial_preferences_update_own on public.financial_preferences
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy expense_records_select_own on public.expense_records
  for select using (user_id = auth.uid());
create policy expense_records_insert_own on public.expense_records
  for insert with check (user_id = auth.uid());
create policy expense_records_update_own on public.expense_records
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy expense_records_delete_own on public.expense_records
  for delete using (user_id = auth.uid());

create policy financial_personal_targets_all_own on public.financial_personal_targets
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy financial_alert_events_select_own on public.financial_alert_events
  for select using (user_id = auth.uid());

-- Rules: authenticated users may READ published rules. There is intentionally
-- NO insert/update/delete policy: normal users can never modify official
-- financial-rule records (fail-closed; only migration/admin processes write).
create policy financial_rule_versions_select_authenticated on public.financial_rule_versions
  for select to authenticated using (status in ('active','retired'));

-- ----------------------------------------------------------------------------
-- Private receipt storage
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'financial-receipts', 'financial-receipts', false, 10485760,
  array['image/jpeg','image/png','image/webp','application/pdf']::text[]
)
on conflict (id) do update
  set public = false,
      file_size_limit = 10485760,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf']::text[];

-- Owner-only access; object path must be rooted at the owner's uid folder.
create policy financial_receipts_owner_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'financial-receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy financial_receipts_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'financial-receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy financial_receipts_owner_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'financial-receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'financial-receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy financial_receipts_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'financial-receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ----------------------------------------------------------------------------
-- Shared helper: tracked compensation summary for one user/year.
-- Canonical earnings source is completed applications joined to their jobs.
-- Payment method NEVER resets or re-baselines earnings: every completed job
-- contributes to the same tracked gross total regardless of method.
-- ----------------------------------------------------------------------------
create or replace function public.get_my_financial_summary(p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_year_start date;
  v_year_end date;
  v_result jsonb;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_year not between 2019 and 2100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_year');
  end if;

  v_year_start := make_date(p_year, 1, 1);
  v_year_end := make_date(p_year, 12, 31);

  select jsonb_build_object(
    'ok', true,
    'year', p_year,
    'gross_tracked_cents', coalesce(sum(earn.amount_cents), 0),
    'jobs_completed', count(earn.*),
    'method_breakdown', coalesce(
      (select jsonb_agg(jsonb_build_object(
         'method', earn.method,
         'category', earn.category,
         'amount_cents', earn.total,
         'count', earn.cnt
       ) order by earn.total desc)
       from (
         select
           case j.payment_method
             when 'cash' then 'cash'
             when 'cash_app' then 'external_electronic'
             when 'square' then 'external_electronic'
             else 'other_direct'
           end as method,
           case j.payment_method
             when 'cash' then 'DIRECT_CASH'
             when 'cash_app' then 'DIRECT_ELECTRONIC'
             when 'square' then 'DIRECT_ELECTRONIC'
             else 'UNKNOWN_DIRECT'
           end as category,
           sum(coalesce(j.pay_amount_cents, 0))::bigint as total,
           count(*)::int as cnt
         from public.applications a
         join public.jobs j on j.id = a.job_id
         where a.teen_id = v_user
           and a.status = 'completed'
           and a.updated_at::date between v_year_start and v_year_end
         group by 1, 2
       ) earn),
      '[]'::jsonb
    ),
    'expenses_cents', (
      select coalesce(sum(e.amount_cents), 0)
      from public.expense_records e
      where e.user_id = v_user
        and e.spent_on between v_year_start and v_year_end
    ),
    'receipts_count', (
      select count(*)
      from public.expense_records e
      where e.user_id = v_user
        and e.spent_on between v_year_start and v_year_end
        and e.receipt_path is not null
    ),
    'expense_count', (
      select count(*)
      from public.expense_records e
      where e.user_id = v_user
        and e.spent_on between v_year_start and v_year_end
    ),
    'personal_targets', coalesce(
      (select jsonb_agg(jsonb_build_object(
         'id', t.id, 'year', t.year, 'amount_cents', t.amount_cents, 'label', t.label
       ) order by t.year)
       from public.financial_personal_targets t
       where t.user_id = v_user and t.year = p_year),
      '[]'::jsonb
    ),
    'disclaimer', 'Recordkeeping estimate — not a tax return or tax determination.'
  )
  into v_result
  from (
    select coalesce(j.pay_amount_cents, 0) as amount_cents
    from public.applications a
    join public.jobs j on j.id = a.job_id
    where a.teen_id = v_user
      and a.status = 'completed'
      and a.updated_at::date between v_year_start and v_year_end
  ) earn;

  return v_result;
end;
$$;

-- ----------------------------------------------------------------------------
-- Expense CRUD (server-validated; owner-only by construction and RLS)
-- ----------------------------------------------------------------------------
create or replace function public.create_my_expense(
  p_amount_cents integer,
  p_spent_on date,
  p_category text,
  p_merchant text default '',
  p_description text default '',
  p_job_id uuid default null,
  p_notes text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.expense_records;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_amount_cents is null or p_amount_cents <= 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_amount');
  end if;
  if p_category not in ('SUPPLIES','FUEL','TOOLS','EQUIPMENT','MAINTENANCE','TRANSPORTATION','PHONE_OR_SERVICE','OTHER') then
    return jsonb_build_object('ok', false, 'code', 'invalid_category');
  end if;
  if p_spent_on is null or p_spent_on > current_date + interval '366 days' or p_spent_on < date '2019-01-01' then
    return jsonb_build_object('ok', false, 'code', 'invalid_date');
  end if;

  insert into public.expense_records (
    user_id, amount_cents, spent_on, category, merchant, description, job_id, notes
  ) values (
    v_user, p_amount_cents, p_spent_on, p_category,
    left(coalesce(p_merchant, ''), 120),
    left(coalesce(p_description, ''), 500),
    p_job_id,
    left(coalesce(p_notes, ''), 500)
  )
  returning * into v_row;

  return jsonb_build_object('ok', true, 'expense', to_jsonb(v_row));
end;
$$;

create or replace function public.update_my_expense(
  p_id uuid,
  p_amount_cents integer default null,
  p_spent_on date default null,
  p_category text default null,
  p_merchant text default null,
  p_description text default null,
  p_job_id uuid default null,
  p_clear_job boolean default false,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.expense_records;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  update public.expense_records e set
    amount_cents = coalesce(p_amount_cents, e.amount_cents),
    spent_on = coalesce(p_spent_on, e.spent_on),
    category = coalesce(p_category, e.category),
    merchant = coalesce(p_merchant, e.merchant),
    description = coalesce(p_description, e.description),
    job_id = case when p_clear_job then null else coalesce(p_job_id, e.job_id) end,
    notes = coalesce(p_notes, e.notes),
    updated_at = now()
  where e.id = p_id and e.user_id = v_user
  returning * into v_row;

  if v_row is null then
    return jsonb_build_object('ok', false, 'code', 'expense_not_found');
  end if;
  return jsonb_build_object('ok', true, 'expense', to_jsonb(v_row));
end;
$$;

create or replace function public.delete_my_expense(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  delete from public.expense_records e
  where e.id = p_id and e.user_id = v_user;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'expense_not_found');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.list_my_expenses(p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_year not between 2019 and 2100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_year');
  end if;
  return jsonb_build_object(
    'ok', true,
    'expenses', coalesce(
      (select jsonb_agg(to_jsonb(e) order by e.spent_on desc, e.created_at desc)
       from public.expense_records e
       where e.user_id = v_user
         and e.spent_on between make_date(p_year, 1, 1) and make_date(p_year, 12, 31)),
      '[]'::jsonb
    )
  );
end;
$$;

-- Receipt registration: the object must live in the caller's own folder inside
-- the private financial-receipts bucket. Access is owner-only via storage RLS.
create or replace function public.set_my_expense_receipt(p_id uuid, p_path text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.expense_records;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_path is null or (storage.foldername(p_path))[1] is distinct from v_user::text then
    return jsonb_build_object('ok', false, 'code', 'invalid_receipt_path');
  end if;

  update public.expense_records e
    set receipt_path = p_path, updated_at = now()
  where e.id = p_id and e.user_id = v_user
  returning * into v_row;

  if v_row is null then
    return jsonb_build_object('ok', false, 'code', 'expense_not_found');
  end if;
  return jsonb_build_object('ok', true, 'expense', to_jsonb(v_row));
end;
$$;

-- ----------------------------------------------------------------------------
-- Preferences and personal targets
-- ----------------------------------------------------------------------------
create or replace function public.get_my_financial_preferences()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.financial_preferences;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_row from public.financial_preferences p where p.user_id = v_user;
  if v_row is null then
    return jsonb_build_object(
      'ok', true,
      'preferences', jsonb_build_object(
        'alerts_enabled', true,
        'benefit_programs', '[]'::jsonb,
        'guardian_financial_visibility', false
      )
    );
  end if;
  return jsonb_build_object('ok', true, 'preferences', to_jsonb(v_row));
end;
$$;

create or replace function public.set_my_financial_preferences(
  p_alerts_enabled boolean default null,
  p_benefit_programs text[] default null,
  p_guardian_financial_visibility boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.financial_preferences;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;

  insert into public.financial_preferences (user_id) values (v_user)
  on conflict (user_id) do nothing;

  update public.financial_preferences p set
    alerts_enabled = coalesce(p_alerts_enabled, p.alerts_enabled),
    benefit_programs = coalesce(p_benefit_programs, p.benefit_programs),
    guardian_financial_visibility = coalesce(p_guardian_financial_visibility, p.guardian_financial_visibility),
    updated_at = now()
  where p.user_id = v_user
  returning * into v_row;

  return jsonb_build_object('ok', true, 'preferences', to_jsonb(v_row));
end;
$$;

create or replace function public.upsert_my_financial_target(
  p_year integer,
  p_amount_cents integer,
  p_label text default 'Personal earning target'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.financial_personal_targets;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_year not between 2019 and 2100 or p_amount_cents is null or p_amount_cents <= 0 then
    return jsonb_build_object('ok', false, 'code', 'invalid_target');
  end if;

  insert into public.financial_personal_targets (user_id, year, amount_cents, label)
  values (v_user, p_year, p_amount_cents, left(coalesce(p_label, 'Personal earning target'), 80))
  on conflict (user_id, year) do update
    set amount_cents = excluded.amount_cents,
        label = excluded.label,
        updated_at = now()
  returning * into v_row;

  return jsonb_build_object('ok', true, 'target', to_jsonb(v_row));
end;
$$;

create or replace function public.delete_my_financial_target(p_year integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  delete from public.financial_personal_targets t
  where t.user_id = v_user and t.year = p_year;
  return jsonb_build_object('ok', true);
end;
$$;

-- ----------------------------------------------------------------------------
-- Financial rule engine: fail-closed stale handling.
-- A rule is stale when it is past its effective window or has not been
-- reviewed within 400 days. Stale rules are NEVER presented as current fact;
-- callers receive a stale notice plus the official source.
-- ----------------------------------------------------------------------------
create or replace function public.list_financial_rules(p_category text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  return jsonb_build_object(
    'ok', true,
    'rules', coalesce(
      (select jsonb_agg(
        to_jsonb(r) || jsonb_build_object(
          'is_stale',
          (r.status <> 'active'
            or (r.effective_to is not null and r.effective_to < current_date)
            or r.last_reviewed_at < now() - interval '400 days')
        ) order by r.category, r.program
       )
       from public.financial_rule_versions r
       where r.status <> 'draft'
         and (p_category is null or r.category = p_category)),
      '[]'::jsonb
    )
  );
end;
$$;

-- Financial Check evaluation. Purely informational: the result NEVER gates any
-- marketplace capability. Levels: 70 HEADS_UP, 85 FINANCIAL_CHECK,
-- 95 REVIEW_RECOMMENDED, 100 THRESHOLD_REACHED.
create or replace function public.evaluate_my_financial_alerts(p_year integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_summary jsonb;
  v_gross bigint;
  v_prefs public.financial_preferences%rowtype;
  v_alerts jsonb := '[]'::jsonb;
  v_target record;
  v_rule record;
  v_pct integer;
  v_level text;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_year not between 2019 and 2100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_year');
  end if;

  v_summary := public.get_my_financial_summary(p_year);
  v_gross := coalesce((v_summary ->> 'gross_tracked_cents')::bigint, 0);

  select * into v_prefs from public.financial_preferences p where p.user_id = v_user;

  -- Personal targets (always evaluated; labeled PERSONAL TARGET)
  for v_target in
    select * from public.financial_personal_targets t
    where t.user_id = v_user and t.year = p_year
  loop
    if v_target.amount_cents > 0 then
      v_pct := least(200, ((v_gross::numeric / v_target.amount_cents) * 100))::int;
      v_level := case
        when v_pct >= 100 then 'THRESHOLD_REACHED'
        when v_pct >= 95 then 'REVIEW_RECOMMENDED'
        when v_pct >= 85 then 'FINANCIAL_CHECK'
        when v_pct >= 70 then 'HEADS_UP'
        else null end;
      if v_level is not null and coalesce(v_prefs.alerts_enabled, true) then
        v_alerts := v_alerts || jsonb_build_object(
          'rule_key', 'personal_target_' || p_year,
          'label', 'PERSONAL TARGET',
          'level', v_level,
          'percent', v_pct,
          'basis', 'personal_target',
          'threshold_cents', v_target.amount_cents,
          'is_stale', false
        );
        insert into public.financial_alert_events (user_id, year, rule_key, level, percent)
        values (v_user, p_year, 'personal_target_' || p_year, v_level, v_pct)
        on conflict do nothing;
      end if;
    end if;
  end loop;

  -- Government-derived rules (informational only; stale rules fail closed)
  for v_rule in
    select r.*, public.list_financial_rules is null as _unused
    from public.financial_rule_versions r
    where r.status = 'active'
      and r.category in ('TAX_INFORMATION_REPORTING','SELF_EMPLOYMENT','BENEFIT_PROGRAM')
      and r.effective_from <= current_date
      and (r.effective_to is null or r.effective_to >= make_date(p_year, 1, 1))
      and (
        r.category <> 'BENEFIT_PROGRAM'
        or (v_prefs.user_id is not null and r.program = any (v_prefs.benefit_programs))
      )
  loop
    if v_rule.threshold_cents is not null and v_rule.threshold_cents > 0 then
      v_pct := least(200, ((v_gross::numeric / v_rule.threshold_cents) * 100))::int;
      v_level := case
        when v_pct >= 100 then 'THRESHOLD_REACHED'
        when v_pct >= 95 then 'REVIEW_RECOMMENDED'
        when v_pct >= 85 then 'FINANCIAL_CHECK'
        when v_pct >= 70 then 'HEADS_UP'
        else null end;
      if v_level is not null and coalesce(v_prefs.alerts_enabled, true) then
        v_alerts := v_alerts || jsonb_build_object(
          'rule_key', v_rule.rule_key,
          'label', 'RULE MAY APPLY',
          'level', v_level,
          'percent', v_pct,
          'basis', coalesce(v_rule.gross_or_net_basis, 'gross'),
          'program', v_rule.program,
          'threshold_cents', v_rule.threshold_cents,
          'source_url', v_rule.source_url,
          'source_agency', v_rule.source_agency,
          'rule_version', v_rule.rule_version,
          'is_stale', (
            v_rule.last_reviewed_at < now() - interval '400 days'
            or (v_rule.effective_to is not null and v_rule.effective_to < current_date)
          )
        );
        insert into public.financial_alert_events (user_id, year, rule_key, level, percent)
        values (v_user, p_year, v_rule.rule_key, v_level, v_pct)
        on conflict do nothing;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'year', p_year,
    'gross_tracked_cents', v_gross,
    'alerts', v_alerts,
    'work_status', 'unaffected',
    'notice', 'Financial checks are informational. They never block or limit your ability to keep working.'
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Guardian financial access: only an ACTIVE guardian whose teen has explicitly
-- enabled guardian_financial_visibility receives the teen's summary. Benefit
-- program selections are NEVER included in guardian output.
-- ----------------------------------------------------------------------------
create or replace function public.get_linked_teen_financial_summary(p_teen_id uuid, p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_summary jsonb;
  v_visibility boolean;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_teen_id is null or p_teen_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'invalid_request');
  end if;

  select (p.guardian_financial_visibility is true) into v_visibility
  from public.financial_preferences p where p.user_id = p_teen_id;

  if v_visibility is not true then
    return jsonb_build_object('ok', false, 'code', 'guardian_access_disabled');
  end if;

  if not exists (
    select 1 from public.guardian_connections g
    where g.teen_id = p_teen_id
      and g.guardian_id = v_user
      and g.status = 'active'
  ) then
    return jsonb_build_object('ok', false, 'code', 'not_linked_guardian');
  end if;

  v_summary := public.get_my_financial_summary(p_year);
  if v_summary is null or (v_summary ->> 'ok') is not true then
    return jsonb_build_object('ok', false, 'code', 'summary_unavailable');
  end if;

  return jsonb_build_object(
    'ok', true,
    'year', p_year,
    'gross_tracked_cents', v_summary -> 'gross_tracked_cents',
    'expenses_cents', v_summary -> 'expenses_cents',
    'jobs_completed', v_summary -> 'jobs_completed',
    'receipts_count', v_summary -> 'receipts_count',
    'personal_targets', v_summary -> 'personal_targets',
    'benefit_programs', null,
    'notice', 'Financial summary shared by the teen. Benefit program selections are never shared.'
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Export report rows (calendar year): completed-jobs compensation report and
-- expense report. Records only; never an official tax form.
-- ----------------------------------------------------------------------------
create or replace function public.get_my_financial_year_report(p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_start date;
  v_end date;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_year not between 2019 and 2100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_year');
  end if;
  v_start := make_date(p_year, 1, 1);
  v_end := make_date(p_year, 12, 31);

  return jsonb_build_object(
    'ok', true,
    'year', p_year,
    'earnings', coalesce(
      (select jsonb_agg(jsonb_build_object(
        'title', j.title,
        'completed_on', a.updated_at::date,
        'method', j.payment_method,
        'amount_cents', coalesce(j.pay_amount_cents, 0)
      ) order by a.updated_at)
       from public.applications a
       join public.jobs j on j.id = a.job_id
       where a.teen_id = v_user
         and a.status = 'completed'
         and a.updated_at::date between v_start and v_end),
      '[]'::jsonb
    ),
    'expenses', coalesce(
      (select jsonb_agg(jsonb_build_object(
        'spent_on', e.spent_on,
        'category', e.category,
        'merchant', e.merchant,
        'description', e.description,
        'amount_cents', e.amount_cents,
        'has_receipt', e.receipt_path is not null
      ) order by e.spent_on)
       from public.expense_records e
       where e.user_id = v_user
         and e.spent_on between v_start and v_end),
      '[]'::jsonb
    ),
    'disclaimer', 'For recordkeeping only. This report is not tax, legal, benefits, or financial advice.'
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Seeded federal rules. Versioned, sourced, dated. State rules are added by
-- future versions only with an official state-agency source.
-- ----------------------------------------------------------------------------
insert into public.financial_rule_versions (
  rule_key, category, program, jurisdiction, federal_or_state,
  age_min, age_max, income_type, gross_or_net_basis, threshold_cents,
  effective_from, last_reviewed_at, source_url, source_agency,
  rule_version, status, notes
) values
(
  'irs_self_employment_net_earnings', 'SELF_EMPLOYMENT', 'IRS', 'US', 'federal',
  13, 17, 'net_earnings', 'net', 40000,
  date '2026-01-01', now(),
  'https://www.irs.gov/businesses/small-businesses-self-employed/self-employed-individuals-tax-center',
  'IRS', '2026.1', 'active',
  'General educational reference: self-employment tax generally applies once net earnings from self-employment reach the annual threshold. MORT does not calculate individual tax. Review the official IRS source.'
),
(
  'irs_recordkeeping_notice', 'RECORDKEEPING_NOTICE', 'IRS', 'US', 'federal',
  13, 17, null, null, null,
  date '2026-01-01', now(),
  'https://www.irs.gov/publications/p334',
  'IRS', '2026.1', 'active',
  'Good records (income and expenses) make any future filing easier. This is recordkeeping guidance, not a filing requirement determination.'
),
(
  'snap_income_monitor_notice', 'BENEFIT_PROGRAM', 'SNAP', 'US', 'federal',
  13, 17, 'household_income', 'gross', null,
  date '2026-01-01', now(),
  'https://www.fns.usda.gov/snap/recipient/eligibility',
  'USDA FNS', '2026.1', 'active',
  'SNAP eligibility depends on household size, income, deductions, and state rules. MORT cannot determine household eligibility. Check the official program information.'
),
(
  'medicaid_income_monitor_notice', 'BENEFIT_PROGRAM', 'MEDICAID', 'US', 'federal',
  13, 17, 'household_income', 'gross', null,
  date '2026-01-01', now(),
  'https://www.medicaid.gov/medicaid/eligibility',
  'CMS', '2026.1', 'active',
  'Medicaid eligibility depends on household circumstances and state rules. MORT cannot determine eligibility. Review the official program information.'
),
(
  'chip_income_monitor_notice', 'BENEFIT_PROGRAM', 'CHIP', 'US', 'federal',
  13, 17, 'household_income', 'gross', null,
  date '2026-01-01', now(),
  'https://www.insurekidsnow.gov/coverage/index.html',
  'CMS', '2026.1', 'active',
  'CHIP eligibility depends on household circumstances and state rules. MORT cannot determine eligibility. Review the official program information.'
)
on conflict (rule_key, rule_version) do nothing;

-- ----------------------------------------------------------------------------
-- MORT Guide integration: financial-safety knowledge documents.
-- The Guide may help users understand records, alerts, and find official
-- resources. It must never advise evasion or make eligibility determinations.
-- ----------------------------------------------------------------------------
insert into public.support_kb_documents (
  slug, title, summary, content, source_url, navigation_route,
  document_type, status, audience, version, effective_at, review_due_at,
  approved_at
) values
(
  'earnings-safety-overview',
  'MORT Earnings Safety',
  'How MORT helps you keep earning while understanding taxes, records, and benefits.',
  'MORT Earnings Safety helps you keep track of the money you earn from jobs, the expenses you have, and when it may be time to review official information. Reaching a financial threshold NEVER stops you from working on MORT. Your records, receipts, and yearly summaries stay private to you (and a linked guardian only if you choose). MORT does not calculate your taxes and cannot determine benefits eligibility. For decisions about taxes or benefits, use the official resources MORT links to or talk with a professional.',
  'https://mortapp.org/safety',
  '/financial',
  'help', 'published', array['teen','adult','guardian']::text[],
  '2026.1', current_date, current_date + 180, now()
),
(
  'benefits-and-teen-earnings',
  'Benefits and teen earnings',
  'Why MORT cannot decide your benefits eligibility, and what to do instead.',
  'Different assistance programs treat teen earnings differently. MORT cannot determine your household eligibility from the app. MORT can show your earnings records and the official information it has for a program. If you are worried about how work might affect benefits, the best steps are: keep your records current, review the official program source MORT links to, and talk with your parent or guardian. MORT never recommends hiding income, using cash so nobody knows, switching to gift cards to avoid reporting, or splitting payments.',
  'https://www.fns.usda.gov/snap/recipient/eligibility',
  '/financial/benefits',
  'help', 'published', array['teen','adult','guardian']::text[],
  '2026.1', current_date, current_date + 180, now()
),
(
  'expenses-and-receipts',
  'Recording expenses',
  'How to record expenses and receipts so your records are ready when needed.',
  'You can record work-related expenses (supplies, fuel, tools, equipment, maintenance, transportation, phone service) and attach a receipt photo. Expenses are recorded as "recorded expenses" or "potential business expenses" — MORT does not decide whether an expense is deductible. Receipts are stored privately: only you can see them. You can export a yearly summary any time.',
  'https://www.irs.gov/publications/p334',
  '/financial/expenses',
  'help', 'published', array['teen','adult']::text[],
  '2026.1', current_date, current_date + 180, now()
)
on conflict (slug) do update set
  title = excluded.title,
  summary = excluded.summary,
  content = excluded.content,
  source_url = excluded.source_url,
  navigation_route = excluded.navigation_route,
  version = excluded.version,
  review_due_at = excluded.review_due_at,
  status = excluded.status,
  approved_at = now(),
  updated_at = now();

-- The support chatbot searches support_kb_chunks, not the documents table
-- directly, so the new financial-safety documents need their search chunks.
insert into public.support_kb_chunks (
  document_id, chunk_index, content, token_estimate
)
select document.id, 0, document.content,
  greatest(1, ceil(char_length(document.content)::numeric / 4)::integer)
from public.support_kb_documents document
where document.slug in (
  'earnings-safety-overview', 'benefits-and-teen-earnings', 'expenses-and-receipts'
)
on conflict (document_id, chunk_index) do update set
  content = excluded.content,
  token_estimate = excluded.token_estimate;

-- ----------------------------------------------------------------------------
-- MORT Guide runtime config: extend get_mort_guide_config (the function the
-- Flutter Guide screen actually calls) with the financial-safety surface and
-- its prohibitions. Original fields are preserved exactly.
-- ----------------------------------------------------------------------------
create or replace function public.get_mort_guide_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_control public.ai_runtime_controls%rowtype;
  v_consent text;
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select * into v_control from public.ai_runtime_controls where id;
  select status into v_consent from public.ai_processing_consents where user_id = auth.uid();
  return jsonb_build_object(
    'ok', true,
    'mode', v_control.mode,
    'external_provider_available', v_control.external_provider_enabled and not v_control.provider_circuit_open,
    'consent_status', coalesce(v_consent, case when public.current_profile_role() = 'teen' then 'not_requested' else 'not_applicable' end),
    'retention_days', v_control.retention_days,
    'daily_request_limit', v_control.daily_user_requests,
    'privacy_warning', 'Do not share IDs, passwords, exact addresses, or emergency evidence.',
    'financial_safety', jsonb_build_object(
      'enabled', true,
      'center_route', '/financial',
      'sections', jsonb_build_array(
        'EARNINGS', 'EXPENSES', 'FINANCIAL_CHECK', 'BENEFITS_CHECK',
        'PERSONAL_TARGETS', 'RECORDS_EXPORTS', 'KEEP_EARNING', 'LEARN'
      ),
      'actions', jsonb_build_array(
        'OPEN_EARNINGS', 'OPEN_EXPENSES', 'ADD_EXPENSE', 'OPEN_FINANCIAL_SAFETY',
        'OPEN_BENEFITS_CHECK', 'REVIEW_PERSONAL_TARGET', 'DOWNLOAD_RECORDS',
        'OPEN_OFFICIAL_RESOURCE', 'TALK_WITH_GUARDIAN', 'CONTACT_SUPPORT'
      ),
      'policy', 'The Guide may explain records, alerts, and official resources. It must never advise hiding income, avoiding reporting, using cash to avoid detection, switching payment methods to evade thresholds, splitting payments, or leaving work unrecorded. It must never claim to be a CPA, tax attorney, benefits caseworker, or financial adviser, and it must never make individual tax or benefits eligibility determinations.',
      'refusal_route', '/financial'
    )
  );
end;
$$;

grant execute on function public.get_mort_guide_config() to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- MORT Guide config: expose the financial-safety surface and its prohibitions.
-- support_get_config is extended (original fields preserved) so the assistant
-- knows Financial Safety exists and must refuse evasion requests.
-- ----------------------------------------------------------------------------
create or replace function public.support_get_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_preferences public.support_user_preferences%rowtype;
  v_account_status text;
  v_deletion_pending boolean;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  select profile.account_status::text into v_account_status
  from public.profiles profile where profile.id = auth.uid();
  if v_account_status is null then
    return jsonb_build_object('ok', false, 'code', 'profile_required');
  end if;
  select exists (
    select 1 from public.account_deletion_requests request
    where request.user_id = auth.uid()
      and request.status in ('requested', 'processing', 'retry_pending')
  ) into v_deletion_pending;

  select * into v_preferences
  from public.support_user_preferences preference
  where preference.user_id = auth.uid();

  return jsonb_build_object(
    'ok', true,
    'assistant_enabled', coalesce(v_preferences.assistant_enabled, true),
    'save_history', coalesce(v_preferences.save_history, true),
    'retention_days', coalesce(v_preferences.retention_days, 30),
    'human_support_available', true,
    'guardian_chat_access', false,
    'account_restricted', v_account_status <> 'active',
    'deletion_pending', v_deletion_pending,
    'warning', 'Do not share passwords, PINs, verification codes, payment credentials, government IDs, exact home addresses, or emergency evidence.',
    'financial_safety', jsonb_build_object(
      'enabled', true,
      'center_route', '/financial',
      'sections', jsonb_build_array(
        'EARNINGS', 'EXPENSES', 'FINANCIAL_CHECK', 'BENEFITS_CHECK',
        'PERSONAL_TARGETS', 'RECORDS_EXPORTS', 'KEEP_EARNING', 'LEARN'
      ),
      'actions', jsonb_build_array(
        'OPEN_EARNINGS', 'OPEN_EXPENSES', 'ADD_EXPENSE', 'OPEN_FINANCIAL_SAFETY',
        'OPEN_BENEFITS_CHECK', 'REVIEW_PERSONAL_TARGET', 'DOWNLOAD_RECORDS',
        'OPEN_OFFICIAL_RESOURCE', 'TALK_WITH_GUARDIAN', 'CONTACT_SUPPORT'
      ),
      'policy', 'The Guide may explain records, alerts, and official resources. It must never advise hiding income, avoiding reporting, using cash to avoid detection, switching payment methods to evade thresholds, splitting payments, or leaving work unrecorded. It must never claim to be a CPA, tax attorney, benefits caseworker, or financial adviser, and it must never make individual tax or benefits eligibility determinations.',
      'refusal_route', '/financial'
    )
  );
end;
$$;

-- Grant execute on the new RPCs to authenticated users.
grant execute on function
  public.get_my_financial_summary(integer),
  public.create_my_expense(integer, date, text, text, text, uuid, text),
  public.update_my_expense(uuid, integer, date, text, text, text, uuid, boolean, text),
  public.delete_my_expense(uuid),
  public.list_my_expenses(integer),
  public.set_my_expense_receipt(uuid, text),
  public.get_my_financial_preferences(),
  public.set_my_financial_preferences(boolean, text[], boolean),
  public.upsert_my_financial_target(integer, integer, text),
  public.delete_my_financial_target(integer),
  public.list_financial_rules(text),
  public.evaluate_my_financial_alerts(integer),
  public.get_linked_teen_financial_summary(uuid, integer),
  public.get_my_financial_year_report(integer)
to authenticated;
