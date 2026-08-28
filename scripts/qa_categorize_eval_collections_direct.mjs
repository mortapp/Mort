import fs from 'fs';
import path from 'path';
const root = path.resolve('.');
const supportRuntime = fs.readFileSync(path.join(root,'supabase','functions','_shared','support_runtime.ts'),'utf8');
const evalCases = fs.readFileSync(path.join(root,'supabase','functions','_shared','support_eval_cases.ts'),'utf8');
const intentRegex = /intent:\s*"([a-z0-9_]+)"/gi;
const knownIntents = new Set();
let m;
while ((m = intentRegex.exec(supportRuntime)) !== null) knownIntents.add(m[1]);
const allCaseBlockRegex = /\.\.\.cases\(\s*"([a-zA-Z0-9_]+)"[\s\S]*?,\s*"([a-z0-9_]+)",[\s\S]*?\)/g;

function findGroupsInSection(source, sectionName) {
  const sectionStart = source.indexOf(sectionName);
  if (sectionStart === -1) return [];
  // crude: find next occurrence of '];' after section start which ends that export
  const endIdx = source.indexOf('];', sectionStart);
  const sectionText = endIdx === -1 ? source.slice(sectionStart) : source.slice(sectionStart, endIdx);
  const groups = [];
  let mm;
  while ((mm = allCaseBlockRegex.exec(sectionText)) !== null) groups.push({prefix:mm[1], expectedIntent:mm[2]});
  return groups;
}

const evalGroups = findGroupsInSection(evalCases, 'export const supportEvaluationCases');
const contrastGroups = findGroupsInSection(evalCases, 'export const supportContrastCases');
const benignGroups = findGroupsInSection(evalCases, 'export const supportBenignEvaluationCases');

function categorize(groups){
  return groups.map(g=>({prefix:g.prefix, expectedIntent:g.expectedIntent, category: knownIntents.has(g.expectedIntent)?'CLASSIFIER_APPLICABLE':'AMBIGUOUS'}));
}

const evalCat = categorize(evalGroups);
const contrastCat = categorize(contrastGroups);
const benignCat = categorize(benignGroups);

function printCollection(name, list){
  console.log(`${name}: ${list.length}`);
  const by = list.reduce((a,r)=>{(a[r.category]=a[r.category]||[]).push(r);return a},{})
  for (const k of Object.keys(by)) console.log(`  ${k}: ${by[k].length}`);
}

printCollection('supportEvaluationCases', evalCat);
printCollection('supportContrastCases', contrastCat);
printCollection('supportBenignEvaluationCases', benignCat);

console.log('');
console.log('Groups classified as AMBIGUOUS (non-classifier likely):');
for (const r of [...evalCat,...contrastCat,...benignCat].filter(x=>x.category==='AMBIGUOUS')) console.log(`  ${r.prefix} (${r.expectedIntent})`);
