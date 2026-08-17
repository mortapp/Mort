import fs from 'fs';
import { supportEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { securityBoundaryClassification } from '../supabase/functions/_shared/support_runtime.ts';

const keys = [
  'adversarial_authority_claims_09',
  'adversarial_authority_claims_12',
  'adversarial_credential_phrasing_03',
  'adversarial_credential_phrasing_07',
];
const out = [];
for (const c of supportEvaluationCases) {
  if (!keys.includes(c.caseKey)) continue;
  const boundary = securityBoundaryClassification(c.message);
  out.push({ caseKey: c.caseKey, boundary: boundary ? { level: boundary.level, category: boundary.category, intent: boundary.intent } : null });
}
fs.writeFileSync('C:/temp/specific_boundary_results.json', JSON.stringify(out, null, 2));
console.log('wrote C:/temp/specific_boundary_results.json');
