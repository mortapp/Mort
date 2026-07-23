import { assert, pass, read } from './play-release-qa-helpers.mjs';

const scope = 'qa-release-network-security';
const manifest = read('flutter_mort/android/app/src/main/AndroidManifest.xml');
const network = read('flutter_mort/android/app/src/main/res/xml/network_security_config.xml');
const config = read('flutter_mort/lib/core/config/app_config.dart');
const build = read('scripts/build-play-aab.ps1');
assert(manifest.includes('android:usesCleartextTraffic="false"'), 'Manifest allows cleartext.');
assert(network.includes('cleartextTrafficPermitted="false"'), 'Network security config allows cleartext.');
assert(!/(localhost|127\.0\.0\.1|10\.0\.2\.2|http:\/\/)/i.test(config + build), 'Release config contains a local/cleartext endpoint.');
assert(build.includes('https://rakjydmgwwgtdislanbt.supabase.co'), 'Release build is not pinned to the hosted project.');
pass(scope, 'release networking is HTTPS-only and pinned to the hosted MORT project');
