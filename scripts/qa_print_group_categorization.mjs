import fs from 'fs';
const data = JSON.parse(fs.readFileSync('C:/temp/eval_collections_categorized.json','utf8'));
const groups = data.groups;
const byCat = {};
for (const g of groups) {
  byCat[g.category] = byCat[g.category] || [];
  byCat[g.category].push(g.prefix + ' ('+g.expectedIntent+')');
}
const totalGroups = groups.length;
console.log(`TOTAL_GROUPS: ${totalGroups}`);
for (const k of Object.keys(byCat).sort()) {
  console.log(`${k}: ${byCat[k].length}`);
}
console.log('');
for (const k of Object.keys(byCat).sort()) {
  console.log(`--- ${k} ---`);
  for (const item of byCat[k]) console.log(item);
  console.log('');
}
