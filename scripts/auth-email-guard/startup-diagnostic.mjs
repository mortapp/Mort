const phases=new Set(['state','identity','preflight','tls','database-start','database-health','schema','journal','auth-start','auth-health','observe']);
export async function runStartup(run,{emit=row=>console.error('Fixture startup failure: '+JSON.stringify(row)),snapshot=()=>({unavailable:true})}={}){
 let phase='state';const context={state:null,phase(value){if(!phases.has(value))throw new Error('Unreviewed startup phase');phase=value;}};
 try{return await run(context);}
 catch(error){
  emit({phase,name:['Error','TypeError','AssertionError','TimeoutError','AbortError'].includes(error.name)?error.name:'unclassified'});
  try{emit({phase,snapshot:await snapshot(context.state)});}catch{emit({phase,snapshotUnavailable:true});}
  throw error;
 }
}
