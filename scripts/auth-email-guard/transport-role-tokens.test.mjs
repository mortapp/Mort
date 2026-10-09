import assert from 'node:assert/strict';
import {test} from 'node:test';
import * as fixture from './fixture.mjs';
const claims=token=>JSON.parse(Buffer.from(token.split('.')[1],'base64url'));
const secret='a'.repeat(64);
test('transport startup retains still-valid internal role issuance instead of recreating Storage',()=>{
  assert.equal(typeof fixture.fixtureTransportRoleTokens,'function','Transport startup must retain the active internal role generation');
  const result=fixture.fixtureTransportRoleTokens({jwtSecret:secret},{anonIssuedAt:1000,serviceIssuedAt:1001},1200);
  assert.equal(claims(result.anonKey).iat,1000);assert.equal(claims(result.anonKey).exp,4600);
  assert.equal(claims(result.serviceKey).iat,1001);assert.equal(claims(result.serviceKey).exp,4601);
  assert.equal(claims(result.serviceKey).role,'service_role');
  assert.deepEqual(fixture.fixtureTransportRoleTokens({jwtSecret:secret},{anonIssuedAt:1000,serviceIssuedAt:1001},1300),result);
});
test('expired or malformed internal role issuance renews roles with the original one-hour lifetime',()=>{
  assert.equal(typeof fixture.fixtureTransportRoleTokens,'function');
  for(const previous of [undefined,{}, {anonIssuedAt:-1,serviceIssuedAt:1000},{anonIssuedAt:'1000',serviceIssuedAt:1000},{anonIssuedAt:1000,serviceIssuedAt:1000},{anonIssuedAt:99999,serviceIssuedAt:99999}]){
    const result=fixture.fixtureTransportRoleTokens({jwtSecret:secret},previous,5000);
    for(const key of ['anonKey','serviceKey']){assert.equal(claims(result[key]).iat,5000);assert.equal(claims(result[key]).exp,8600);}
  }
});
