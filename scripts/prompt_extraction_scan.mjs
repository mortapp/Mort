import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const failures = JSON.parse(Deno.readTextFileSync('C:/temp/qa_support_failures.json'));
const promptFails = failures.filter(f => (f.caseKey || '').startsWith('prompt_'));

function flagsFor(msg) {
  const v = String(msg).toLowerCase();
  return {
    HAS_SHOW_VERB: /\b(?:show|print|reveal|display|read back|read|repeat|dump|expose|return)\b/i.test(v),
    HAS_POSSESSIVE_TARGET: /\b(?:your|my|their|the)\b/.test(v),
    HAS_TARGET_KEYWORD: /\b(?:system prompt|developer message|developer instructions|hidden instructions|service[- ]?role key|service role key)\b/i.test(v),
    IS_QUESTION_WORD: /\b(?:what|why|how|can you|could you)\b/i.test(v),
  };
}

for (const f of promptFails) {
  const caseKey = f.caseKey;
  const metaCases = [...supportEvaluationCases, ...(supportContrastCases||[]), ...(supportBenignEvaluationCases||[])];
  const c = metaCases.find(x => x.caseKey === caseKey);
  if (!c) {
    console.log(JSON.stringify({ caseKey, note: 'meta_not_found' }));
    continue;
  }
  const expected = { level: f.expected?.level ?? null, intent: f.expected?.intent ?? null };
  const actualRaw = localClassification(c.message) || null;
  const actual = { level: actualRaw?.level ?? null, intent: actualRaw?.intent ?? actualRaw?.intent_name ?? null, category: actualRaw?.category ?? null, provider_allowed: actualRaw?.provider_allowed ?? null };
  const flags = flagsFor(c.message);
  console.log(JSON.stringify({ caseKey, expected, actual, flags }));
}
