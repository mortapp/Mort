import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const assetRoot = join(root, 'build', 'play', 'store-assets');
const reportPath = join(root, 'build', 'play', 'reports', 'store-asset-validation.txt');

function fail(message) {
  throw new Error(`[validate-final-play-assets] ${message}`);
}

function identify(file) {
  const output = execFileSync(
    'magick',
    ['identify', '-format', '%w|%h|%m|%[channels]', file],
    { encoding: 'utf8' },
  ).trim();
  const [width, height, format, channels] = output.split('|');
  return { width: Number(width), height: Number(height), format, channels };
}

function validateImage(file, expectedWidth, expectedHeight, maxBytes) {
  if (!existsSync(file)) fail(`missing image: ${file}`);
  const info = identify(file);
  if (info.width !== expectedWidth || info.height !== expectedHeight) {
    fail(`${file} is ${info.width}x${info.height}; expected ${expectedWidth}x${expectedHeight}`);
  }
  if (info.format !== 'PNG') fail(`${file} is not PNG`);
  const bytes = statSync(file).size;
  if (bytes > maxBytes) fail(`${file} exceeds ${maxBytes} bytes`);
  return { file, bytes, ...info };
}

if (!existsSync(assetRoot)) fail('asset output is missing; run capture-final-play-assets.ps1');
const inventory = JSON.parse(readFileSync(join(assetRoot, 'asset-inventory.json'), 'utf8').replace(/^\uFEFF/, ''));
if (inventory.sourceBuild !== 'MORT Android release 0.9.1+91') fail('inventory build version is incorrect');
if (inventory.physicalDeviceClaim !== false) fail('physical-device claim must remain false');
if (inventory.tabletAssetsIncluded !== false) fail('tablet assets must remain excluded until tablet testing passes');
if (!Array.isArray(inventory.screenshots) || inventory.screenshots.length !== 8) fail('exactly eight screenshot narratives are required');

const results = [];
results.push(validateImage(join(assetRoot, 'app-icon', 'mort-play-icon-512.png'), 512, 512, 1024 * 1024));
results.push(validateImage(join(assetRoot, 'feature-graphic', 'mort-feature-graphic-1024x500.png'), 1024, 500, 15 * 1024 * 1024));

for (const group of [
  { name: 'phone-large', width: 1080, height: 1920 },
  { name: 'phone-small', width: 720, height: 1280 },
]) {
  const directory = join(assetRoot, group.name);
  const files = readdirSync(directory).filter((name) => name.endsWith('.png')).sort();
  if (files.length !== 8) fail(`${group.name} must contain exactly eight PNG screenshots`);
  for (const name of files) {
    const result = validateImage(join(directory, name), group.width, group.height, 8 * 1024 * 1024);
    const ratio = Math.max(result.width, result.height) / Math.min(result.width, result.height);
    if (Math.min(result.width, result.height) < 320 || Math.max(result.width, result.height) > 3840 || ratio > 2) {
      fail(`${name} violates Play screenshot dimension constraints`);
    }
    if (/alpha/i.test(result.channels)) fail(`${name} retains an alpha channel`);
    results.push(result);
  }
}

const captions = readFileSync(join(assetRoot, 'screenshot-captions.txt'), 'utf8');
for (const forbidden of ['sandbox test account', 'sha-256:', 'goexception', 'application not responding']) {
  if (captions.toLowerCase().includes(forbidden)) fail(`captions contain forbidden text: ${forbidden}`);
}

const lines = [
  'PASS: Google Play asset package validation',
  'Build: MORT Android release 0.9.1+91',
  'App icon: 512x512 PNG, <= 1 MB',
  'Feature graphic: 1024x500 PNG',
  'Large phone screenshots: 8 at 1080x1920',
  'Small phone screenshots: 8 at 720x1280',
  'Tablet screenshots: excluded; tablet physical testing is not complete',
  'Physical-device claim: false',
  `Validated files: ${results.length}`,
];
writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
process.stdout.write(`${lines.join('\n')}\n`);

