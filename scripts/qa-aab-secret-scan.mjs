import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createHash, randomBytes } from 'node:crypto';
import { assert, pass, read, root } from './play-release-qa-helpers.mjs';

const scope = 'qa-aab-secret-scan';
const version = read('flutter_mort/pubspec.yaml').match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$/m);
assert(version, 'Flutter version could not be read.');
const artifactVersion = `${version[1]}-${version[2]}`;
const bundle = process.argv[2]
  ? resolve(process.argv[2])
  : resolve(root, `build/play/mort-closed-test-${artifactVersion}.aab`);
const apk = process.argv[3]
  ? resolve(process.argv[3])
  : resolve(root, `build/play/mort-closed-test-${artifactVersion}.apk`);
if (!process.argv.includes('--self-test')) {
  assert(existsSync(bundle), 'Closed-test AAB does not exist.');
  assert(existsSync(apk), 'Closed-test QA APK does not exist.');
}

const secretNames = [
  'SUPABASE_SERVICE_ROLE_KEY','SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD',
  'MORT_UPLOAD_STORE_PASSWORD','MORT_UPLOAD_KEY_PASSWORD','REVENUECAT_V1_SECRET_API_KEY',
  'REVENUECAT_V2_SECRET_API_KEY',
  'REVENUECAT_WEBHOOK_AUTH_HEADER','REVENUECAT_PLAY_WEBHOOK_AUTH_HEADER',
  'REVENUECAT_TEST_WEBHOOK_AUTH_HEADER','SEND_PUSH_INVOKE_SECRET',
  'STRIPE_TEST_SECRET_KEY','STRIPE_LIVE_SECRET_KEY',
  'STRIPE_TEST_WEBHOOK_SECRET','STRIPE_LIVE_WEBHOOK_SECRET',
  'STRIPE_TEST_CONNECT_WEBHOOK_SECRET','STRIPE_LIVE_CONNECT_WEBHOOK_SECRET',
  'MORT_STRIPE_OPERATIONS_SECRET','IDENTITY_VERIFICATION_WEBHOOK_SECRET',
  'OPENAI_API_KEY','ANTHROPIC_API_KEY','GEMINI_API_KEY',
  'PLAY_REVIEW_ADULT_PASSWORD','PLAY_REVIEW_TEEN_PASSWORD',
];
const secrets = secretNames.map((name) => process.env[name]).filter((value) => value && value.length >= 8).map((value) => Buffer.from(value));
const forbiddenCredentialMarkers = [Buffer.from('GOCSPX-')];
const serverSecretPattern = /\bsk_[A-Za-z0-9]{20,}\b/g;
const flutterEngineMarkerSha256 = 'c1c7ed5ead0b539526a4659a401eef75663873f436a902cb70303d229676e373';
const flutterEnginePath = /^(?:BUNDLE-METADATA\/com\.android\.tools\.build\.debugsymbols\/(?:arm64-v8a|armeabi-v7a|x86_64)\/libflutter\.so\.sym|(?:base\/)?lib\/(?:arm64-v8a|armeabi-v7a|x86_64)\/libflutter\.so)$/;

function hasForbiddenServerSecret(entry, data) {
  for (const match of data.toString('latin1').matchAll(serverSecretPattern)) {
    const digest = createHash('sha256').update(match[0]).digest('hex');
    if (!flutterEnginePath.test(entry) || digest !== flutterEngineMarkerSha256) {
      return true;
    }
  }
  return false;
}

if (process.argv.includes('--self-test')) {
  assert(hasForbiddenServerSecret('base/lib/arm64-v8a/libapp.so', Buffer.from(`sk_${'R'.repeat(28)}`)));
  assert(!hasForbiddenServerSecret('base/lib/arm64-v8a/libapp.so', Buffer.from('goog_public_sdk_identifier')));
  pass(scope, 'generic server-secret marker detection self-test');
  process.exit(0);
}

function files(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? files(path) : [path];
  });
}

let scannedEntries = 0;
for (const artifact of [
  { label: 'AAB', path: bundle },
  { label: 'APK', path: apk },
]) {
  const work = join(
    tmpdir(),
    `mort-${artifact.label.toLowerCase()}-scan-${randomBytes(6).toString('hex')}`,
  );
  mkdirSync(work, { recursive: true });
  try {
    execFileSync('jar', ['xf', artifact.path], {
      cwd: work,
      stdio: 'ignore',
    });
    const extracted = files(work);
    scannedEntries += extracted.length;
    for (const path of extracted) {
      const data = readFileSync(path);
      const entry = path.slice(work.length + 1).replaceAll('\\', '/');
      assert(
        !hasForbiddenServerSecret(entry, data),
        `Server-only secret marker detected in ${artifact.label} entry ${entry}.`,
      );
      assert(
        !/test_[A-Za-z0-9]{20,}/.test(data.toString('latin1')),
        `RevenueCat Test Store key detected in ${artifact.label} entry ${path.slice(work.length + 1)}.`,
      );
      for (const secret of secrets) {
        assert(
          data.indexOf(secret) === -1,
          `Sensitive environment value detected in ${artifact.label} entry ${path.slice(work.length + 1)}.`,
        );
      }
      for (const marker of forbiddenCredentialMarkers) {
        assert(
          data.indexOf(marker) === -1,
          `Google OAuth client-secret marker detected in ${artifact.label} entry ${path.slice(work.length + 1)}.`,
        );
      }
    }
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

pass(
  scope,
  `scanned ${scannedEntries} extracted AAB/APK entries against ${secrets.length} available sensitive values and Google client-secret markers`,
);
