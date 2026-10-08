import config from './config.mjs';
import {createChallengeTransport} from './transport.mjs';
import {createChallengeController} from './controller.mjs';
const byId=id=>document.getElementById(id);
const status=byId('status'),continueForm=byId('continue-form'),passwordForm=byId('password-form');
const password=byId('password'),confirmation=byId('confirmation'),code=byId('code'),target=byId('target'),deadlines=byId('deadlines');
const clearFields=()=>{password.value='';confirmation.value='';code.value='';};
const fragment=location.hash,unexpectedQuery=location.search.length>0;
// No secrets in history, storage, analytics, DOM attributes or a network request on load.
history.replaceState(null,'',location.pathname);
let controller;
try {
  if(unexpectedQuery||window.top!==window.self||navigator.serviceWorker?.controller||!crypto?.subtle)throw new Error('Guard page unavailable');
  controller=createChallengeController({
    transport:createChallengeTransport(config),crypto,clearFragment:()=>history.replaceState(null,'',location.pathname),
    onState(state){
      const success=state.state==='success',error=state.state==='failure';
      status.className='status'+(success?' success':error?' error':'');
      status.textContent=(success?'✓ ':error?'✕ ':'')+state.message;
      const passwordPhase=['password','submitting'].includes(state.state),busy=['continuing','submitting'].includes(state.state);
      continueForm.hidden=passwordPhase||success||error;passwordForm.hidden=!passwordPhase;
      byId('continue').disabled=busy;byId('update').disabled=busy;
      if(state.maskedRecipient){target.textContent='For '+state.maskedRecipient;target.hidden=false;}
      if(state.familyExpiresAt&&state.capabilityExpiresAt){deadlines.textContent='Email challenge expires '+new Date(state.familyExpiresAt).toLocaleTimeString()+'. Complete this password step by '+new Date(state.capabilityExpiresAt).toLocaleTimeString()+'.';deadlines.hidden=false;}
      if(success||error||state.state==='neutral'){target.hidden=true;deadlines.hidden=true;if(success||error)clearFields();}
    },
  });
  controller.load(fragment);
  continueForm.addEventListener('submit',event=>{event.preventDefault();controller.continue(code.value);});
  passwordForm.addEventListener('submit',event=>{
    event.preventDefault();const operation=controller.submitPassword(password.value,confirmation.value);
    // The controller already copied the values; clear visible fields before awaiting transport.
    password.value='';confirmation.value='';void operation;
  });
}catch{
  status.className='status error';status.textContent='✕ This security page is unavailable. Open your latest MORT email or contact support.';
  continueForm.hidden=true;passwordForm.hidden=true;clearFields();
}
window.addEventListener('pagehide',()=>{clearFields();controller?.dispose();});
window.addEventListener('pageshow',event=>{if(event.persisted){clearFields();controller?.dispose();}});
