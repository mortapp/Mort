import { assert, pass, read } from './play-release-qa-helpers.mjs';

const releaseBuilder = read('scripts/android-release-profile-common.ps1');
const bundleVerifier = read('scripts/verify-play-aab.ps1');
const keyGenerator = read('scripts/generate-play-upload-key.ps1');

for (const [label, source] of [
  ['release builder', releaseBuilder],
  ['AAB verifier', bundleVerifier],
]) {
  assert(
    !/-storepass\s+\$signing\.StorePassword|\$signing\.StorePassword\s+-storepass/i.test(source),
    `${label} must not pass the keystore password as a process argument.`,
  );
  assert(
    source.includes('-storepass:env MORT_UPLOAD_STORE_PASSWORD'),
    `${label} must read the keystore password from the process environment.`,
  );
}

assert(
  !/-storepass\s+\$storePassword|-keypass\s+\$keyPassword/i.test(keyGenerator),
  'The upload-key generator must not pass passwords as process arguments.',
);
assert(
  keyGenerator.includes('-storepass:env MORT_UPLOAD_STORE_PASSWORD') &&
    keyGenerator.includes('-keypass:env MORT_UPLOAD_KEY_PASSWORD'),
  'The upload-key generator must read passwords from the process environment.',
);

pass('qa-release-signing-credential-process', 'release signing credentials stay out of process arguments');
