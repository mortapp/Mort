import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validPassword} from './password-policy.mjs';
test('approved password boundary fixtures have the same browser and server verdict',async()=>{
  const {validPassword: serverPolicy}=await import('../../supabase/functions/_shared/auth_email_guard/parser.ts');
  const cases=JSON.parse(readFileSync(new URL('../../flutter_mort/test/fixtures/password-policy.json',import.meta.url),'utf8'));
  for(const entry of cases){assert.equal(validPassword(entry.value),entry.valid,entry.name);assert.equal(serverPolicy(entry.value),entry.valid,entry.name);}
});
