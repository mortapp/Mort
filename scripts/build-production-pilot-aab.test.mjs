import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const builder = readFileSync(
  path.join(root, 'scripts', 'build-production-pilot-aab.ps1'),
  'utf8',
);

test('production pilot preflight checks the crash and push providers wired by the app', () => {
  const crashProvider = path.join(
    root,
    'flutter_mort',
    'lib',
    'core',
    'observability',
    'sentry_crash_provider.dart',
  );
  const pushProvider = path.join(
    root,
    'flutter_mort',
    'lib',
    'services',
    'push',
    'remote_push_provider.dart',
  );

  assert.ok(existsSync(crashProvider), 'real Sentry provider exists');
  assert.ok(existsSync(pushProvider), 'real Firebase push provider exists');
  assert.match(builder, /sentry_crash_provider\.dart/);
  assert.match(builder, /remote_push_provider\.dart/);
  assert.doesNotMatch(builder, /production_crash_provider\.dart/);
  assert.doesNotMatch(builder, /remote_push_service\.dart/);
});
