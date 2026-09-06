import test from 'node:test';
import assert from 'node:assert/strict';
import { renderArchive } from './shell.mjs';
import {createInput,beginInput,moveInput,releaseInput,decayInput} from './input.mjs';
test('hover, right button and secondary pointers cannot activate the scene',()=>{
  const s=createInput();moveInput(s,1,100,100,10);assert.equal(s.energy,0);
  assert.equal(beginInput(s,1,2,true,0,0,0),false);assert.equal(beginInput(s,2,0,false,0,0,0),false);
});
test('primary drag produces bounded velocity, release decays and cancel clears',()=>{
  const s=createInput();assert.equal(beginInput(s,1,0,true,0,0,0),true);
  moveInput(s,2,1000,1000,16);assert.equal(s.energy,0);
  moveInput(s,1,1000,1000,16);assert.equal(s.energy,1);assert.equal(s.vx,3);
  releaseInput(s);decayInput(s,.1);assert.ok(s.energy>0&&s.energy<1);
  releaseInput(s,true);assert.equal(s.energy,0);assert.equal(s.vx,0);
});
test('archive retains semantic text, anchors and deletion scripts', () => {
  const html = renderArchive({title:'Privacy',description:'Original description',body:'<h2>Keep this heading</h2><p>Original legal text.</p>',scripts:'<script src="/assets/account-deletion.js"></script>',routes:[['/','Overview'],['/privacy/','Privacy']],publisher:'MORT',supportEmail:'support@example.com',effectiveDate:'2026-08-29',websiteUrl:'https://mortapp.org',blocker:''});
  assert.match(html, /Original legal text\./);
  assert.match(html, /id="keep-this-heading"/);
  assert.match(html, /aria-hidden="true"/);
  assert.match(html, /Pause atmosphere/);
  assert.match(html, /account-deletion.js/);
  assert.match(html, /class="skip"/);
  assert.doesNotMatch(html, /hubgrid|hubcard/);
});
