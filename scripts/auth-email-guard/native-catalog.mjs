export function nativeCatalogCoverage(resources){
  if(!Array.isArray(resources)||!resources.length)return {passed:false,uncovered:['missing-native-catalog']};
  const known=new Set(['private_bucket','private_channel','published_table']);
  const uncovered=resources.filter(r=>!r||typeof r.name!=='string'||!known.has(r.kind)||r.reachable!==false&&(r.reachable!==true||r.sessionGuardCovered!==true||r.kind==='private_bucket'&&r.public!==false||r.kind==='private_channel'&&r.privateOnly!==true||r.kind==='published_table'&&r.rlsEnabled!==true)).map(r=>r?.name??'invalid-resource');
  return {passed:uncovered.length===0,uncovered};
}
