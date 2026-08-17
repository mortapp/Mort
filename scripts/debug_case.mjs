import { supportEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';

const key = Deno.args[0] || 'general_22';
const c = supportEvaluationCases.find(x => x.caseKey === key);
if (!c) {
  console.error('case not found');
  Deno.exit(2);
}
const msg = c.message;
const weaponRe = /(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack)/i;
const locRe = /(?:here|right now|now|immediate|trapped|at the job|at work|someone here|near me|in the car|in this area)/i;
const proxRe = /(?:(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack).{0,30}(?:here|right now|now|immediate|trapped|at the job|at work|someone here|near me|in the car|in this area)|(?:here|right now|now|immediate|trapped|at the job|at work|someone here|near me|in the car|in this area).{0,30}(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack))/i;

const weaponMatch = msg.match(weaponRe)?.[0] ?? null;
const locMatch = msg.match(locRe)?.[0] ?? null;
const prox = proxRe.test(msg);
console.log(JSON.stringify({ caseKey: key, weaponMatch, locMatch, prox }));
