import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
const routes = [
  ['/', 'index.html'],
  ['/privacy/', 'privacy/index.html'],
  ['/terms/', 'terms/index.html'],
  ['/terms-of-use/', 'terms-of-use/index.html'],
  ['/community-guidelines/', 'community-guidelines/index.html'],
  ['/safety/', 'safety/index.html'],
  ['/child-safety-standards/', 'child-safety-standards/index.html'],
  ['/prohibited-jobs/', 'prohibited-jobs/index.html'],
  ['/payment-disputes/', 'payment-disputes/index.html'],
  ['/account-deletion/', 'account-deletion/index.html'],
  ['/support/', 'support/index.html'],
  ['/contact/', 'contact/index.html'],
  ['/accessibility/', 'accessibility/index.html'],
];

const failures = [];
const read = (relative) => readFileSync(resolve(output, relative), 'utf8');

for (const [route, relative] of routes) {
  const html = read(relative);
  for (const [label, pattern] of [
    ['skip link', /class="skip"[^>]*href="#content"/],
    ['local mark', /href="\/mort-mark\.svg"/],
    ['atmosphere canvas', /<canvas[^>]*id="legal-sky"/],
    ['top bar', /class="topbar"/],
    ['responsive navigation', /<aside[^>]*class="side"/],
    ['main content landmark', /<main[^>]*id="content"[^>]*class="content"/],
    ['local atmosphere script', /src="\/assets\/atmosphere\.js"/],
  ]) {
    if (!pattern.test(html)) failures.push(`${route}: missing ${label}`);
  }
  if (/\sonsubmit=|<script[^>]+src="https?:\/\//i.test(html)) {
    failures.push(`${route}: contains inline behavior or a remote executable script`);
  }
  if (!html.includes(`href="${route}" aria-current="page"`)) {
    failures.push(`${route}: navigation does not identify the current page`);
  }
}

for (const asset of ['assets/legal.css', 'assets/atmosphere.js', 'mort-mark.svg']) {
  if (!existsSync(resolve(output, asset))) failures.push(`missing redesigned asset: ${asset}`);
}

if (existsSync(resolve(output, 'assets/legal.css'))) {
  const css = read('assets/legal.css');
  if (/@import|url\(["']?https?:\/\//i.test(css)) failures.push('legal.css loads a remote asset');
  if (!/:focus-visible/.test(css)) failures.push('legal.css has no keyboard focus treatment');
  if (!/@media\s*\(prefers-reduced-motion:\s*reduce\)/.test(css)) {
    failures.push('legal.css does not respect reduced motion');
  }
}

if (existsSync(resolve(output, 'assets/atmosphere.js'))) {
  const atmosphere = read('assets/atmosphere.js');
  if (!/prefers-reduced-motion:\s*reduce/.test(atmosphere) || !/if\s*\(!REDUCE\)/.test(atmosphere)) {
    failures.push('atmosphere animation is not disabled for reduced motion');
  }
}

const deletion = read('account-deletion/index.html');
for (const required of [
  'id="deletion-link-form"',
  'id="confirmed-panel"',
  'id="submit-deletion"',
  'src="/assets/supabase.js"',
  'src="/assets/public-config.js"',
  'src="/assets/account-deletion.js"',
]) {
  if (!deletion.includes(required)) failures.push(`/account-deletion/: missing ${required}`);
}

if (failures.length) {
  throw new Error(`Legal redesign QA failed: ${failures.join('; ')}`);
}

process.stdout.write(`Legal redesign QA PASS: ${routes.length} routes use the production shell and deletion flow.\n`);
