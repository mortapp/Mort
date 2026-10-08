import {validPassword} from '../password-policy.mjs';
const invalid='That link or code is not valid. Request a new email.';
const policy='Use 12–128 characters with uppercase, lowercase, a number and a symbol.';
const uuid=value=>typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
function canonicalSecret(value){
  if(typeof value!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(value))return false;
  try{const raw=atob(value.replaceAll('-','+').replaceAll('_','/')+'=');return raw.length===32&&btoa(raw).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'')===value;}catch{return false;}
}
export function createChallengeController({transport,crypto,now=()=>Date.now(),onState,clearFragment}){
  let epoch=0,phase='neutral',inflight=false,itemId,linkSecret,verifier,capability,capabilityExpiresAt;
  let abort=new AbortController(),publicState={state:'neutral'};
  const clear=()=>{itemId=linkSecret=verifier=capability=capabilityExpiresAt=undefined;};
  const emit=(state,message,extras={})=>{phase=state;publicState=Object.freeze({state,message,...extras});onState(publicState);};
  const terminal=()=>{clear();emit('failure',invalid);};
  const random=()=>btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
  const digest=async value=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),n=>n.toString(16).padStart(2,'0')).join('');
  const isBusy=result=>result?.ok===false&&result.retryAfterSeconds===1&&result.message==='MORT is busy. Try again shortly.';
  return {
    load(fragment){
      epoch++;abort.abort();abort=new AbortController();inflight=false;clear();
      // Strip history before parsing or rendering. Loading never redeems.
      clearFragment();
      try{
        if(typeof fragment!=='string'||fragment.length>1024)throw new Error('Invalid input');
        const values=new URLSearchParams(fragment.replace(/^#/,'')),keys=[...values.keys()];
        if(keys.some(k=>!['itemId','linkSecret'].includes(k))||new Set(keys).size!==keys.length)throw new Error('Invalid input');
        if(values.has('itemId')){if(!uuid(values.get('itemId')))throw new Error('Invalid input');itemId=values.get('itemId');}
        if(values.has('linkSecret')){if(!itemId||!canonicalSecret(values.get('linkSecret')))throw new Error('Invalid input');linkSecret=values.get('linkSecret');}
        emit('neutral','Press Continue to check your link, or enter the code from your email.');
      }catch{terminal();}
    },
    continue:async(code)=>{
      if(phase!=='neutral'||inflight)return;
      const useCode=typeof code==='string'&&code.length>0;
      if(!itemId||(useCode?!/^\d{8}$/.test(code):!linkSecret)){emit('neutral','Open your latest MORT email or enter its eight-digit code.');return;}
      const generation=epoch;inflight=true;emit('continuing','Checking…');
      try {
        verifier??=random();const verifierHash=await digest(verifier);if(generation!==epoch)return;
        const result=await transport.continue({itemId,...(useCode?{code}:{linkSecret}),verifierHash},abort.signal);
        if(generation!==epoch)return;
        if(isBusy(result)){emit('neutral','MORT is busy. Try again shortly.',{retryAfterSeconds:1});return;}
        if(result?.ok!==true||!canonicalSecret(result.capability)||!['confirmation','recovery'].includes(result.purpose)||typeof result.maskedRecipient!=='string'||!/^.{1}\*\*\*@[^@\s]{1,253}$/.test(result.maskedRecipient)||![result.familyExpiresAt,result.capabilityExpiresAt].every(value=>typeof value==='string'&&Number.isFinite(Date.parse(value)))||Date.parse(result.capabilityExpiresAt)<=now()){terminal();return;}
        capability=result.capability;capabilityExpiresAt=Date.parse(result.capabilityExpiresAt);itemId=linkSecret=undefined;
        emit('password',result.purpose==='confirmation'?'Email checked. Choose a new password to replace the password entered at signup.':'Reset link checked. Choose a new password.',{purpose:result.purpose,maskedRecipient:result.maskedRecipient,familyExpiresAt:result.familyExpiresAt,capabilityExpiresAt:result.capabilityExpiresAt});
      }catch{if(generation===epoch)terminal();}finally{if(generation===epoch)inflight=false;}
    },
    submitPassword:async(password,confirmation)=>{
      if(phase!=='password'||inflight||!capability||!verifier)return;
      if(now()>=capabilityExpiresAt){terminal();return;}
      if(password!==confirmation){emit('password','The passwords do not match.');return;}
      if(!validPassword(password)){emit('password',policy);return;}
      const generation=epoch;inflight=true;emit('submitting','Updating your password…');
      try {
        const result=await transport.password({capability,verifier,password},abort.signal);
        if(generation!==epoch)return;
        if(isBusy(result)){emit('password','MORT is busy. Try again shortly.',{retryAfterSeconds:1});return;}
        if(result?.ok===false&&result.message==='Choose a password that meets the requirements.'){emit('password',policy);return;}
        if(result?.ok===true&&result.message==='Password updated. Return to MORT to sign in.'){clear();emit('success','Password updated. Return to MORT to sign in.');}else terminal();
      }catch{if(generation===epoch)terminal();}finally{if(generation===epoch)inflight=false;}
    },
    dispose(){epoch++;abort.abort();clear();inflight=false;emit('neutral','Open your latest MORT email to continue.');},
    snapshot(){return publicState;},
  };
}
