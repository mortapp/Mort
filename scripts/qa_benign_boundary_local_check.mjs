import fs from 'fs';
import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { securityBoundaryClassification, localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const target = 'benign';
const out = [];
for (const c of all) {
  if (!c.caseKey.startsWith(target)) continue;
  const boundary = securityBoundaryClassification(c.message);
  const local = localClassification(c.message);
  const pass = local.intent === c.expectedIntent && local.level === c.expectedLevel;
  if (!pass) out.push({ caseKey: c.caseKey, expectedLevel: c.expectedLevel, expectedIntent: c.expectedIntent, boundary: boundary ? {level: boundary.level, category: boundary.category, intent: boundary.intent} : null, local: {level: local.level, intent: local.intent, category: local.category} });
}
fs.writeFileSync('C:/temp/benign_boundary_local.json', JSON.stringify(out, null, 2));
console.log('wrote C:/temp/benign_boundary_local.json entries:', out.length);
