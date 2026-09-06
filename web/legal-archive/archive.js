import * as THREE from 'three';
import {createInput,beginInput,moveInput,releaseInput,decayInput} from './input.mjs';

// An original rain court: monumental glass leaves above a rippling silver basin.
// All visual data is procedural. Contracts and navigation remain native HTML.
const canvas = document.querySelector('#archive-canvas');
const toggle = document.querySelector('#motion-toggle');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
const progress = document.querySelector('#reading-progress');
let manualPause = false;
try { manualPause = localStorage.getItem('mort-archive-paused') === 'true'; } catch {}
let paused = reduced.matches || manualPause;
let renderStill = () => {};
let syncAnimation = () => {};
function updateControl() {
  toggle.textContent = paused ? 'Resume atmosphere' : 'Pause atmosphere';
  toggle.setAttribute('aria-pressed', String(paused));
  toggle.disabled = reduced.matches;
  if(reduced.matches)toggle.textContent='Reduced motion enabled';
}
toggle.addEventListener('click', () => { manualPause = !paused; try { localStorage.setItem('mort-archive-paused',String(manualPause)); } catch {} paused = reduced.matches || manualPause; updateControl(); renderStill(); syncAnimation(); });
reduced.addEventListener('change', () => { paused = reduced.matches || manualPause; updateControl(); renderStill(); syncAnimation(); });
updateControl();
let scroll = 0;
function updateScroll() {
  scroll = window.scrollY / Math.max(1, document.documentElement.scrollHeight - innerHeight);
  progress.value = scroll;
}
addEventListener('scroll', updateScroll, {passive:true});
updateScroll();
const headings = [...document.querySelectorAll('.document h2[id]')];
if (headings.length) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) if (entry.isIntersecting) {
      document.querySelectorAll('.contents a').forEach(link => {
        if (link.hash === `#${entry.target.id}`) link.setAttribute('aria-current','location');
        else link.removeAttribute('aria-current');
      });
    }
  }, {rootMargin:'-5% 0px -65% 0px'});
  headings.forEach(heading => observer.observe(heading));
}

