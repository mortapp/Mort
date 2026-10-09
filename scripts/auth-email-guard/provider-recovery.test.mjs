import assert from 'node:assert/strict';
import {fixtureSql} from './fixture.mjs';
import {run as providerIngress} from './provider-ingress.test.mjs';

// Removing recovery dispatch or treating recovery as signup must fail against
// the actual provider receipt and family, not a mock request or source string.
export async function run(handle){
  await providerIngress(handle,{action:'recovery',recoveryScenario:'replace',beforeCleanup:async({id})=>{
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM mort_fixture.email_ingress WHERE account_id='${id}' AND action='recovery' AND used_at IS NOT NULL`),'1','Actual provider recovery commits and consumes one recovery ingress receipt');
    assert.equal(await fixtureSql(handle,`SELECT count(*) FROM mort_auth_guard.families WHERE account_id='${id}' AND purpose='recovery'`),'1','Recovery ingress creates a recovery family rather than a confirmation family');
    assert.equal(await fixtureSql(handle,`SELECT email_confirmed_at IS NOT NULL FROM auth.users WHERE id='${id}'`),'t','Recovery issuance preserves the existing confirmed account');
  }});
  await providerIngress(handle,{action:'recovery',recoveryScenario:'expired'});
  console.log('PASS actual provider recovery receipt, family, replay defenses and SMTP delivery');
}
