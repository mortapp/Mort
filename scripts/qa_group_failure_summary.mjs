import fs from 'fs';
const failures = JSON.parse(fs.readFileSync('C:/temp/qa_support_failures.json','utf8'));
const families = {
  urgent_safety: [],
  trust_safety: [],
  quoted_reporting: [],
  prompt_extraction: [],
  secret_extraction: [],
  cross_user: [],
  sensitive_data_disclosure: [],
  guardian: [],
  benign_support: [],
  other: [],
};

for (const f of failures) {
  const key = f.caseKey || '';
  const grp = f.group || '';
  const lower = key.toLowerCase();
  let family = 'other';
  if (/^urgent|^emergency|urgent_mixed_intent/.test(lower) || lower.startsWith('urgent')) family = 'urgent_safety';
  else if (lower.startsWith('trust')) family = 'trust_safety';
  else if (grp === 'quoted' || lower.startsWith('quoted') || lower.startsWith('quoted_hostile_content')) family = 'quoted_reporting';
  else if (grp === 'prompt' || lower.includes('prompt_extraction') || lower.includes('prompt')) family = 'prompt_extraction';
  else if (grp === 'secret' || lower.includes('secret_extraction') || lower.includes('credential')) family = 'secret_extraction';
  else if (lower.includes('authority') || lower.includes('profiles') || lower.includes('dump') || lower.includes("another user's") || lower.includes("another user") || lower.includes('cross_user') || lower.includes('cross')) family = 'cross_user';
  else if (grp === 'sensitive' || lower.startsWith('sensitive') || lower.includes('ssn') ) family = 'sensitive_data_disclosure';
  else if (grp === 'guardian' || lower.startsWith('guardian')) family = 'guardian';
  else if (/^teen_|^adult_|^marketplace|^account|^billing|^human|^general|^privacy|^report_block|^support_contact|^teen_job_pin_benign|^teen_safety_center_benign/.test(lower)) family = 'benign_support';
  else family = 'other';

  families[family].push(f);
}

function printSummary() {
  const totals = {};
  for (const k of Object.keys(families)) totals[k] = families[k].length;
  const totalFailures = failures.length;
  console.log('FULL_CLASSIFIER_FAILED', totalFailures);
  for (const k of Object.keys(totals)) console.log(`${k} ${totals[k]}`);
  console.log('');
  for (const fam of Object.keys(families)) {
    if (families[fam].length === 0) continue;
    console.log(`-- ${fam} (${families[fam].length})`);
    for (const f of families[fam]) {
      console.log(`${f.caseKey} ${f.group} expected=${JSON.stringify(f.expected)} actual=${JSON.stringify(f.actual)}`);
    }
  }
}

printSummary();
fs.writeFileSync('C:/temp/qa_failure_family_counts.json', JSON.stringify(Object.fromEntries(Object.entries(families).map(([k,v])=>[k,v.length])),null,2));
console.log('WROTE C:/temp/qa_failure_family_counts.json');
