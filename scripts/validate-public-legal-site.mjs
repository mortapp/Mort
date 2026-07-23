import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const output = resolve(root, 'web', 'public');
const expectedRoutes = [
  '/', '/privacy/', '/terms/', '/terms-of-use/', '/community-guidelines/',
  '/safety/', '/child-safety-standards/', '/prohibited-jobs/',
  '/payment-disputes/', '/account-deletion/', '/support/', '/contact/',
  '/accessibility/',
];
const failures = [];
const checked = [];

function routeFile(route) {
  if (route === '/') return resolve(output, 'index.html');
  const relative = route.slice(1);
  if (/\.[a-z0-9]+$/i.test(relative)) return resolve(output, relative);
  return resolve(output, relative, 'index.html');
}

for (const route of expectedRoutes) {
  const file = routeFile(route);
  if (!existsSync(file)) {
    failures.push(`${route}: missing index.html`);
    continue;
  }
  const html = readFileSync(file, 'utf8');
  for (const [name, pattern] of [
    ['doctype', /<!doctype html>/i],
    ['viewport', /name="viewport"/i],
    ['MORT brand', />MORT(?:\s|<)/],
    ['skip link', /class="skip"/],
    ['support route', /href="\/support\/"/],
  ]) if (!pattern.test(html)) failures.push(`${route}: missing ${name}`);
  if (/lorem ipsum|\[[^\]]*required|service_role|SUPABASE_SERVICE_ROLE_KEY/i.test(html)) {
    failures.push(`${route}: forbidden placeholder or secret marker`);
  }
  for (const match of html.matchAll(/href="(\/[^"?#]*\/?)"/g)) {
    const linked = match[1];
    if (!existsSync(routeFile(linked))) failures.push(`${route}: broken internal link ${linked}`);
  }
  checked.push(route);
}

const statusPath = resolve(output, 'release-status.json');
if (!existsSync(statusPath)) failures.push('release-status.json is missing');
const status = existsSync(statusPath)
  ? JSON.parse(readFileSync(statusPath, 'utf8'))
  : { deploymentReady: false, missingConfiguration: ['unknown'] };
const publicConfigPath = resolve(output, 'assets', 'public-config.js');
if (!existsSync(publicConfigPath)) failures.push('public-config.js is missing');
if (existsSync(publicConfigPath) && /service_role|SUPABASE_SERVICE_ROLE_KEY/i.test(readFileSync(publicConfigPath, 'utf8'))) {
  failures.push('public-config.js contains a privileged-key marker');
}

const deletionScriptPath = resolve(output, 'assets', 'account-deletion.js');
if (!existsSync(deletionScriptPath)) {
  failures.push('account-deletion.js is missing');
} else {
  const deletionScript = readFileSync(deletionScriptPath, 'utf8');
  if (!deletionScript.includes('shouldCreateUser: false')) failures.push('account deletion could create an account');
  if (!/finally\s*\{[\s\S]*result\.textContent\s*=\s*['"][^'"]*This page never confirms whether an account exists\./.test(deletionScript)) {
    failures.push('account deletion does not use one generic finally response');
  }
  if (/error\.message|console\.(log|error)|user\.email/.test(deletionScript)) failures.push('account deletion exposes backend/account detail');
}

const childSafetyPath = routeFile('/child-safety-standards/');
if (existsSync(childSafetyPath)) {
  const standards = readFileSync(childSafetyPath, 'utf8').toLowerCase();
  for (const term of ['csam', 'csae', 'grooming', 'sexual solicitation', 'sextortion', 'trafficking', 'report', 'block', 'child-safety contact']) {
    if (!standards.includes(term)) failures.push(`/child-safety-standards/: missing ${term}`);
  }
}

let httpsValidation = { requested: false, passed: false, results: [] };
const baseUrl = process.env.MORT_VALIDATE_PUBLIC_BASE_URL?.replace(/\/$/, '');
if (baseUrl) {
  if (!baseUrl.startsWith('https://')) failures.push('Hosted validation URL must use HTTPS');
  httpsValidation.requested = true;
  for (const route of expectedRoutes) {
    const response = await fetch(`${baseUrl}${route}`, { redirect: 'follow' });
    httpsValidation.results.push({ route, status: response.status });
    if (response.status !== 200) failures.push(`${route}: hosted HTTP ${response.status}`);
  }
  httpsValidation.passed = httpsValidation.results.every((item) => item.status === 200);
}

const report = {
  generatedAt: new Date().toISOString(),
  packagePass: failures.length === 0,
  deploymentReady: status.deploymentReady === true && failures.length === 0,
  checkedRoutes: checked,
  missingConfiguration: status.missingConfiguration ?? [],
  httpsValidation,
  failures,
  legalApprovalClaimed: false,
};
const reportPath = resolve(root, 'build', 'play', 'reports', 'legal-site-validation.json');
mkdirSync(dirname(reportPath), { recursive: true });
writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
if (failures.length) throw new Error(`Legal site package validation failed: ${failures.join('; ')}`);
process.stdout.write(`Legal site package PASS: ${checked.length} routes. Deployment ready: ${report.deploymentReady}.\n`);
