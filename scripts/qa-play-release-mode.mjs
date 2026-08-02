import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-play-release-mode';
const pubspec = read('flutter_mort/pubspec.yaml');
const gradle = read('flutter_mort/android/app/build.gradle.kts');
const build = read('scripts/build-play-aab.ps1');
const profileBuild = read('scripts/build-closed-test-aab.ps1');
const commonBuild = read('scripts/android-release-profile-common.ps1');
const profileMatrix = JSON.parse(read('config/mort-release-profiles.json'));
const reviewerProfile = profileMatrix.profiles.reviewer_demo;
const version = pubspec.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)$/m);
assert(version, 'Flutter version source is missing or invalid.');
assert(Number(version[2]) > 90, 'Play versionCode must be greater than 90.');
assert(gradle.includes('applicationId = "com.mortapp.mobile"'), 'Package ID mismatch.');
assert(gradle.includes('targetSdk = 36') && gradle.includes('minSdk = 24'), 'SDK levels mismatch.');
assert(gradle.includes('Release signing is required') && !gradle.includes('signingConfigs.getByName("debug")'), 'Release signing does not fail closed.');
assert(profileBuild.includes('-ReleaseProfile reviewer_demo'), 'Play build does not select the reviewer/demo profile.');
assert(reviewerProfile.releaseStage === 'closed_test', 'Reviewer profile is not a closed test.');
assert(reviewerProfile.operationalMode === 'closed_pilot', 'Reviewer profile is not bound to the closed pilot.');
for (const flag of ['publicMarketplaceEnabled','identityVerificationEnabled','marketplacePaymentsEnabled','iapEnabled','adsEnabled']) {
  assert(reviewerProfile[flag] === false, `Reviewer profile must disable ${flag}.`);
}
assert(reviewerProfile.reviewerModeEnabled === true, 'Reviewer routes are not explicitly isolated to reviewer/demo.');
assert(build.includes('build-closed-test-aab.ps1'), 'Play wrapper does not use the reviewed profile build.');
assert(commonBuild.includes('read-mobile-version.mjs'), 'Build does not consume the authoritative version source.');
pass(scope, `version ${version[1]}+${version[2]}, package, SDK, fail-closed signing, and reviewer/demo profile are fixed`);
