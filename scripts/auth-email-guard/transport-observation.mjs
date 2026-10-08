const transports=['postgrest','storage','realtime'];
const measurementFailure=()=>{throw new Error('Transport measurement failed: invalid state or clock');};
const finite=value=>typeof value==='number'&&Number.isFinite(value);

// Observe actual responses without changing JWT expiry or the strict policy.
// Validate the entire sample before mutating its evidence row.
export function recordTransportSample(row,sample,{signedExpiryMs,lifecycleAtMs,checkedAtMs}={}){
  if(!row||typeof row!=='object'||Array.isArray(row)||!sample||typeof sample!=='object'
    ||!finite(signedExpiryMs)||!finite(lifecycleAtMs))measurementFailure();
  const result={};
  for(const name of transports){
    const value=sample[name];
    if(!value||typeof value!=='object')measurementFailure();
    const measuredAt=Object.hasOwn(value,'checkedAtMs')?value.checkedAtMs:checkedAtMs;
    if(!finite(measuredAt))measurementFailure();
    let accepted,denied;
    if(name==='realtime'){
      if(!['ok','error','http_401','http_403'].includes(value.status))measurementFailure();
      accepted=value.status==='ok';denied=!accepted;
    }else{
      if(typeof value.accepted!=='boolean'||typeof value.denied!=='boolean'
        ||value.accepted===value.denied||!Number.isInteger(value.status)||value.status<100||value.status>599)measurementFailure();
      accepted=value.accepted;denied=value.denied;
    }
    result[name]={status:value.status,accepted,denied,checkedAtMs:measuredAt,
      elapsedMs:measuredAt-lifecycleAtMs,afterSignedExpiryMs:measuredAt-signedExpiryMs};
  }
  const allAccepted=transports.every(name=>result[name].accepted);
  const allDenied=transports.every(name=>result[name].denied);
  row.perTransport??={};
  for(const name of transports){
    const observed=result[name],previous=row.perTransport[name]??{};
    const next={...previous,status:observed.accepted?'ACCEPTED':'DENIED',
      checkedAtMs:observed.checkedAtMs,afterSignedExpiryMs:observed.afterSignedExpiryMs};
    if(observed.accepted)next.lastAcceptedMs=observed.elapsedMs;
    else if(previous.firstRejectedMs===undefined){
      next.firstRejectedMs=observed.elapsedMs;
      next.rejectionAfterSignedExpiryMs=observed.afterSignedExpiryMs;
    }
    row.perTransport[name]=next;
  }
  if(!row.strictExpiryCheck&&transports.every(name=>result[name].checkedAtMs>=signedExpiryMs+1000)){
    const measuredAt=Math.max(...transports.map(name=>result[name].checkedAtMs));
    row.strictExpiryCheck={policy:'REJECT_BY_SIGNED_EXPIRY_PLUS_1_SECOND',
      status:allDenied?'NO_ACCEPTANCE_OBSERVED_AT_THIS_SAMPLE':'RED_FINDING',
      checkedAtMs:measuredAt,afterSignedExpiryMs:measuredAt-signedExpiryMs,result};
  }
  return {allAccepted,allDenied};
}
