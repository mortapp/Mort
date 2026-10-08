import {validateCoverage} from './coverage.mjs';
// Explicit semantic crosswalk. These keys identify assertions that must actually
// execute successfully in this invocation; a suite name or file presence never
// grants PASS. Unavailable integrations retain an explicit BLOCKED disposition.
const mappings=new Map();
const add=(numbers,...assertions)=>{for(const n of numbers){if(mappings.has(n))throw new Error('Duplicate requirement mapping');mappings.set(n,{id:`MD2-${String(n).padStart(3,'0')}`,disposition:'EXECUTE',assertions});}};
const block=(numbers,reason)=>{for(const n of numbers){if(mappings.has(n))throw new Error('Duplicate requirement mapping');mappings.set(n,{id:`MD2-${String(n).padStart(3,'0')}`,disposition:'BLOCKED',assertions:[],reason});}};
const unit=name=>`unit:${name}`;
const parser=unit('Continue accepts locator plus exactly one recognized credential and binding');
const duplicate=unit('duplicate keys including escaped keys and nested objects fail before use');
const gateway=unit('gateway rejects disabled, arbitrary routes/methods/query/Origin and ambiguous bodies without authority');
const shape=unit('canonical failures share response and 350ms schedule; success returns only bounded committed capability');
const signed=unit('signature, freshness and canonical parsing denials never enqueue');
const policy=unit('password policy is revealed only after verifier possession; raw password never reaches SQL; pending is not success');
const browser='browser:disposable real browser: scanner/reload/back make no redemption; human-only POST, memory verifier, green/red and headers';
const build='browser:guard page builder defaults off; explicit fixture build has no third-party SDK, query authority or weak headers';
const load='load:Bounded actual gateway load must pass';
const delivered='delivery:Actual isolated encrypted delivery and real gateway must pass without exposing runtime secrets';
add([1,27,83,124,127,148],shape);
add([2,3,4,5,6,138,184],duplicate,gateway);
add([7,8,9,10,11,17,33,53,106,146,147],gateway,parser);
add([12,187],'state:Cross-item secret must be denied','state:Wrong recognized secret debits addressed family only');
add([13,16,79,80,84,186],unit('password requires capability and verifier, never email or extra authority'),parser,'grant:Capability binds server-owned account/purpose');
add([14,35,36,117,171],'state:Wrong code/link must share failure budget','state:Fifth failure permanently exhausts the family');
add([15,123],unit('outbox AEAD binds ciphertext to item context; tamper and wrong key fail'),'state:Cross-item secret must be denied');
add([18],'state:Old challenge cannot redeem after the actual account address changes');
add([19],'state:Deleted-account challenge cannot redeem, recreate account or charge another family');
add([89],'state:Deletion racing redemption leaves no usable password-reset permission','state:Deletion racing redemption leaves no active orphan proof','retention:Orphan generation and proof data removed after authority is gone');
add([20,169],'issuance:Older grace can never re-enter','issuance:At most current and previous items remain eligible');
add([21,92,93],'issuance:Uncommitted signup defers instead of sending','issuance:Rolled-back signup expires and purges ciphertext');
add([22,23,25,26],unit('eight-digit sampling rejects biased upper range and preserves leading zero'),parser);
add([24,139],parser,'state:Wrong recognized secret debits addressed family only');
add([30],unit('short-code HMAC binds context and key; digest comparisons reject shape'));
add([31],unit('independent secrets have canonical 256-bit transport'));
add([32,103,104,107,108,109,110,111,112,116,188],browser,build);
add([34,153],'cutover:Restored once-used item cannot issue authority again','cutover:Restored capability cannot reserve again','cutover:Restored old Admin grant cannot change a password','cutover:Runner restart refuses old or partially transitioned database authority');
add([37],'state:Four failures followed by success consumes exactly once');
add([38],'state:Failure after success never mutates or resurrects family');
add([39],'state:Concurrent wrong guesses debit one serialized family budget');
add([43],'state:Successful just-before-expiry control consumes live family');
add([40],'state:Concurrent correct and wrong guesses consume once without resurrection');
add([41],'issuance:Resend cooldown begins at successful promotion','issuance:Sixth account-purpose family is denied regardless of source');
add([42,170,172,173,174],'issuance:Resend cannot renew family expiry','issuance:Resend never resets failure count','state:Grace success atomically consumes current item too');
add([44,45,78],'grant:At/after expiry never reserves','grant:Dispatched-live write rechecks expiry after lock and preserves password');
add([46,140],signed,'state:Family deadline is checked after lock wait and creates no capability');
add([47,48,49,50,54],signed,unit('missing owned ingress binding and disabled mode fail closed despite signed payload'));
add([51,55],'issuance:Same event replay is idempotent','issuance:Modified event replay is rejected','issuance:Idempotent replay charges one family admission');
add([57,58,59,60,62,64],'bypass:GET, POST token-hash and typed provider-code forms cannot mint a guarded session','bypass:Provider-only confirmation variants do not verify pending account','bypass:Legitimate verified password remains live after provider-bypass denial');
add([63,121,143],'grant:Original signup password never becomes usable','grant:One supported transaction confirms and replaces password','cutover:Pending user never inherits baseline');
add([66],'unit:rejectsObservedMismatch: providerVersion');
add([68,179,180],'grant:Spoofed metadata without private grant cannot authorize','grant:Operation correlator is removed from minted claims');
add([69],'bypass:Forged JWT cannot read account or establish authenticated authority');
add([72],'grant:Current proved refresh remains supported','grant:Final guarded reset revokes old refresh session');
add([74,76],'security:Private reads must reject client database roles','security:No private helper may be executed by client roles');
add([77,85],'grant:Reservation is one use','grant:Committed grant cannot mutate a second time','state:Two actual concurrent connections produce exactly one consume success');
add([94],'grant:One grant permits exactly one of two actual concurrent Admin password writes');
add([81,149,167],policy,'grant:Policy denial keeps capability issued',unit('UTF16 password boundaries agree with approved policy'));
add([82],delivered,shape);
add([86],unit('provider rejects hosted/disabled targets and unknown outcome never becomes success'),'grant:Provider-transaction commit reconciles privately','grant:Expired operation reconciles terminally');
add([151],'grant:Dispatched-live write rechecks expiry after lock and preserves password','grant:Committed grant cannot mutate a second time','grant:Provider-transaction commit reconciles privately');
add([182],'grant:Lost actual Admin response and unavailable reconciliation never report success','grant:Unknown outcome uses an actual committed provider write and destroyed response socket','grant:Lost Admin response never reopens consumed capability','grant:Private reconciliation resolves actual lost Admin response safely','grant:Retry of reconciled lost operation cannot repeat provider mutation','grant:Owner can sign in with committed replacement after lost-response reconciliation');
add([88,181],'grant:Old Admin body cannot borrow a currently reserved newer grant','grant:New legitimate operation still completes after stale request denial','retention:Delayed old provider write remains denied after cleanup');
add([90,91],'issuance:New family never cancels the already-issued independent capability','state:Grace success atomically consumes current item too');
add([96],'issuance:Late acknowledgment cannot promote an expired attempt','issuance:Ambiguous delivery is never promoted','issuance:Ambiguous successor preserves last delivered item');
add([99,100,125,128],unit('strict bound mailbox and signed hook structural action allowlist'),unit('outbox AEAD binds ciphertext to item context; tamper and wrong key fail'));
add([101,102],delivered,build,unit('response and log shapes cannot carry supplied secrets'));
add([113,114],'browser:double-click, disposal and stale asynchronous completion cannot reopen password UI','browser:Busy keeps the same verifier/link; unknown lost response is terminal and cannot rebind or replay');
add([118,130],load,'issuance:Source fifth attempt exhausts its sixth dispatch across different recipients','issuance:Recipient sixth dispatch is denied even with a fresh source');
add([119,132],'issuance:Eight real connections atomically admit at most twenty of twenty-four queued events','issuance:Forty-first global attempt is denied','issuance:Recipient sixth dispatch is denied even with a fresh source');
add([120,133,156,175],load,unit('250ms store deadline aborts active work and returns Busy without raw credentials or dispatcher use'));
add([122],'grant:OAuth cannot legitimize preconfirmation password','grant:Unverified provider claim cannot confirm pending owner');
add([131],'state:Wrong recognized secret debits addressed family only','state:Unrelated legitimate family remains usable');
add([137,152],'grant:Direct public password update cannot borrow a private reserved operation','grant:Spoofed metadata without private grant cannot authorize','bypass:Provider-only confirmation variants do not verify pending account');
add([141],'grant:Address change-and-change-back cannot revive old capability','grant:Address change-back requires fresh proof before password sign-in');
add([142],'cutover:Concurrent confirmation cannot inherit pre-cutover baseline proof','cutover:Concurrent confirmation original password cannot sign in without proof');
add([144],'bypass:Disabled phone provider cannot produce login challenge','bypass:Disabled anonymous provider cannot produce session');
add([150],'bypass:Provider-only confirmation variants do not verify pending account','retention:Delayed cleanup replay cannot verify pending user');
add([154],'cutover:Verified login works after rollback','cutover:Restored once-used item cannot issue authority again');
add([155],'unit:acceptsExactSyntheticFixture','unit:cleanupNeverTouchesOtherResources','unit:duplicate or invented resource roles cannot satisfy observed identity');
add([158],'delivery:Protocol stall requires the exact owned capture resource');
add([159],'security:No private helper may be executed by client roles','grant:Direct public password update cannot borrow a private reserved operation');
add([161,185,189],browser,parser,delivered);
add([176],'issuance:Same event replay is idempotent','issuance:Late acknowledgment cannot promote an expired attempt','issuance:At most current and previous items remain eligible');
add([177,178],'unit:process environment allowlist excludes credentials and remote Docker targets','unit:cleanupNeverTouchesOtherResources');
add([183],parser,gateway);
add([190],'state:Capability lease is independently fixed at 300 seconds','issuance:New family never cancels the already-issued independent capability');
add([191],'grant:Dispatched-live write rechecks expiry after lock and preserves password','grant:Committed grant cannot mutate a second time','retention:Delayed old provider write remains denied after cleanup');
add([28],unit('missing HMAC key rejects code checking without weak fallback or store mutation'));
block([29],'Deployment HMAC key-rotation rehearsal requires the actual key-manager lifecycle; wrong-key AEAD units are narrower evidence.');
add([160],'unit:sanitized evidence requires exact candidate, fixture, executed assertions, cleanup and fixed redacted shape','unit:runtime assertion capture cannot turn an unexecuted or failing assertion into evidence');
add([52],unit('new transport ID cannot reuse an old signed event'));
add([56],unit('hook dependency timeout aborts before issuance and legitimate retry remains live'),'issuance:Eight real connections atomically admit at most twenty of twenty-four queued events');
add([67],'hook-boundary:Client user_metadata verification claims cannot replace private address proof');
add([71],'hook-boundary:Refresh after provider-only confirmation without private proof fails closed');
add([73],'hook-boundary:Actual GoTrue hook timeout fails closed before five-second fixture deadline','hook-boundary:Hook timeout recovery restores legitimate sign-in');
add([75],'hook-boundary:Malformed provider method or claim type cannot exploit token-hook truthiness');
block([65],'Final Auth probes observe password/oauth/otp/token_refresh and real PKCE controls execute. Complete intended hosted provider/session-path inventory, including live Google/Apple compatibility, remains an integration gate.');
add([87],'state:Address change racing redemption leaves no usable stale authority or charged guess');
add([105],'issuance:Worker cannot claim a queued message after actual recipient binding changes','issuance:Address-change race clears stale encrypted recipient payload');
add([129],'bypass:Provider email case canonicalization cannot create a second account sharing proof','bypass:Distinct alias cannot inherit verified address proof or usable password');
add([97],'smtp-fault:Actual owned SMTP fault produces no delivery acknowledgment','issuance:Failed SMTP outcome cannot promote challenge eligibility');
add([98],'smtp-fault:Authentication failure, untrusted certificate and TLS downgrade send no email DATA');
block([126],'Credential-free notification previews need the intended mail-client/device path. Server subject/redaction checks cannot certify arbitrary client snippets.');
add([61],'bypass:PKCE denial uses a genuine provider-created code and matching verifier','bypass:Valid PKCE exchange cannot mint an unauthorized pending-account session','bypass:Real PKCE token hook denies provider-confirmed account lacking private proof','bypass:PKCE positive control proves real code and matching verifier are otherwise redeemable');
block([70,145],'PostgREST/Storage/Realtime old-JWT policy needs those transports in the isolated fixture; existing Auth tests do not certify them.');
block([95],'A single fixture database is not an HA failover topology. Restore/restart evidence does not certify replica failover.');
block([115,135,136],'Native Android/email-gateway compatibility requires the intended device/mail path; no emulator or external mail is authorized in this run.');
block([134],'Arbitrary same-origin script compromise cannot be disproved by CSP/page tests. Dedicated origin, service-worker scope and hosted page isolation remain deployment gates.');
block([157],'Pinned-version refusal is tested; a second provider-version drift fixture has not been executed.');
for(const n of [162,163,164,165,166])mappings.set(n,{id:`MD2-${n}`,disposition:'OWNER_SCOPED_OUT',assertions:[],reason:'Approved Continue-only design excludes a peek route. Route-absence assertion executes in the gateway/browser suite.'});
block([168],'Approved overlap policy is executed. Separate unapproved immediate-supersession/redelivery policy fixtures are not activated or silently claimed.');
export const caseMappings=[...mappings.values()].sort((a,b)=>a.id.localeCompare(b.id));
export const operationalMappings=[
  {id:'MD-115',disposition:'EXECUTE',assertions:['security:Every private table denies actual SELECT INSERT UPDATE DELETE for untrusted database roles','security:No private helper may be executed by client roles']},
  {id:'MD-116',disposition:'EXECUTE',assertions:[unit('missing signing encryption or HMAC configuration never issues a challenge'),unit('missing SMTP configuration fails closed before opening any transport'),unit('partial activation and missing runtime/key configuration cannot pass the full cutover gate')]},
  {id:'MD-117',disposition:'EXECUTE',assertions:[unit('partial activation and missing runtime/key configuration cannot pass the full cutover gate'),'cutover:Partial fixture readiness cannot activate the full guard']},
  {id:'MD-118',disposition:'EXECUTE',assertions:['cutover:Verified login works after rollback','cutover:Rollback never reopens a consumed guard challenge','cutover:Pending user never inherits baseline']},
  {id:'MD-119',disposition:'BLOCKED',assertions:[],reason:'Owned Auth/DB/SMTP logs and browser/redaction tests execute, but hosted traces/metrics/error-reporting and deployed SMTP/browser sinks have not been inspected. Fixture privacy configuration does not certify hosted telemetry.'},
  {id:'MD-120',disposition:'EXECUTE',assertions:['cutover:Snapshot expired and consumed challenges remain unusable after actual restore','cutover:Restored once-used item cannot issue authority again','cutover:Restored capability cannot reserve again','cutover:Restored old Admin grant cannot change a password','cutover:Restore never revives a pre-backup refresh session revoked by recovery','retention:Expired encrypted recipient/payload erased immediately','state:Deletion racing redemption leaves no active orphan proof']},
];
validateCoverage(Array.from({length:191},(_,i)=>`MD2-${String(i+1).padStart(3,'0')}`),caseMappings);
export function runCase(id,observations,context){
  const mapping=[...caseMappings,...operationalMappings].find(row=>row.id===id);if(!mapping)throw new Error('Unowned requirement');
  if(mapping.disposition!=='EXECUTE')return {id,status:mapping.disposition,reason:mapping.reason,assertions:[],...context};
  const proofs=mapping.assertions.map(key=>observations.find(record=>record.key===key));
  if(proofs.some(proof=>!proof||proof.status!=='PASS'))return {id,status:'NOT_RUN',reason:'A required named assertion did not execute successfully in this run.',assertions:[],...context};
  return {id,status:'PASS',assertions:proofs,...context};
}
