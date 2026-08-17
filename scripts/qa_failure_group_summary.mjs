import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const all = [...supportEvaluationCases, ...supportContrastCases, ...supportBenignEvaluationCases];
const failures = [];
for (const c of all) {
  const actual = localClassification(c.message);
  const pass = actual.intent === c.expectedIntent && actual.level === c.expectedLevel;
  if (!pass) failures.push({id:c.caseKey, prefix:c.caseKey.split('_').slice(0,-1).join('_')});
}
// count per prefix
const counts = failures.reduce((acc,f)=>{acc[f.prefix]=(acc[f.prefix]||0)+1;return acc;},{})
// Map prefixes to major groups
const majorGroups = {
  trust_safety: ['trust_safety','adversarial_authority_claims','adversarial_credential_phrasing','adversarial_credential_phrasing','adversarial_authority_claims'],
  quoted_hostile_content: ['quoted_hostile_content','quoted_hostile_content_benign'],
  prompt_extraction_malicious: ['prompt_extraction_malicious','prompt_extraction_benign'],
  secret_extraction_malicious: ['secret_extraction_malicious','secret_extraction_benign'],
  guardian: ['guardian_mode_benign','adult_guardian_account_flow_benign','guardian_mode_benign'],
  holdout_benign_25_plus: ['holdout_benign_25_plus'],
};
const summary = {};
for (const [prefix,n] of Object.entries(counts)){
  let placed = false;
  for (const [major,arr] of Object.entries(majorGroups)){
    if (arr.includes(prefix)) { summary[major]=(summary[major]||0)+n; placed=true; break; }
  }
  if (!placed) { summary.other=(summary.other||0)+n; }
}
// compute benign by looking at prefixes containing 'benign' or 'teen' or 'support'
for (const [prefix,n] of Object.entries(counts)){
  if (/benign|teen|support|profile|payment|privacy_question|identity_verification|payment_explanations|profile_reviews|teen_/.test(prefix)){
    summary.benign = (summary.benign||0) + n;
  }
}
// print requested categories
const categories = ['trust_safety','quoted_hostile_content','prompt_extraction_malicious','secret_extraction_malicious','guardian','guardian_mode','guardian_account','benign','other'];
for (const cat of categories){
  console.log(`${cat}: ${summary[cat]||0}`);
}

// subdivide major groups by root cause (list prefixes in each)
console.log('\nSubdivisions:');
for (const [major,arr] of Object.entries(majorGroups)){
  const items = Object.entries(counts).filter(([p])=>arr.includes(p)).map(([p,n])=>`${p}: ${n}`);
  if (items.length) { console.log(`${major}:`); for(const it of items) console.log(`  ${it}`); }
}
// list top other prefixes
console.log('\nTop other prefixes:');
const otherList = Object.entries(counts).filter(([p])=> !Object.values(majorGroups).flat().includes(p)).sort((a,b)=>b[1]-a[1]);
for (const [p,n] of otherList.slice(0,20)) console.log(`  ${p}: ${n}`);
