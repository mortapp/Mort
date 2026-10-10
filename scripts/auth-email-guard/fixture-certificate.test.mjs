import {test} from 'node:test';import assert from 'node:assert/strict';
const module=await import('./fixture-certificate.mjs').catch(()=>({}));
const certificate={validFrom:'2026-10-08T00:00:00Z',validTo:'2026-10-10T00:00:00Z'};
test('fixtureCertificateValidityRejectsExpiryAndAcceptsInsideLifetime',()=>{
 assert.equal(typeof module.certificateCurrent,'function','Fixture certificate validity check missing');
 assert.equal(module.certificateCurrent(certificate,Date.parse(certificate.validTo)),false);
 assert.equal(module.certificateCurrent(certificate,Date.parse(certificate.validFrom)+1000),true);
 assert.equal(module.certificateCurrent(certificate,Date.parse(certificate.validFrom)-1),false);
 assert.equal(module.certificateCurrent({validFrom:'invalid',validTo:'invalid'},Date.now()),false);
});
