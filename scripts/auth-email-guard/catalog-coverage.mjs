export function catalogCoverage(resources,{gateVerified,policies}){
  const valid=Array.isArray(resources)&&resources.length>0&&Array.isArray(policies);
  const uncovered=valid?resources.filter(row=>row.reachable!==false&&!(row.reachable===true&&((gateVerified===true&&['table','view','rpc'].includes(row.kind))||policies.includes(row.name)))).map(row=>row.name):['invalid-catalog'];
  return {passed:valid&&uncovered.length===0,uncovered};
}
