import { cpSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
await import('./build-public-legal-site.mjs');

const source = resolve(root, 'web', 'public');
const output = resolve(root, '.vercel', 'output');
const staticDir = resolve(output, 'static');
rmSync(output, { recursive: true, force: true });
mkdirSync(staticDir, { recursive: true });
cpSync(source, staticDir, { recursive: true });

const headers = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=()',
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
  'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self' https://rakjydmgwwgtdislanbt.supabase.co wss://rakjydmgwwgtdislanbt.supabase.co; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
};
writeFileSync(resolve(output, 'config.json'), `${JSON.stringify({
  version: 3,
  routes: [
    { src: '/(.*)', headers },
    { handle: 'filesystem' },
  ],
}, null, 2)}\n`);
console.log('[build-public-legal-vercel] emitted .vercel/output with security headers');
