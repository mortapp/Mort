import { smtpDiagnostic } from './smtp-diagnostic.ts';
Deno.test('SMTP diagnostics retain fixed failure categories without sensitive values', () => {
  for (const [code, expected] of [['EAUTH','authentication'],['EENVELOPE','envelope'],['ETIMEDOUT','timeout'],['ECONNREFUSED','connection'],['CERT_HAS_EXPIRED','tls'],['ESOCKET','socket']]) {
    const actual = smtpDiagnostic({code, message:'private fixture address and password', response:'private provider response'});
    if (actual !== expected) throw new Error('Fixed SMTP category mismatch');
  }
  if (smtpDiagnostic({code:'private-value',message:'private-value'}) !== 'unclassified') throw new Error('Unknown details escaped');
});
