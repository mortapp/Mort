import fs from 'fs';
import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const target = 'trust_safety';
const failing = [];
for (const c of all) {
  if (!c.caseKey.startsWith(target)) continue;
  const actual = localClassification(c.message);
  const pass = actual.intent === c.expectedIntent && actual.level === c.expectedLevel;
  if (!pass) failing.push({ caseKey: c.caseKey, expectedLevel: c.expectedLevel, expectedIntent: c.expectedIntent, actualLevel: actual.level, actualIntent: actual.intent, message: c.message });
}

const tokens = ['verification code','verification','cvv','cvc','password','card number','ssn','social security','api key','service-role key','developer message','system prompt','private transcript','messages'];
const messageVerbs = ['received','got a message','got','dm','dmed','messaged','message said','message','sender','sent me','i was sent','i received'];
const askVerbs = ['asked','asked me','asked for','told me to','told me','requested','requested my','wanted me to','pressured me','tried to make me','asked that'];

const out = [];
for (const f of failing){
  const l = f.message.toLowerCase();
  const hasToken = tokens.filter(t=> l.includes(t));
  const hasMessageVerb = messageVerbs.filter(t=> l.includes(t));
  const hasAskVerb = askVerbs.filter(t=> l.includes(t));
  out.push({ caseKey: f.caseKey, expectedLevel: f.expectedLevel, actualLevel: f.actualLevel, actualIntent: f.actualIntent, hasToken: hasToken.length>0, tokensFound: hasToken, hasMessageVerb: hasMessageVerb.length>0, messageVerbsFound: hasMessageVerb, hasAskVerb: hasAskVerb.length>0, askVerbsFound: hasAskVerb });
}
fs.writeFileSync('C:/temp/trust_safety_debug.json', JSON.stringify(out, null, 2));
console.log('wrote C:/temp/trust_safety_debug.json entries:', out.length);
