import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';
const failures = JSON.parse(Deno.readTextFileSync('C:/temp/qa_support_failures.json'));
const secretFails = failures.filter(f => (f.caseKey || '').startsWith('secret_'));

function flags(vRaw) {
  const v = String(vRaw).toLowerCase();
  return {
    HAS_RETRIEVAL_VERB: /\b(?:tell me|show me|read back|give me|send me|print|read|reveal|share|display|return|dump|expose)\b/i.test(v),
    HAS_SECRET_NOUN: /\b(?:password|verification code|cvv|cvc|pin|ssn|passport|card number|api key|service[- ]?role key|2fa|recovery code)\b/i.test(v),
    HAS_NEGATION: /\b(?:never|don't|do not|wouldn't|would not|not going to)\b/i.test(v),
    HAS_RESET_FLOW: /\b(?:reset|change|recover|forgot|reset my password|how do i reset)\b/i.test(v),
  };
}

for (const f of secretFails) {
  const caseKey = f.caseKey;
  const metaCases = [...supportEvaluationCases, ...(supportContrastCases||[]), ...(supportBenignEvaluationCases||[])];
  const c = metaCases.find(x => x.caseKey === caseKey);
  if (!c) { console.log(JSON.stringify({ caseKey, note: 'meta_not_found' })); continue; }
  const expected = { level: f.expected?.level ?? null, intent: f.expected?.intent ?? null };
  const actualRaw = localClassification(c.message) || null;
  const actual = { level: actualRaw?.level ?? null, intent: actualRaw?.intent ?? actualRaw?.intent_name ?? null, category: actualRaw?.category ?? null, provider_allowed: actualRaw?.provider_allowed ?? null };
  const featureFlags = flags(c.message);
  console.log(JSON.stringify({ caseKey, expected, actual, featureFlags }));
}
