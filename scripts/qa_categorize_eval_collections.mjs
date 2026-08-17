import fs from 'fs';
import path from 'path';
const root = path.resolve('.');
const supportRuntime = fs.readFileSync(path.join(root,'supabase','functions','_shared','support_runtime.ts'),'utf8');
const evalCases = fs.readFileSync(path.join(root,'supabase','functions','_shared','support_eval_cases.ts'),'utf8');
// extract intent string literals from support_runtime
const intentRegex = /intent:\s*"([a-z0-9_]+)"/gi;
const knownIntents = new Set();
let m;
while ((m = intentRegex.exec(supportRuntime)) !== null) knownIntents.add(m[1]);
// also extract intents mentioned as expectedIntent in cases file
const caseBlockRegex = /\.\.\.cases\(\s*"([a-zA-Z0-9_]+)"[\s\S]*?,\s*"([a-z0-9_]+)",[\s\S]*?\)/g;
const groups = [];
while ((m = caseBlockRegex.exec(evalCases)) !== null) {
  groups.push({prefix:m[1], expectedIntent:m[2]});
}
// categorize each group
const results = groups.map(g => {
  const inKnown = knownIntents.has(g.expectedIntent);
  return {prefix:g.prefix, expectedIntent:g.expectedIntent, category: inKnown ? 'CLASSIFIER_APPLICABLE' : 'AMBIGUOUS'};
});
console.log(JSON.stringify({knownIntents:Array.from(knownIntents).sort(), groups:results},null,2));
