import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const failures: {id:string,prefix:string}[] = [];
for (const c of all) {
  const actual = localClassification(c.message);
  const pass = actual.intent === c.expectedIntent && actual.level === c.expectedLevel;
  if (!pass) failures.push({id:c.caseKey, prefix:c.caseKey.split('_').slice(0,-1).join('_')});
}
const counts: Record<string,number> = {};
for (const f of failures) counts[f.prefix] = (counts[f.prefix] ?? 0) + 1;

const majorGroups: Record<string,string[]> = {
  trust_safety: ['trust_safety','adversarial_authority_claims','adversarial_credential_phrasing'],
  quoted_hostile_content: ['quoted_hostile_content','quoted_hostile_content_benign'],
  prompt_extraction_malicious: ['prompt_extraction_malicious','prompt_extraction_benign'],
  secret_extraction_malicious: ['secret_extraction_malicious','secret_extraction_benign'],
  guardian: ['guardian_mode_benign','adult_guardian_account_flow_benign','guardian_mode_benign','adult_guardian_account_flow_benign'],
  holdout_benign_25_plus: ['holdout_benign_25_plus'],
};

// assign each failure to at most one major group, in priority order
const orderedMajors = ['trust_safety','quoted_hostile_content','prompt_extraction_malicious','secret_extraction_malicious','guardian','holdout_benign_25_plus'];
const assignment: Record<string, number> = {};
const assignedPrefixes = new Set();
for (const f of failures) {
  const prefix = f.prefix;
  let assigned = false;
  for (const major of orderedMajors) {
    if (majorGroups[major].includes(prefix)) {
      assignment[major] = (assignment[major] ?? 0) + 1;
      assigned = true;
      assignedPrefixes.add(prefix);
      break;
    }
  }
  if (!assigned) {
    // heuristic: benign prefixes
    if (/benign|teen|support|profile|payment|privacy_question|identity_verification|payment_explanations|profile_reviews|teen_/.test(prefix)) {
      assignment.benign = (assignment.benign ?? 0) + 1;
      assignedPrefixes.add(prefix);
    } else {
      assignment.other = (assignment.other ?? 0) + 1;
      assignedPrefixes.add(prefix);
    }
  }
}

// print categories
const categories = ['trust_safety','quoted_hostile_content','prompt_extraction_malicious','secret_extraction_malicious','guardian','guardian_mode','guardian_account','benign','other','holdout_benign_25_plus'];
for (const cat of categories) console.log(`${cat}: ${assignment[cat] ?? 0}`);

console.log('\nSubdivisions:');
for (const major of Object.keys(majorGroups)){
  console.log(major+':');
  for (const prefix of majorGroups[major]){
    console.log(`  ${prefix}: ${counts[prefix] ?? 0}`);
  }
}

console.log('\nTop other prefixes:');
const otherList = Object.entries(counts).filter(([p])=> !Array.from(Object.values(majorGroups).flat()).includes(p)).sort((a,b)=>b[1]-a[1]);
for (const [p,n] of otherList.slice(0,40)) console.log(`  ${p}: ${n}`);

console.log('\nSubdivisions:');
for (const [major,arr] of Object.entries(majorGroups)){
  const items = Object.entries(counts).filter(([p])=>arr.includes(p)).map(([p,n])=>`${p}: ${n}`);
  if (items.length) { console.log(`${major}:`); for (const it of items) console.log(`  ${it}`); }
}

console.log('\nTop other prefixes:');
const otherListVars = Object.entries(counts).filter(([p])=> !Object.values(majorGroups).flat().includes(p)).sort((a,b)=>b[1]-a[1]);
for (const [p,n] of otherListVars.slice(0,40)) console.log(`  ${p}: ${n}`);
