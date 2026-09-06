export const createInput = () => ({id:null,x:0,y:0,time:0,vx:0,vy:0,energy:0});
export function beginInput(state,id,button,primary,x,y,time){
  if(button!==0||!primary||state.id!==null)return false;
  Object.assign(state,{id,x,y,time,vx:0,vy:0});return true;
}
export function moveInput(state,id,x,y,time){
  if(id!==state.id)return;
  const dt=Math.max(8,time-state.time);
  state.vx=Math.max(-3,Math.min(3,(x-state.x)/dt));state.vy=Math.max(-3,Math.min(3,(y-state.y)/dt));
  state.energy=Math.min(1,Math.hypot(state.vx,state.vy)*.4);
  Object.assign(state,{x,y,time});
}
export function releaseInput(state,cancel=false){state.id=null;if(cancel){state.energy=0;state.vx=0;state.vy=0;}}
export function decayInput(state,dt){state.energy*=Math.exp(-3*Math.min(dt,.1));state.vx*=Math.exp(-3*Math.min(dt,.1));state.vy*=Math.exp(-3*Math.min(dt,.1));}
