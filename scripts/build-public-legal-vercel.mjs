import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
await import('./build-public-legal-site.mjs');

const source = resolve(root, 'web', 'public');
const output = resolve(root, '.vercel', 'output');
const staticDir = resolve(output, 'static');

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = resolve(dir, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

// Public output uses ordinary effective-date status language, not internal review-state labels.
for (const file of walk(source).filter((path) => path.endsWith('.html'))) {
  let html = readFileSync(file, 'utf8').replaceAll('class="draft"', 'class="status"');
  if (file.endsWith('/verification-privacy-notice/index.html')) {
    html = html.replace(
      '<h2>6. No advertising use or sale</h2>',
      '<p><b>Illinois retention schedule:</b> where BIPA applies, covered biometric identifiers and biometric information will be permanently destroyed when the initial purpose for collecting or obtaining them has been satisfied or within 3 years of the individual\'s last interaction with MORT, whichever occurs first, except to the extent a valid warrant or subpoena issued by a court of competent jurisdiction lawfully requires otherwise.</p><h2>6. No advertising use or sale</h2>',
    );
  }
  if (file.endsWith('/us-state-law-addendum/index.html')) {
    html = html.replace(
      '<h2>8. Texas biometric information</h2>',
      '<p>For covered Illinois biometric data, MORT\'s public destruction schedule is the earlier of satisfaction of the collection purpose or 3 years after the individual\'s last interaction with MORT, subject to legally controlling process.</p><h2>8. Texas biometric information</h2>',
    );
  }
  writeFileSync(file, html);
}
const cssPath = resolve(source, 'assets', 'legal.css');
writeFileSync(cssPath, readFileSync(cssPath, 'utf8').replaceAll('.draft', '.status'));

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
console.log('[build-public-legal-vercel] emitted hardened .vercel/output');
