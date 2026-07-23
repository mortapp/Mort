import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-release-deep-links';
const manifest = read('flutter_mort/android/app/src/main/AndroidManifest.xml');
const router = read('flutter_mort/lib/core/routing/app_router.dart');
assert(manifest.includes('android:scheme="mort"') && manifest.includes('android:host="app"'), 'Expected MORT custom deep link missing.');
assert(!manifest.includes('android:autoVerify="true"'), 'Unverified HTTPS app link is claimed.');
assert(router.includes('auth-callback'), 'Auth callback route is missing.');
assert(router.includes('class GuardedRoute') && router.includes('AuthRequiredScreen') && router.includes('currentUser'), 'Router has no authenticated route guard.');
pass(scope, 'custom auth deep link is declared without a false verified-domain claim and guarded routes enforce session state');
