import fs from 'fs';
import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { securityBoundaryClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const target = 'trust_safety';
const out = [];
for (const c of all) {
  if (!c.caseKey.startsWith(target)) continue;
  const b = securityBoundaryClassification(c.message);
  out.push({ caseKey: c.caseKey, boundary: b ? { level: b.level, category: b.category, intent: b.intent } : null });
}
fs.writeFileSync('C:/temp/trust_safety_boundary_results.json', JSON.stringify(out, null, 2));
console.log('wrote C:/temp/trust_safety_boundary_results.json');
