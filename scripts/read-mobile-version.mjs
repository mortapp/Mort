import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = readFileSync(resolve(root, 'flutter_mort', 'pubspec.yaml'), 'utf8');
const match = source.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
if (!match) throw new Error('flutter_mort/pubspec.yaml has no valid Flutter version.');

const result = {
  versionName: match[1],
  versionCode: Number(match[2]),
  source: 'flutter_mort/pubspec.yaml',
};

if (process.argv.includes('--json')) {
  process.stdout.write(`${JSON.stringify(result)}\n`);
} else {
  process.stdout.write(`${result.versionName}+${result.versionCode}\n`);
}
