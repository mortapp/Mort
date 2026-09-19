create or replace function public.support_classify_intent(p_message text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.is_profile_active(auth.uid()) then
    return jsonb_build_object('ok', false, 'code', 'authentication_required');
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 3 and 2000 then
    return jsonb_build_object('ok', false, 'code', 'invalid_support_message');
  end if;
  if not private.support_take_rate_limit(auth.uid(), 'intent', 60, 600) then
    return jsonb_build_object('ok', false, 'code', 'support_rate_limited');
  end if;
  return jsonb_build_object('ok', true, 'classification', private.support_classify_message(p_message));
end;
$$;;
