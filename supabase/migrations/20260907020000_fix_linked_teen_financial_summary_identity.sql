-- Bug found while transferring the Financial Safety feature from the
-- preserved PR #4 checkout: get_linked_teen_financial_summary(p_teen_id,
-- p_year) authorizes the caller correctly (guardian_financial_visibility
-- opt-in + an active guardian_connections link) but then calls
-- public.get_my_financial_summary(p_year), which internally reads
-- v_user := auth.uid(). auth.uid() reflects the JWT of the actual calling
-- session regardless of how many SECURITY DEFINER functions are nested
-- inside one another -- it does not become the teen's id just because this
-- function's argument is named p_teen_id. The guardian would therefore
-- receive their OWN (empty/irrelevant) financial summary, not the linked
-- teen's, despite the authorization checks being correct.
--
-- Fix: inline the same aggregate computation parameterized on p_teen_id
-- instead of delegating to the auth.uid()-based helper. Deliberately not
-- refactored into a shared private helper function (which would need new
-- grant/privilege wiring this session cannot execute against a live
-- database to verify) -- duplicating this already-correct, already-reviewed
-- query with the id source swapped is the lower-risk fix. Output shape is
-- unchanged: still excludes method_breakdown and always nulls
-- benefit_programs, matching the original's privacy intent (guardians never
-- see payment-method detail or benefit-program selections).

create or replace function public.get_linked_teen_financial_summary(p_teen_id uuid, p_year integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_visibility boolean;
  v_year_start date;
  v_year_end date;
  v_gross_cents bigint;
  v_jobs_completed integer;
  v_expenses_cents bigint;
  v_receipts_count integer;
  v_personal_targets jsonb;
begin
  if v_user is null or not public.is_profile_active(v_user) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if p_teen_id is null or p_teen_id = v_user then
    return jsonb_build_object('ok', false, 'code', 'invalid_request');
  end if;
  if p_year not between 2019 and 2100 then
    return jsonb_build_object('ok', false, 'code', 'invalid_year');
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

  v_year_start := make_date(p_year, 1, 1);
  v_year_end := make_date(p_year, 12, 31);

  select coalesce(sum(j.pay_amount_cents), 0)::bigint, count(*)::int
  into v_gross_cents, v_jobs_completed
  from public.applications a
  join public.jobs j on j.id = a.job_id
  where a.teen_id = p_teen_id
    and a.status = 'completed'
    and a.updated_at::date between v_year_start and v_year_end;

  select coalesce(sum(e.amount_cents), 0)::bigint into v_expenses_cents
  from public.expense_records e
  where e.user_id = p_teen_id
    and e.spent_on between v_year_start and v_year_end;

  select count(*)::int into v_receipts_count
  from public.expense_records e
  where e.user_id = p_teen_id
    and e.spent_on between v_year_start and v_year_end
    and e.receipt_path is not null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id, 'year', t.year, 'amount_cents', t.amount_cents, 'label', t.label
  ) order by t.year), '[]'::jsonb)
  into v_personal_targets
  from public.financial_personal_targets t
  where t.user_id = p_teen_id and t.year = p_year;

  return jsonb_build_object(
    'ok', true,
    'year', p_year,
    'gross_tracked_cents', v_gross_cents,
    'expenses_cents', v_expenses_cents,
    'jobs_completed', v_jobs_completed,
    'receipts_count', v_receipts_count,
    'personal_targets', v_personal_targets,
    'benefit_programs', null,
    'notice', 'Financial summary shared by the teen. Benefit program selections are never shared.'
  );
end;
$$;
