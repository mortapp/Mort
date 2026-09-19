-- Remove the invalid function-qualified expression from the informational
-- financial-alert query. The expression had no FROM-clause binding and was
-- not used by the function's result.
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

  for v_rule in
    select r.*
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
