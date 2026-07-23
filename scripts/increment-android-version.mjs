import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1]);
}
const requestedName = args.get('--name');
const requestedCode = Number(args.get('--code'));
if (!/^\d+\.\d+\.\d+$/.test(requestedName ?? '') || !Number.isSafeInteger(requestedCode)) {
  throw new Error('Usage: node scripts/increment-android-version.mjs --name 0.9.1 --code 91');
}

const path = resolve(import.meta.dirname, '..', 'flutter_mort', 'pubspec.yaml');
const source = readFileSync(path, 'utf8');
const match = source.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
if (!match) throw new Error('Current Flutter version could not be read.');
const currentCode = Number(match[2]);
if (requestedCode <= currentCode) {
  throw new Error(`Version code must be greater than ${currentCode}.`);
}

writeFileSync(path, source.replace(match[0], `version: ${requestedName}+${requestedCode}`));
process.stdout.write(`Updated Flutter version to ${requestedName}+${requestedCode}.\n`);