try {
  let mobile = innerWidth < 760;
  const renderer = new THREE.WebGLRenderer({canvas,antialias:!mobile,alpha:true,powerPreference:'low-power'});
  renderer.setPixelRatio(Math.min(devicePixelRatio, mobile ? 1.25 : 1.6));
  renderer.setSize(innerWidth,innerHeight);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.12;
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x1b2a34, .018);
  const camera = new THREE.PerspectiveCamera(mobile ? 55 : 46,innerWidth/innerHeight,.1,130);
  const target = new THREE.Vector3(mobile ? 1.8 : 0,4,-9);
  const ambient = new THREE.HemisphereLight(0xd9edff,0x273743,2.2);
  scene.add(ambient);
  const light = new THREE.DirectionalLight(0xe8f8ff,4);
  light.position.set(-10,18,-12); scene.add(light);
  const rim = new THREE.PointLight(0xb0e5ff,100,45,1.8);
  rim.position.set(7,8,-8); scene.add(rim);
  const architecture = new THREE.Group(); scene.add(architecture);
  const metal = new THREE.MeshStandardMaterial({color:0x17212a,metalness:.75,roughness:.29});
  const glass = new THREE.MeshPhysicalMaterial({color:0x8aa9b8,metalness:.25,roughness:.13,transparent:true,opacity:.34,side:THREE.DoubleSide,depthWrite:false});
  const edgeMat = new THREE.LineBasicMaterial({color:0xb5dce9,transparent:true,opacity:.54});
  const pillarGeo = new THREE.BoxGeometry(.26,12,.4);
  const paneGeo = new THREE.BoxGeometry(3.6,11,.08);
  const beamGeo = new THREE.BoxGeometry(4,.2,.5);
  const paneEdges = new THREE.EdgesGeometry(paneGeo);
  // Receding frames, with a separate vertical cadence for narrow screens.
  for(let i=0;i<8;i++) {
    const group = new THREE.Group();
    group.position.set(5 + i*.17,6,-i*4.1);
    group.rotation.y = -.17;
    for(const x of [-2,2]) {const p = new THREE.Mesh(pillarGeo,metal);p.position.x=x;group.add(p);}
    const top = new THREE.Mesh(beamGeo,metal);top.position.y=6;group.add(top);
    const pane = new THREE.Mesh(paneGeo,glass);pane.position.y=.2;group.add(pane);
    const edges = new THREE.LineSegments(paneEdges,edgeMat);edges.position.copy(pane.position);group.add(edges);
    architecture.add(group);
    // Dim mirrored architecture continues below the waterline.
    const reflection = group.clone();reflection.position.y=-6.3;reflection.scale.y=-.86;
    reflection.children.forEach(child => {child.material=child.material.clone();child.material.transparent=true;child.material.opacity=.13;});
    architecture.add(reflection);
    group.visible=reflection.visible=!mobile||i<5;
  }
  const distantMat = new THREE.MeshStandardMaterial({color:0x0b151f,roughness:.8});
  for(let i=0;i<11;i++) {const height=7+(i%4)*3;const p=new THREE.Mesh(new THREE.BoxGeometry(1.3,height,2),distantMat);p.position.set(-23+i*5,height/2,-42-(i%3)*5);scene.add(p);}
  const uniforms = {time:{value:0},pulse:{value:0},pointer:{value:new THREE.Vector2(.5,.5)}};
  const water = new THREE.Mesh(new THREE.PlaneGeometry(180,180,1,1),new THREE.ShaderMaterial({
    uniforms,transparent:true,vertexShader:`varying vec2 vUv; void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
    fragmentShader:`varying vec2 vUv;uniform float time;uniform float pulse;uniform vec2 pointer;
      void main(){vec2 p=(vUv-.5)*180.;float waves=sin(p.x*2.+sin(p.y*.6+time*.55)*1.3+time*.8)*sin(p.y*3.-time*1.2);float ripple=sin(length(p-vec2(5.,8.))*5.-time*3.)*.5+.5;float beam=exp(-abs(p.x-5.+sin(p.y*.4+time*.22)*.5)*.65);float silver=pow(max(0.,waves),8.)*beam;float wake=sin(length(p-vec2((pointer.x-.5)*16.,(pointer.y-.5)*16.))*4.-time*5.)*pulse*.08;vec3 color=vec3(.035,.066,.088)+vec3(.35,.49,.57)*silver+vec3(.07,.10,.12)*ripple*beam+vec3(wake);gl_FragColor=vec4(color,.93);}`
  }));
  water.rotation.x=-Math.PI/2;water.position.y=-.1;scene.add(water);
  const count=1150;
  const rainGeo=new THREE.BufferGeometry();
  const positions=new Float32Array(count*6);
  const seeds=new Float32Array(count*3);
  for(let i=0;i<count;i++){seeds[i*3]=(Math.random()-.5)*52;seeds[i*3+1]=Math.random()*30;seeds[i*3+2]=5-Math.random()*48;}
  rainGeo.setAttribute('position',new THREE.BufferAttribute(positions,3));
  const rain=new THREE.LineSegments(rainGeo,new THREE.LineBasicMaterial({color:0xccedfa,transparent:true,opacity:mobile?.2:.3,depthWrite:false}));scene.add(rain);
  rainGeo.setDrawRange(0,(mobile?450:count)*2);
  const mistGeo=new THREE.BufferGeometry();const mistPositions=new Float32Array(70*3);
  for(let i=0;i<70;i++){mistPositions[i*3]=(Math.random()-.5)*50;mistPositions[i*3+1]=Math.random()*7;mistPositions[i*3+2]=-Math.random()*40;}
  mistGeo.setAttribute('position',new THREE.BufferAttribute(mistPositions,3));
  const mist=new THREE.Points(mistGeo,new THREE.PointsMaterial({color:0xc4e3ee,size:.045,transparent:true,opacity:.4,depthWrite:false}));scene.add(mist);
  const input=createInput();let capture=null,pendingTouch=false,originX=0,originY=0;
  const excluded='a,button,input,textarea,select,label,form,nav,p,h1,h2,h3,li,[contenteditable],[role="button"]';
  const cancel=(clear=true)=>{const id=input.id;releaseInput(input,clear);if(id!==null&&capture?.hasPointerCapture(id))capture.releasePointerCapture(id);capture=null;pendingTouch=false;};
  addEventListener('pointerdown',e=>{
    if(paused||document.hidden||!(e.target instanceof Element)||e.target.closest(excluded))return;
    const zone=e.target.closest('[data-scene-drag]');if(e.pointerType==='touch'&&!zone)return;
    if(!beginInput(input,e.pointerId,e.button,e.isPrimary,e.clientX,e.clientY,e.timeStamp))return;
    capture=zone||e.target;originX=e.clientX;originY=e.clientY;pendingTouch=e.pointerType==='touch';
    if(!pendingTouch)capture.setPointerCapture(e.pointerId);
  });
  addEventListener('pointermove',e=>{
    if(e.pointerId!==input.id)return;if(!(e.buttons&1)){cancel(false);return;}
    if(pendingTouch){const dx=Math.abs(e.clientX-originX),dy=Math.abs(e.clientY-originY);if(dy>8&&dy>dx){cancel();return;}if(dx<10||dx<dy*1.3)return;pendingTouch=false;capture?.setPointerCapture(e.pointerId);}
    moveInput(input,e.pointerId,e.clientX,e.clientY,e.timeStamp);
    uniforms.pointer.value.set(e.clientX/innerWidth,e.clientY/innerHeight);
  },{passive:true});
  addEventListener('pointerup',e=>{if(e.pointerId===input.id)cancel(false);});
  addEventListener('pointercancel',()=>cancel());addEventListener('blur',()=>cancel());
  addEventListener('lostpointercapture',e=>{if(e.pointerId===input.id)cancel();});
  let elapsed=0,lastRender=0,slowFrames=0,qualityReduced=false,frame=0,failed=false;
  function draw() {
    const t=elapsed;
    uniforms.time.value=t;uniforms.pulse.value=input.energy;
    canvas.dataset.energy=input.energy.toFixed(4);
    for(let i=0;i<count;i++) {
      const x=seeds[i*3]+Math.sin(t*.17)*.25;const y=(seeds[i*3+1]-t*9)%30;const py=y<0?y+30:y;const z=seeds[i*3+2];
      positions.set([x,py,z,x-.075,py+.55,z],i*6);
    }
    rainGeo.attributes.position.needsUpdate=true;
    camera.position.set((mobile?11:15)+input.vx*.08,mobile?5.5:6.1, mobile?17:22);
    camera.position.y+=Math.sin(t*.18)*.12-scroll*.8;
    camera.lookAt(target.x,target.y+scroll*.8,target.z);
    rim.intensity=95+Math.sin(t*.7)*25;
    mist.position.x=Math.sin(t*.15)*1.7;mist.position.y=Math.sin(t*.22)*.3;
    renderer.render(scene,camera);
  }
  renderStill=draw;
  function tick(now) {
    frame=0;
    if(document.hidden || paused || failed)return;
    frame=requestAnimationFrame(tick);
    if(lastRender&&now-lastRender<(mobile||qualityReduced?33:20))return;
    const delta=lastRender?Math.min((now-lastRender)/1000,.1):1/60;
    if(now-lastRender>55)slowFrames++;else slowFrames=Math.max(0,slowFrames-1);
    if(slowFrames>70&&!qualityReduced){renderer.setPixelRatio(1);rainGeo.setDrawRange(0,900);qualityReduced=true;}
    lastRender=now;elapsed+=delta;decayInput(input,delta);draw();
  }
  syncAnimation=()=>{if(frame)cancelAnimationFrame(frame);frame=0;lastRender=0;cancel();if(!paused&&!document.hidden&&!failed)frame=requestAnimationFrame(tick);};
  addEventListener('visibilitychange',syncAnimation);
  addEventListener('resize',()=>{
    mobile=innerWidth<760;target.x=mobile?1.8:0;camera.fov=mobile?55:46;
    camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();
    renderer.setPixelRatio(qualityReduced?1:Math.min(devicePixelRatio,mobile?1.25:1.6));renderer.setSize(innerWidth,innerHeight);
    architecture.children.forEach((child,i)=>child.visible=!mobile||Math.floor(i/2)<5);
    rainGeo.setDrawRange(0,(mobile||qualityReduced?450:count)*2);draw();
  },{passive:true});
  canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();failed=true;paused=true;syncAnimation();document.body.classList.remove('has-webgl');canvas.hidden=true;toggle.hidden=true;});
  draw();document.body.classList.add('has-webgl');syncAnimation();
} catch {
  // The composed CSS glass court remains available without WebGL or JavaScript.
  canvas.hidden=true;toggle.hidden=true;
}
