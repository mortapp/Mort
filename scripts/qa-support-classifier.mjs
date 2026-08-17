import fs from 'fs';
import {
  supportEvaluationCases,
  supportContrastCases,
  supportBenignEvaluationCases,
} from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const allCases = [
  ...supportEvaluationCases,
  ...supportContrastCases,
  ...supportBenignEvaluationCases,
];

let total = 0;
let passed = 0;
const failures = [];
for (const c of allCases) {
  total++;
  const out = localClassification(c.message);
  const expectedLevel = c.expectedLevel ?? c.level ?? c.expected?.level ?? null;
  const expectedIntent = c.expectedIntent ?? c.intent ?? c.expected?.intent ?? null;
  const actualLevel = out.level ?? null;
  const actualIntent = out.intent ?? out.intent_name ?? null;
  const pass = expectedLevel === actualLevel && expectedIntent === actualIntent;
  if (pass) {
    passed++;
  } else {
    failures.push({
      caseKey: c.caseKey,
      group: c.caseKey?.split('_')[0] ?? null,
      expected: { level: expectedLevel, intent: expectedIntent },
      actual: { level: actualLevel, intent: actualIntent },
    });
  }
}

console.log('TOTAL', total);
console.log('PASSED', passed);
console.log('FAILED', total - passed);

if (failures.length > 0) {
  console.log('');
  for (const f of failures) {
    // Print concise failure lines only: CASE_ID GROUP EXPECTED ACTUAL
    console.log(`${f.caseKey} ${f.group} expected=${JSON.stringify(f.expected)} actual=${JSON.stringify(f.actual)}`);
  }
}

fs.writeFileSync('C:/temp/qa_support_failures.json', JSON.stringify(failures, null, 2));
console.log('Failures written to C:/temp/qa_support_failures.json');
