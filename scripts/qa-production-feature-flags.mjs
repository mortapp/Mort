import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-production-feature-flags';
const config = read('flutter_mort/lib/core/config/app_config.dart');
const profiles = JSON.parse(read('config/mort-release-profiles.json')).profiles;
const releaseBuild = read('scripts/android-release-profile-common.ps1');
assert(/publicMarketplaceEnabled[\s\S]+defaultValue: false/.test(config), 'Public marketplace does not default off.');
assert(/identityVerificationEnabled[\s\S]+defaultValue: false/.test(config), 'Identity verification does not default off.');
assert(/adsEnabled[\s\S]+defaultValue: false/.test(config), 'Ads do not default off.');
assert(profiles.production.adsEnabled === true, 'Production ads flag drifted from the owner-approved release profile.');
assert(profiles.production.useTestAds === false, 'Production must use configured production ad units, not Google test ads.');
assert(profiles.production_candidate.useTestAds === false, 'Production candidate ads must use configured production units.');
assert(releaseBuild.includes('USE_TEST_ADS = ([bool]$profile.useTestAds)'), 'Android release builds ignore the profile test-ad setting.');
assert(releaseBuild.includes('adsEnabled = $AdsEnabled'), 'Build manifest does not report the actual ads setting.');
assert(/iapEnabled[\s\S]+defaultValue: false/.test(config), 'IAP does not default off.');
assert(config.includes("defaultValue: 'development'"), 'Release stage default must not claim production.');
assert(/configuredReleaseProfile[\s\S]+defaultValue: ''/.test(config), 'Release profile must require an explicit non-development build define.');
assert(config.includes('releaseConfiguration.validationErrors'), 'Release profiles are not validated at startup.');
pass(scope, 'profile, marketplace, real identity verification, ads, and IAP default off and cannot be changed by ordinary UI');
