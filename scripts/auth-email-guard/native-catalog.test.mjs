import {test} from 'node:test';import assert from 'node:assert/strict';
let api={};try{api=await import('./native-catalog.mjs');}catch(e){if(e.code!=='ERR_MODULE_NOT_FOUND')throw e;}
const bucket={name:'storage.bucket.synthetic',kind:'private_bucket',reachable:true,public:false,sessionGuardCovered:true};
test('native catalog rejects uncovered bucket while covered private bucket succeeds',()=>{
  assert.equal(typeof api.nativeCatalogCoverage,'function');
  assert.equal(api.nativeCatalogCoverage([bucket]).passed,true);
  assert.equal(api.nativeCatalogCoverage([bucket,{...bucket,name:'new-bucket',sessionGuardCovered:false}]).passed,false);
});
test('native catalog rejects public avatar private-surface claims and empty inventory',()=>{
  assert.equal(typeof api.nativeCatalogCoverage,'function');
  assert.equal(api.nativeCatalogCoverage([{...bucket,public:true}]).passed,false);
  assert.equal(api.nativeCatalogCoverage([]).passed,false);
});
test('published tables and private channels require their own native policy despite a request gate',()=>{
  assert.equal(typeof api.nativeCatalogCoverage,'function');
  const table={name:'fixture.table',kind:'published_table',reachable:true,rlsEnabled:true,sessionGuardCovered:true};
  const channel={name:'fixture.channel',kind:'private_channel',reachable:true,privateOnly:true,sessionGuardCovered:true};
  assert.equal(api.nativeCatalogCoverage([bucket,table,channel]).passed,true);
  assert.equal(api.nativeCatalogCoverage([bucket,{...table,rlsEnabled:false},channel]).passed,false);
  assert.equal(api.nativeCatalogCoverage([bucket,table,{...channel,privateOnly:false}]).passed,false);
});
