import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const generatorPath = resolve(root, 'scripts', 'build-public-legal-site.mjs');
const output = resolve(root, 'web', 'public');
const generator = readFileSync(generatorPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(`[qa-public-legal-site] ${message}`);
}

function includesAll(text, needles, label) {
  for (const needle of needles) {
    assert(text.includes(needle), `${label} missing required text: ${needle}`);
  }
}

const requiredRoutes = [
  '/',
  '/privacy/',
  '/terms/',
  '/dispute-resolution/',
  '/us-state-law-addendum/',
  '/guardian-terms/',
  '/verification-privacy-notice/',
  '/paid-services/',
  '/terms-of-use/',
  '/community-guidelines/',
  '/safety/',
  '/child-safety-standards/',
  '/prohibited-jobs/',
  '/payment-disputes/',
  '/account-deletion/',
  '/support/',
  '/contact/',
  '/accessibility/',
];

assert(!generator.includes('Draft — pending qualified legal review'), 'public generator still exposes Draft status');
for (const route of requiredRoutes) {
  assert(generator.includes(`'${route}'`) || generator.includes(`\"${route}\"`), `generator route missing: ${route}`);
}

includesAll(generator, [
  '2026-10-10-nationwide-us-legal-v2',
  'legalApprovalClaimed',
  'externalLegalReviewPending',
  'conspicuous notice',
  'Create Account',
  'Confirm Purchase',
  'No sale of Teen User personal information for money',
  'No cross-context behavioral advertising to Teen Users',
  '60 days',
  'individual arbitration',
  'class-action waiver',
  'jury',
  'small-claims',
  'government agency',
  'sexual assault',
  '30 days',
  'ARBITRATION OPT OUT',
  'public injunctive relief',
  'greater of $100',
], 'generator');

if (process.env.MORT_LEGAL_QA_SOURCE_ONLY !== '1') {
  execFileSync(process.execPath, [generatorPath], {
    cwd: root,
    env: process.env,
    stdio: 'inherit',
  });

  for (const route of requiredRoutes) {
    const file = route === '/' ? resolve(output, 'index.html') : resolve(output, route.slice(1), 'index.html');
    assert(existsSync(file), `built route missing: ${route}`);
  }

  const combined = requiredRoutes
    .map((route) => route === '/' ? resolve(output, 'index.html') : resolve(output, route.slice(1), 'index.html'))
    .map((file) => readFileSync(file, 'utf8'))
    .join('\n');

  assert(!combined.includes('Draft — pending qualified legal review'), 'built output still exposes Draft status');
  includesAll(combined, [
    'Effective',
    'United States',
    '/us-state-law-addendum/',
    '/guardian-terms/',
    '/verification-privacy-notice/',
    '/paid-services/',
    'ARBITRATION OPT OUT',
  ], 'built legal package');

  const releaseStatus = JSON.parse(readFileSync(resolve(output, 'release-status.json'), 'utf8'));
  assert(releaseStatus.revision === '2026-10-10-nationwide-us-legal-v2', 'release revision mismatch');
  assert(releaseStatus.legalApprovalClaimed === false, 'must not claim lawyer approval');
  assert(releaseStatus.externalLegalReviewPending === true, 'external legal review metadata must remain truthful');

  const deletion = readFileSync(resolve(output, 'account-deletion', 'index.html'), 'utf8');
  for (const asset of ['/assets/supabase.js', '/assets/public-config.js', '/assets/account-deletion.js']) {
    assert(deletion.includes(asset), `account deletion lost required script: ${asset}`);
  }
}

console.log('[qa-public-legal-site] PASS');
