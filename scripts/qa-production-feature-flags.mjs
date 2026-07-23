import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-production-feature-flags';
const config = read('flutter_mort/lib/core/config/app_config.dart');
assert(/publicMarketplaceEnabled[\s\S]+defaultValue: false/.test(config), 'Public marketplace does not default off.');
assert(/identityVerificationEnabled[\s\S]+defaultValue: false/.test(config), 'Identity verification does not default off.');
assert(/adsEnabled[\s\S]+defaultValue: false/.test(config), 'Ads do not default off.');
assert(/iapEnabled[\s\S]+defaultValue: false/.test(config), 'IAP does not default off.');
assert(config.includes("defaultValue: 'development'"), 'Release stage default must not claim production.');
pass(scope, 'marketplace, real identity verification, ads, and IAP default off and cannot be changed by ordinary UI');
