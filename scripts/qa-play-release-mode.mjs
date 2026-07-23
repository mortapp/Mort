import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-play-release-mode';
const pubspec = read('flutter_mort/pubspec.yaml');
const gradle = read('flutter_mort/android/app/build.gradle.kts');
const build = read('scripts/build-play-aab.ps1');
const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)$/m);
assert(version, 'Flutter version source is missing or invalid.');
assert(Number(version[2]) > 90, 'Play versionCode must be greater than 90.');
assert(gradle.includes('applicationId = "com.mortapp.mobile"'), 'Package ID mismatch.');
assert(gradle.includes('targetSdk = 36') && gradle.includes('minSdk = 24'), 'SDK levels mismatch.');
assert(gradle.includes('Release signing is required') && !gradle.includes('signingConfigs.getByName("debug")'), 'Release signing does not fail closed.');
for (const flag of ['MORT_RELEASE_STAGE=closed_test','MORT_OPERATIONAL_MODE=closed_pilot','MORT_PUBLIC_MARKETPLACE_ENABLED=false','MORT_IDENTITY_VERIFICATION_ENABLED=false','IAP_ENABLED=false','ADS_ENABLED=false']) {
  assert(build.includes(flag), `Missing release define: ${flag}`);
}
assert(build.includes('read-mobile-version.mjs'), 'Build does not consume the authoritative version source.');
pass(scope, `version ${version[1]}+${version[2]}, package, SDK, fail-closed signing, and closed-test build defines are fixed`);
