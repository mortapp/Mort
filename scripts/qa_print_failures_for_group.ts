import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const target = 'trust_safety';
for (const c of all) {
  if (!c.caseKey.startsWith(target)) continue;
  const actual = localClassification(c.message);
  const pass = actual.intent === c.expectedIntent && actual.level === c.expectedLevel;
  if (!pass) {
    console.log(`${c.caseKey} ${target} ${c.expectedLevel} ${c.expectedIntent} ${actual.level} ${actual.intent} ${actual.category}`);
  }
}
