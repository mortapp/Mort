export function assertLongRunSafety({durationMs,powerRequestVerified}){
 if(!Number.isFinite(durationMs)||durationMs<0)throw new Error('Invalid run duration');
 if(durationMs>600000&&powerRequestVerified!==true)throw new Error('Sleep prevention not verified; long run refused');
 return true;
}
