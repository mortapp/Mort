import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const service = readFileSync(
  join(repoRoot, 'flutter_mort', 'lib', 'data', 'services', 'supabase_service.dart'),
  'utf8',
);
const bootstrap = readFileSync(
  join(repoRoot, 'flutter_mort', 'lib', 'main.dart'),
  'utf8',
);
const providers = readFileSync(
  join(
    repoRoot,
    'flutter_mort',
    'lib',
    'data',
    'repositories',
    'providers.dart',
  ),
  'utf8',
);

const checks = [
  ['Supabase initializes once', service.includes('if (!isConfigured || _initialized) return;')],
  ['Startup waits for initialization', bootstrap.includes('FutureBuilder<Object?>')],
  ['Startup exposes retry', bootstrap.includes('Retry startup')],
  ['Auth state stream is observed', providers.includes('authStateProvider')],
  ['Profile provider watches auth changes', providers.includes('ref.watch(authStateProvider)')],
];

let failed = false;
for (const [label, passed] of checks) {
  console.log(`${passed ? 'PASS' : 'FAIL'}: ${label}`);
  failed ||= !passed;
}

console.log(
  'MANUAL: Browser refresh and real iPhone relaunch session restoration still require signed-in runtime testing.',
);
process.exit(failed ? 1 : 0);
