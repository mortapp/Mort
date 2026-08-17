import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const allCases = [
  ...(supportEvaluationCases || []),
  ...(supportContrastCases || []),
  ...(supportBenignEvaluationCases || []),
];

function urgentSignalFor(value) {
  const v = String(value).toLowerCase();
  const urgentSignal = (/(?:\b(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack|assault)\b).{0,40}(?:here|right now|now|immediate|trapped|at the job|at work|near me|in this area)/i.test(v)) || (/((?:here|right now|now|immediate|trapped|at the job|at work|near me|in this area).{0,40}(?:\b(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack|assault)\b))/i.test(v));
  return !!urgentSignal;
}

const signalFalsePos = [];
const urgentFalseNeg = [];
for (const c of allCases) {
  const sig = urgentSignalFor(c.message);
  const expectedLevel = c.expectedLevel ?? c.level ?? c.expected?.level ?? null;
  const expectedIntent = c.expectedIntent ?? c.intent ?? c.expected?.intent ?? null;
  const actual = localClassification(c.message) || {};
  const actualLevel = actual.level ?? null;
  const actualIntent = actual.intent ?? actual.intent_name ?? null;

  if (sig && expectedLevel !== 3) {
    signalFalsePos.push({ caseKey: c.caseKey, expected: { level: expectedLevel, intent: expectedIntent }, actual: { level: actualLevel, intent: actualIntent } });
  }
  if (expectedLevel === 3 && actualLevel !== 3) {
    urgentFalseNeg.push({ caseKey: c.caseKey, expected: { level: expectedLevel, intent: expectedIntent }, actual: { level: actualLevel, intent: actualIntent } });
  }
}

console.log('URGENT_SIGNAL_FALSE_POSITIVE_CANDIDATES_COUNT:', signalFalsePos.length);
for (const s of signalFalsePos) console.log(`${s.caseKey} expected=${JSON.stringify(s.expected)} actual=${JSON.stringify(s.actual)}`);
console.log('\nURGENT_FALSE_NEGATIVES_COUNT:', urgentFalseNeg.length);
for (const s of urgentFalseNeg) console.log(`${s.caseKey} expected=${JSON.stringify(s.expected)} actual=${JSON.stringify(s.actual)}`);
